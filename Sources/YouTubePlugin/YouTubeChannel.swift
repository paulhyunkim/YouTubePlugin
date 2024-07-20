//
//  File.swift
//  
//
//  Created by Paul Kim on 7/16/24.
//

import Foundation
import SharedModule

//public struct YouTubeChannel: Codable {
//    
//    public var id: String
//    public var name: String
//    public var userLogin: String
//    public var imageURL: URL?
//    
//    public init(id: String, name: String, userLogin: String, imageURL: URL? = nil) {
//        self.id = id
//        self.name = name
//        self.userLogin = userLogin
//        self.imageURL = imageURL
//    }
//    
////    public init(cachedChannel: Channel) {
////        self.id = cachedChannel.id
////        self.name = cachedChannel.name
////        self.userLogin = cachedChannel.userLogin
////        self.imageURL = cachedChannel.imageURL
////    }
//    
//    init(responseItem: GetYouTubeChannelSuccess.Item) {
//        self.id = responseItem.id
//        self.name = responseItem.snippet.title
//        self.userLogin = responseItem.snippet.customUrl
//        self.imageURL = responseItem.snippet.thumbnails.default.url
//    }
//
////    public func toCacheType() -> CacheChannel {
////        CacheChannel(id: id, name: name, userLogin: userLogin, imageURL: imageURL, platform: .youTube)
////    }
//
//}

extension Channel {
    
    convenience init(responseItem: GetYouTubeChannelSuccess.Item) {
        self.init(
            id: responseItem.id,
            name: responseItem.snippet.title,
            userLogin: responseItem.snippet.customUrl,
            platform: "youtube",
//            imageBackgroundColor: .red,
            imageURL: responseItem.snippet.thumbnails.default.url
        )
    }
    
}
