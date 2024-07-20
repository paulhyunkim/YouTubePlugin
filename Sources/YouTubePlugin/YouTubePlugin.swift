//
//  File.swift
//  
//
//  Created by Paul Kim on 7/16/24.
//

import Foundation
import Combine
import SwiftSoup
import Sextant
import SharedModule

public class YouTubeService: StreamServicePlugin {

    public var platformName: String { "youtube" }
    
    //var userAgent: Binding<String>// = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) HeadlessChrome/121.0.0.0 Safari/537.36 [ip:13.233.135.97]"

    @PluginStorage<YouTubeService>("apiKey") private var apiKey
    @PluginStorage<YouTubeService>("userAgent") private var userAgent
    
    let streamlink = YoutubeStreamlinkService()
    
    var channelsSubject = CurrentValueSubject<[Channel], Never>([])
    public var channelsPublisher: AnyPublisher<[Channel], Never> { channelsSubject.eraseToAnyPublisher() }
    
    var streamsSubject = CurrentValueSubject<[Video], Never>([])
    public var streamsPublisher: AnyPublisher<[Video], Never> { streamsSubject.eraseToAnyPublisher() }
    
    public var configuration: PluginConfiguration
    
    required public init() {
        self.configuration = PluginConfiguration(
            title: "YouTube Settings",
            dict: [:]
        )
        self.configuration.dict["User Agent"] = $userAgent
        self.configuration.dict["API Key"] = $apiKey
    }
    
    public func fetchChannels(channels: [Channel]) async throws {
        let ids = channels
            .filter { [platformName] in $0.platform == platformName }
            .map { $0.id }
        let channelsResponse = try await fetchYouTubeChannels(ids: ids)
        let channels = channelsResponse.items.map { Channel(responseItem: $0) }
        channelsSubject.send(channels)
    }
    
    // using streamlink to check liveness
    public func fetchStreamsStreamlink(channels: [Channel]) async throws {
        let youtubeChannels = channels
            .filter { [platformName] in $0.platform == platformName }
        let liveChannels = await streamlink.fetchLiveChannels(channels: youtubeChannels)
        guard !liveChannels.isEmpty else {
            return
        }
        
        let liveVideoData = try await scrapeLiveVideoData(channels: liveChannels)
        let response = try await fetchYouTubeVideos(ids: liveVideoData.map { $0.videoID })
        
        let streams: [Video] = response.items.compactMap { item in
            guard let channel = liveChannels.first(where: { $0.id == item.snippet.channelId }),
                  let videoData = liveVideoData.first(where: { $0.videoID == item.id }) else {
                return nil
            }
            return Video(responseItem: item, channel: channel, topic: videoData.topic)
        }
        streamsSubject.send(streams)
    }
    
    //
    public func fetchStreams(channels: [Channel]) async throws {
        let youtubeChannels = channels
            .filter { [platformName] in $0.platform == platformName }
//        let liveChannels = await streamlink.fetchLiveChannels(channels: youtubeChannels)
//        guard !liveChannels.isEmpty else {
//            return
//        }
        
        let liveVideoData = try await scrapeLiveVideoData(channels: youtubeChannels)
        guard !liveVideoData.isEmpty else {
            return
        }
        
        let response = try await fetchYouTubeVideos(ids: liveVideoData.map { $0.videoID })
        
        let streams: [Video] = response.items.compactMap { item in
            guard let channel = youtubeChannels.first(where: { $0.id == item.snippet.channelId }),
                  let videoData = liveVideoData.first(where: { $0.videoID == item.id }) else {
                return nil
            }
            switch item.snippet.liveBroadcastContent {
            case .live:
                return Video(responseItem: item, channel: channel, topic: videoData.topic)
            case .upcoming:
//                return nil
                if let scheduledStartTime = item.liveStreamingDetails?.scheduledStartTime,
                   scheduledStartTime.timeIntervalSince(.now) < 60 * 60 * 24,
                   scheduledStartTime.timeIntervalSince(item.snippet.publishedAt) < 60 * 60 * 24 * 365 {
                    return Video(responseItem: item, channel: channel, topic: videoData.topic)
                } else {
                    return nil
                }
            case .none:
                return nil
            }
        }
        streamsSubject.send(streams)
    }

