//
//  File.swift
//  
//
//  Created by Paul Kim on 7/16/24.
//

import Foundation
import SharedModule

struct Constant {
    
    static let getChannelsURL = URL(string: "https://youtube.googleapis.com/youtube/v3/channels")!
    static let getVideosURL = URL(string: "https://youtube.googleapis.com/youtube/v3/videos")!
    static let channels = "\(bundleID).youTubeChannels"
//    static let favoriteChannels = "\(bundleID).favoriteChannels"
//    static let enabledNotifications = "\(bundleID).enabledNotifications"
//    static let channels = "\(bundleID).channels"
//    static let apiKey = "\(bundleID).youtubeAPIKey"
    
    static let bundleID = "com.paulkim.StreamDex"
    
}
