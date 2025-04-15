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
    @State private var showOnboarding = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                if authViewModel.isLoggedIn {
                    if showOnboarding {
                        OnboardingView(onComplete: {
                            showOnboarding = false
                        })
                    } else {
                        MainView()
                    }
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
            .onChange(of: authViewModel.isLoggedIn) { isLoggedIn in
                if isLoggedIn {
                    // 로그인 성공 시 사용자 정보 확인
                    checkUserOnboardingStatus()
                }
            }
        }
    }
    
    // 사용자 정보가 있는지 확인하고 없으면 온보딩 화면 표시
    private func checkUserOnboardingStatus() {
        // 사용자 ID 설정 - UUID를 String으로 변환
        if let userId = authViewModel.currentUser?.id {
            userViewModel.setUserId(userId.uuidString)
        }
        
        // 필수 사용자 정보 확인 (이름과 생년월일)
        let hasUserName = userViewModel.userData.name != nil
        let hasUserBirthdate = userViewModel.userData.birthdate != nil
        
        // 필수 정보가 있으면 온보딩 화면을 표시하지 않음
        showOnboarding = !(hasUserName && hasUserBirthdate)
    }
}