    public func addChannel(from url: URL) async throws {
        guard url.host()?.contains("youtube") == true,
              let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: true)?.queryItems,
              let videoID = queryItems.first(where: { $0.name == "v" })?.value else {
            throw DataServiceError.invalidURL
        }
        
        guard let videoResponseItem = try await fetchYouTubeVideos(ids: [videoID]).items.first else {
            throw YouTubeError.emptyVideosResponseItems
        }
        
        guard let channelResponseItem = try await fetchYouTubeChannels(ids: [videoResponseItem.snippet.channelId]).items.first else {
            throw YouTubeError.emptyChannelsResponseItems
        }
        
        let channel = Channel(responseItem: channelResponseItem)
        updateChannelsCache(with: [channel])
    }
    
}

public extension YouTubeService {
    
    private func fetchYouTubeVideos(videosData: [ScrapedLiveVideoData]) async throws -> GetYouTubeVideoSuccess {
        let part = "snippet,liveStreamingDetails"
        
        var urlComponents = URLComponents(url: Constant.getVideosURL, resolvingAgainstBaseURL: false)
        urlComponents?.queryItems = [
            URLQueryItem(name: "part", value: part),
            URLQueryItem(name: "id", value: videosData.map({ $0.videoID }).joined(separator: ",")),
            URLQueryItem(name: "key", value: apiKey)
        ]
        
        guard let requestURL = urlComponents?.url else {
            throw DataServiceError.invalidURL
        }
        let urlRequest = URLRequest(url: requestURL)
        
        return try await withCheckedThrowingContinuation { continuation in
            let task = URLSession.shared.dataTask(with: urlRequest) { data, response, error in
                guard let data else {
                    continuation.resume(throwing: DataServiceError.invalidURL)
                    return
                }
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                do {
                    let response = try decoder.decode(GetYouTubeVideoSuccess.self, from: data)
                    continuation.resume(returning: response)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            task.resume()
        }
    }
    
    private func fetchYouTubeVideos(ids: [String]) async throws -> GetYouTubeVideoSuccess {
        let chunkSize = 50

        // Split the ids array into chunks of 50
        let idChunks = ids.chunked(into: chunkSize)
        
        // Initialize an array to hold the combined results
        var combinedResults = GetYouTubeVideoSuccess(items: [])

        for chunk in idChunks {
            let result = try await fetchVideosChunk(ids: chunk)
            combinedResults.items.append(contentsOf: result.items)
        }

        return combinedResults
    }
    
    private func fetchVideosChunk(ids: [String]) async throws -> GetYouTubeVideoSuccess {
        let parts = ["snippet", "liveStreamingDetails", "contentDetails"] // "status"
        
        var urlComponents = URLComponents(url: Constant.getVideosURL, resolvingAgainstBaseURL: false)
        urlComponents?.queryItems = [
            URLQueryItem(name: "part", value: parts.joined(separator: ",")),
            URLQueryItem(name: "id", value: ids.joined(separator: ",")),
            URLQueryItem(name: "key", value: apiKey)
        ]
        
        guard let requestURL = urlComponents?.url else {
            throw DataServiceError.invalidURL
        }
        let urlRequest = URLRequest(url: requestURL)
        
        return try await withCheckedThrowingContinuation { continuation in
            let task = URLSession.shared.dataTask(with: urlRequest) { data, response, error in
                guard let data else {
                    continuation.resume(throwing: DataServiceError.invalidURL)
                    return
                }
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                do {
                    let response = try decoder.decode(GetYouTubeVideoSuccess.self, from: data)
                    continuation.resume(returning: response)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            task.resume()
        }
    }
    
    private func fetchYouTubeChannels(ids: [String]) async throws -> GetYouTubeChannelSuccess {
        let chunkSize = 50

        // Split the ids array into chunks of 50
        let idChunks = ids.chunked(into: chunkSize)
        
        // Initialize an array to hold the combined results
        var combinedResults = GetYouTubeChannelSuccess(items: [])

        for chunk in idChunks {
            let result = try await fetchChannelsChunk(ids: chunk)
            combinedResults.items.append(contentsOf: result.items)
        }

        return combinedResults
    }
    
    private func fetchChannelsChunk(ids: [String]) async throws -> GetYouTubeChannelSuccess {
        let parts = ["snippet"]
        
        var urlComponents = URLComponents(url: Constant.getChannelsURL, resolvingAgainstBaseURL: false)
        urlComponents?.queryItems = [
            URLQueryItem(name: "part", value: parts.joined(separator: ",")),
            URLQueryItem(name: "id", value: ids.joined(separator: ",")),
            URLQueryItem(name: "key", value: apiKey)
        ]
        
        guard let requestURL = urlComponents?.url else {
            throw DataServiceError.invalidURL
        }
        let urlRequest = URLRequest(url: requestURL)
        
        return try await withCheckedThrowingContinuation { continuation in
            let task = URLSession.shared.dataTask(with: urlRequest) { data, response, error in
                guard let data else {
                    continuation.resume(throwing: DataServiceError.invalidURL)
                    return
                }
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                do {
                    let response = try decoder.decode(GetYouTubeChannelSuccess.self, from: data)
                    continuation.resume(returning: response)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            task.resume()
        }
    }
    
    private func updateChannelsCache(with channels: [Channel]) {
//        channels.forEach { channel in
//            if let index = cachedChannels.firstIndex(where: { $0.id == channel.id }) {
//                cachedChannels[index] = channel
//            } else {
//                cachedChannels.append(channel)
//            }
//        }
    }
    
//    private func convertStringToDictionary(text: String) -> [String: AnyObject]? {
//        if let data = text.data(using: .utf8) {
//            do {
//                let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String:AnyObject]
//                return json
//            } catch {
//                print("Something went wrong")
//            }
//        }
//        return nil
//    }
    
    private func scrapeLiveVideoData(channels: [Channel]) async throws -> [ScrapedLiveVideoData] {
        return try await withThrowingTaskGroup(
            of: ScrapedLiveVideoData?.self,
            returning: [ScrapedLiveVideoData].self) { taskGroup in
                var liveVideoData: [ScrapedLiveVideoData?] = []
                channels.forEach { channel in
                    taskGroup.addTask {
                        do {
                            let document = try await self.fetchHTMLDocument(channel: channel)
                            let videoID = try await self.scrapeLiveVideoID(document: document)
                            let topic = try await self.scrapeTopicName(document: document)
                            return ScrapedLiveVideoData(videoID: videoID, topic: topic)
                        } catch {
                            return nil
                        }
                    }
                }
                for try await data in taskGroup {
                    liveVideoData.append(data)
                }
                return liveVideoData.compactMap { $0 }
            }
    }
    
    struct ScrapedLiveVideoData {
        var videoID: String
        var topic: String?
    }
    
    private func fetchHTMLDocument(channel: Channel) async throws -> Document {
        return try await withCheckedThrowingContinuation { continuation in
            guard let requestURL = URL(string: "https://www.youtube.com/\(channel.userLogin)/live") else {
                continuation.resume(throwing: DataServiceError.invalidURL)
                return
            }
            var urlRequest = URLRequest(url: requestURL)
            urlRequest.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            
            let task = URLSession.shared.dataTask(with: urlRequest) { data, response, error in
                guard let data,
                      let html = String(data: data, encoding: .ascii) else {
                    continuation.resume(throwing: DataServiceError.invalidURL)
                    return
                }
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                do {
                    let document = try SwiftSoup.parse(html)
                    continuation.resume(returning: document)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            task.resume()
        }
    }
    
    private func scrapeLiveVideoID(document: Document) throws -> String {
        let dataRegex = try Regex("var ytInitialPlayerResponse = (.*)")

        guard let scriptData = try document
            .select("script")
            .first(where: { $0.data().contains(dataRegex) })?
            .data() else {
            throw DataServiceError.invalidURL
        }

        let escapedData = Entities.escape(scriptData, OutputSettings().encoder(String.Encoding.ascii).escapeMode(Entities.EscapeMode.base))
        
        guard let matchString = escapedData.firstMatch(of: dataRegex)?.output.last?.substring,
              let matchData = String(matchString).data(using: .utf8) else {
            throw DataServiceError.invalidURL
        }
    
        guard let videoID = matchData.query(values: "$.videoDetails.videoId")?.first as? String else {
            throw DataServiceError.invalidURL
        }
        
        return videoID
    }
    
    private func scrapeTopicName(document: Document) throws -> String {
        let dataRegex = try Regex("var ytInitialData = (.*)")
        
        guard let scriptData = try document
            .select("script")
            .first(where: { $0.data().contains(dataRegex) })?
            .data() else {
            throw DataServiceError.invalidURL
        }

        let escapedData = Entities.escape(scriptData, OutputSettings().encoder(String.Encoding.ascii).escapeMode(Entities.EscapeMode.base))
        
        guard let matchString = escapedData.firstMatch(of: dataRegex)?.output.last?.substring,
              let matchData = String(matchString).data(using: .utf8) else {
            throw DataServiceError.invalidURL
        }
        
        guard let topicName = matchData
            .query(values: "$..richMetadataRenderer[?(@.style=='RICH_METADATA_RENDERER_STYLE_BOX_ART')].title.simpleText")?
            .first as? String else {
            return "Just Chatting"
        }
        
        return topicName
    }
    
    func fetchChannel(id: String) async throws -> Channel {
        var urlComponents = URLComponents(url: Constant.getChannelsURL, resolvingAgainstBaseURL: false)
        urlComponents?.queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "id", value: id),
            URLQueryItem(name: "key", value: "AIzaSyDEmoilv9NLdpxpQaEgHRF3bXWyessnYoI")
        ]
        
        guard let requestURL = urlComponents?.url else {
            throw DataServiceError.invalidURL
        }

        let urlRequest = URLRequest(url: requestURL)
        
        let (data, _) = try await URLSession.shared.data(for: urlRequest)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        guard let response = try? decoder.decode(GetYouTubeChannelSuccess.self, from: data),
              let item = response.items.first else {
            throw DataServiceError.invalidURL
        }
        return Channel(responseItem: item)
    }
    
}


struct YoutubeStreamlinkService {
    
    func fetchLiveChannels(channels: [Channel]) async -> [Channel] {
        var liveChannels: [Channel] = []

        await withTaskGroup(of: (Channel, Bool).self) { group in
            for channel in channels {
                group.addTask {
                    do {
                        let isLive = try await isLive(for: channel)
                        return (channel, isLive)
                    } catch {
                        return (channel, false)
                    }
                }
            }

            for await result in group {
                let (channel, isLive) = result
                if isLive {
                    liveChannels.append(channel)
                }
            }
        }
        
        return liveChannels
    }
    
    func isLive(for channel: Channel) async throws -> Bool {
        let shell = ShellService()
        
        return try await withCheckedThrowingContinuation { continuation in
//            let command = "\(UserPreferences.shared.streamlinkPath) \"https://www.youtube.com/\(channel.userLogin)\" best --stream-url"
            Task {
                do {
//                    let output = try await shell.execute(command)
//                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    let output = try await shell
                        .execute(
                            path: "/opt/homebrew/bin/streamlink", //UserPreferences.shared.streamlinkPath,
                            args: [
                                "https://www.youtube.com/\(channel.userLogin)",
                                "best",
                                "--stream-url"
                            ]
                        )
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    if let url = URL(string: output), url.scheme?.contains("http") == true, url.pathExtension == "m3u8" {
                        continuation.resume(returning: true)
                    } else {
                        continuation.resume(returning: false)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
//    func url(for channel: Channel, quality: VideoQuality) async throws -> URL {
////        guard let url = stream.url else {
////            throw StreamlinkServiceError.invalidStreamURL
////        }
//        
//        let url = "https://www.youtube.com/\(channel.userLogin)"
//        
////        let qualityArg = stream.streamlinkQualityArg(quality)
//        
//        return try await withCheckedThrowingContinuation { continuation in
//            let command = "\(UserPreferences.shared.streamlinkPath) \"\(url)\" --stream-url"
////            print(command)
//            Task {
//                do {
//                    let output = try ShellService().execute(command).trimmingCharacters(in: .whitespacesAndNewlines)
//                    if let url = URL(string: output) {
//                        continuation.resume(returning: url)
//                    } else {
//                        continuation.resume(throwing: StreamlinkServiceError.outputIsNotAURL(output))
//                    }
//                }
//            }
//        }
//    }
    
}
