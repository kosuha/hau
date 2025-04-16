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
    // 앱 초기 설정(onAppear)이 시작되었는지 추적하는 상태 변수
    @State private var initialSetupStarted = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                // 1. initialSetupStarted가 false이면 무조건 초기 로딩 뷰 표시
                if !initialSetupStarted {
                    ProgressView() // 초기 로딩 메시지
                        .transition(.opacity.animation(.easeInOut))
                }
                // 2. 모든 로딩이 완료되면 실제 콘텐츠 표시
                else if !(authViewModel.isLoading || userViewModel.isLoading) {
                    Group {
                        if authViewModel.isLoggedIn {
                            if userViewModel.isOnboardingCompleted {
                                MainView()
                            } else {
                                OnboardingView(onComplete: {
                                    userViewModel.isOnboardingCompleted = true
                                    userViewModel.saveProfile()
                                })
                            }
                        } else {
                            LoginScreen()
                        }
                    }
                    .transition(.opacity.animation(.easeInOut))
                }
            }
            .environmentObject(userViewModel)
            .environmentObject(authViewModel)
            .onAppear {
                // onAppear가 여러 번 호출될 경우를 대비해 한 번만 실행되도록 함
                guard !initialSetupStarted else { return }

                print("HAUApp: onAppear 실행됨 - 초기 설정 시작.")
                // 실제 데이터 로딩 및 인증 확인 시작
                CallManager.shared.setupVoIP()
                authViewModel.setUserViewModel(userViewModel)
                authViewModel.checkAuthStatus()

                // 모든 초기 설정 작업 시작 후 상태 업데이트
                initialSetupStarted = true
            }
        }
    }
}
