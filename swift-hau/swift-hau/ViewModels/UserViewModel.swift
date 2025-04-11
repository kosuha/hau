//
//  UserViewModel.swift
//  swift-hau
//
//  Created by Seonho Kim on 4/11/25.
//

import Foundation
import SwiftUI
import Combine

class UserViewModel: ObservableObject {
    @Published var userData: UserModel = UserModel()
    
    func updateUserData(birthdate: Date? = nil, name: String? = nil, selfStory: String? = nil, voice: String? = nil, callTime: String? = nil) {
        if let birthdate = birthdate {
            userData.birthdate = birthdate
        }
        if let name = name {
            userData.name = name
        }
        if let selfStory = selfStory {
            userData.selfIntro = selfStory
        }
        if let voice = voice {
            userData.voice = voice
        }
        if let callTime = callTime {
            userData.callTime = callTime
        }
        
        print("User data updated: \(userData)")
    }
}
