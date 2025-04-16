//
//  UserModel.swift
//  swift-hau
//
//  Created by Seonho Kim on 4/11/25.
//

import Foundation

struct UserModel: Codable {  // 또는 class UserModel: Codable {
    var birthdate: Date?
    var name: String?
    var selfIntro: String?
    var voice: String?
    var callTime: String?
    var plan: String?
    var authId: String?
    
    // JSON 키와 Swift 속성 간의 매핑
    enum CodingKeys: String, CodingKey {
        case birthdate
        case name
        case selfIntro = "self_intro"
        case voice
        case callTime = "call_time"
        case plan
        case authId = "auth_id"
    }
    
    // 생성자 추가
    init(birthdate: Date? = nil, name: String? = nil, selfIntro: String? = nil, 
         voice: String? = nil, callTime: String? = nil, plan: String? = nil, authId: String? = nil) {
        self.birthdate = birthdate
        self.name = name
        self.selfIntro = selfIntro
        self.voice = voice
        self.callTime = callTime
        self.plan = plan
        self.authId = authId
    }
}
