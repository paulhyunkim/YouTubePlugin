//
//  File.swift
//  
//
//  Created by Paul Kim on 7/16/24.
//

import Foundation

struct GetYouTubeVideoSuccess: Codable {

    var items: [Item]
    
    struct Item: Codable {
        
        var id: String
        var snippet: Snippet
        var liveStreamingDetails: LiveStreamingDetails?
        
        struct Snippet: Codable {
            var title: String
            var publishedAt: Date
            var channelId: String
            var description: String
            var channelTitle: String
            var liveBroadcastContent: LiveBroadcastContent
            
            enum LiveBroadcastContent: String, Codable {
                case live
                case none
                case upcoming
            }
        }

        struct LiveStreamingDetails: Codable {
            var actualStartTime: Date?
            var actualEndTime: Date?
            var scheduledStartTime: Date?
            var scheduledEndTime: Date?
            var concurrentViewers: String?
//            var activeLiveChatId: String?
        }
        
        
        
    }

}

struct GetYouTubeChannelSuccess: Codable {

    var items: [Item]
    
    struct Item: Codable {
        
        var id: String
        var snippet: Snippet
        
        struct Snippet: Codable {
            var title: String
            var description: String
            var customUrl: String
            var thumbnails: Thumbnails
            
            struct Thumbnails: Codable {
                var `default`: DefaultThumbnail
                
                struct DefaultThumbnail: Codable {
                    var url: URL?
                }
            }
        }

    }

}

struct YouTubeScrapedVideoDetail: Codable {
    
    var isLive: Bool
    var author: String
    var channelId: String
    var title: String
    var videoId: String
    var viewCount: String
    
}

