//
//  HAUApp.swift
//  swift-hau
//
//  Created by Seonho Kim on 4/11/25.
//

import SwiftUI

@main
struct HAUApp: App {
    @StateObject private var userViewModel = UserViewModel()
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(userViewModel)
        }
    }
}
