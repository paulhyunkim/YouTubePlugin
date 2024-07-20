//
//  File.swift
//  
//
//  Created by Paul Kim on 7/16/24.
//

import Foundation
import SharedModule

//public struct YouTubeStream: Video {

//    static func == (lhs: YouTubeStream, rhs: YouTubeStream) -> Bool {
//        lhs.url == rhs.url
//    }
    
//    public var url: URL? {
//        return URL(string: "https://www.youtube.com/watch?v=\(id)")
//    }
//    
//    public var viewerCount: Int
//    public var id: String
//    public var startTime: Date?
//    public var title: String?
//    public var gameName: String?
//    
//    public var channel: YouTubeChannel
//    public var chatURL: URL? {
//        return URL(string: "https://www.youtube.com/live_chat?v=\(id)")
//    }
    
//    init(videoDetails: YouTubeScrapedVideoDetail, channel: YouTubeChannel) {
//        self.id = videoDetails.videoId
//        self.viewerCount = Int(videoDetails.viewCount) ?? 0
//        self.channel = channel
//    }
    
//    init(responseItem: GetYouTubeVideoSuccess.Item, channel: YouTubeChannel, gameName: String?) {
//        self.id = responseItem.id
//        self.title = responseItem.snippet.title
//        self.startTime = responseItem.liveStreamingDetails?.actualStartTime
//        self.viewerCount = Int(responseItem.liveStreamingDetails?.concurrentViewers ?? "0") ?? 0
//        self.channel = channel
//        self.gameName = gameName
//    }
    
//    init(id: String, viewerCount: Int) {
//        self.id = id
//        self.viewerCount = viewerCount
//    }
    
//    public func streamlinkQualityArg(_ quality: VideoQuality) -> String {
//        switch quality {
//        case .worst: return "worst"
//        case .p360:  return "360p"
//        case .p480:  return "480p"
//        case .p720:  return "720p"
//        case .p1080: return "1080p"
//        case .best:  return "best"
//        }
//    }
    
//}

extension Video {
    
    convenience init(responseItem: GetYouTubeVideoSuccess.Item, channel: Channel, topic: String?) {
        let status: Video.VideoStatus
        switch responseItem.snippet.liveBroadcastContent {
        case .live:
            status = .live
        case .upcoming:
            status = .upcoming
        case .none:
            status = .none
        }
        
        self.init(
            url: URL(string: "https://www.youtube.com/watch?v=\(responseItem.id)"),
            channel: channel,
            viewerCount: Int(responseItem.liveStreamingDetails?.concurrentViewers ?? "0") ?? 0,
            actualStartTime: responseItem.liveStreamingDetails?.actualStartTime,
            scheduledStartTime: responseItem.liveStreamingDetails?.scheduledStartTime,
            title: responseItem.snippet.title,
            topic: topic,
            chatURL: URL(string: "https://www.youtube.com/live_chat?v=\(responseItem.id)"),
            status: status
        )
    }
    
}
