//
//  UserModel.swift
//  swift-hau
//
//  Created by Seonho Kim on 4/11/25.
//

import Foundation

struct UserModel {
    var birthdate: Date?
    var name: String?
    var selfIntro: String?
    var voice: String?
    var callTime: String?
    
    init(birthdate: Date? = Date(), name: String? = nil, selfStory: String? = nil, voice: String? = "Beomsoo", callTime: String? = "") {
        self.birthdate = birthdate
        self.name = name
        self.selfIntro = selfStory
        self.voice = voice
        self.callTime = callTime
    }
}
