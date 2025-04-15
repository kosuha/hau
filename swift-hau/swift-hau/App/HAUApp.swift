//
//  HAUApp.swift
//  swift-hau
//
//  Created by Seonho Kim on 4/11/25.
//

import SwiftUI
import Supabase
import AuthenticationServices

let client = SupabaseClient(
    supabaseURL: URL(string: AppConfig.supabaseProjectURL)!, supabaseKey: AppConfig.supabaseProjectKey)

@main
struct HAUApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var userViewModel = UserViewModel()
    @StateObject private var authViewModel = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            ZStack {
                if authViewModel.isLoggedIn {
                    MainView()
                } else {
                    LoginScreen()
                }
            }
            .environmentObject(userViewModel)
            .environmentObject(authViewModel)
            .onAppear {
                // 앱이 시작될 때 CallManager 설정
                CallManager.shared.setupVoIP()
                // 자동 로그인 시도
                authViewModel.checkAuthStatus()
            }
        }
    }
}
