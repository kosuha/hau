//
//  HAUApp.swift
//  swift-hau
//
//  Created by Seonho Kim on 4/11/25.
//

import SwiftUI
import Supabase

let client = SupabaseClient(
    supabaseURL: URL(string: "https://xyzcompany.supabase.co")!, supabaseKey: "public-anon-key")

@main
struct HAUApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var userViewModel = UserViewModel()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(userViewModel)
                .onAppear {
                    // 앱이 시작될 때 CallManager 설정
                    CallManager.shared.setupVoIP()
                }
        }
    }
}
