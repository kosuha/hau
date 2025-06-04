//
//  HAUApp.swift
//  swift-hau
//
//  Created by Seonho Kim on 4/11/25.
//

import SwiftUI
import Supabase
import AuthenticationServices
import Foundation
import UIKit

// 안전하게 Supabase 클라이언트 초기화
let client: SupabaseClient = {
    // 릴리즈 모드에서도 로깅하도록 함
    print("📱 Supabase 초기화 시도")
    print("📱 SUPABASE_URL: \(AppConfig.supabaseProjectURL ?? "nil")")
    
    guard let supabaseURLString = AppConfig.supabaseProjectURL, 
          !supabaseURLString.isEmpty,
          let supabaseURL = URL(string: supabaseURLString) else {
        // Info.plist 값 직접 확인
        if let infoDict = Bundle.main.infoDictionary,
           let urlFromInfo = infoDict["SUPABASE_URL"] as? String,
           !urlFromInfo.isEmpty,
           let url = URL(string: urlFromInfo) {
            print("📱 Info.plist에서 직접 URL 발견: \(urlFromInfo)")
            let key = AppConfig.supabaseProjectKey
            return SupabaseClient(supabaseURL: url, supabaseKey: key)
        }
        
        // 마지막 대안으로 하드코딩된 값 사용
        print("📱 Supabase 초기화 실패: 유효한 URL을 찾을 수 없습니다")
        fatalError("Supabase 초기화 실패: 유효한 URL이 설정되지 않았습니다. Info.plist 또는 환경 변수를 확인하세요.")
    }
    
    let supabaseKey = AppConfig.supabaseProjectKey
    
    print("📱 Supabase 초기화 성공 - URL: \(supabaseURLString)")
    
    return SupabaseClient(supabaseURL: supabaseURL, supabaseKey: supabaseKey)
}()

@main
struct HAUApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var userViewModel = UserViewModel()
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var coinViewModel = CoinViewModel()
    // 앱 초기 설정(onAppear)이 시작되었는지 추적하는 상태 변수
    @State private var initialSetupStarted = false
    // 업데이트 관련 상태 변수
    @State private var showUpdateAlert = false
    @State private var updateInfo: AppUpdateInfo?

    init() {
        // Google 로그인 설정
        // ... existing code ...
    }
    
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
            .environmentObject(coinViewModel)
            .onAppear {
                // onAppear가 여러 번 호출될 경우를 대비해 한 번만 실행되도록 함
                guard !initialSetupStarted else { return }
                
                // 앱 버전 체크
                Task {
                    await checkAppVersion()
                }
                
                // 실제 데이터 로딩 및 인증 확인 시작
                authViewModel.setUserViewModel(userViewModel)
                authViewModel.checkAuthStatus()

                // 모든 초기 설정 작업 시작 후 상태 업데이트
                initialSetupStarted = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                // 앱이 활성화될 때마다 인증 상태 확인
                authViewModel.checkAuthStatus()
            }
            .onChange(of: userViewModel.userData.authId) { newUserId in
                if let userId = newUserId {
                    coinViewModel.setUserId(userId)
                    Task {
                        await coinViewModel.fetchCoinBalance()
                    }
                }
            }
            .alert(isPresented: $showUpdateAlert) {
                Alert(
                    title: Text(updateInfo?.title ?? "업데이트 알림"),
                    message: Text(updateInfo?.message ?? "새로운 버전의 앱이 출시되었습니다. 업데이트해주세요."),
                    primaryButton: .default(Text("지금 업데이트"), action: {
                        if let urlString = updateInfo?.appStoreURL, let url = URL(string: urlString) {
                            UIApplication.shared.open(url)
                        }
                        
                        // 강제 업데이트인 경우 앱 종료
                        if updateInfo?.isForceUpdate == true {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    exit(0)
                                }
                            }
                        }
                    }),
                    secondaryButton: updateInfo?.isForceUpdate == true ? 
                        .destructive(Text("앱 종료"), action: {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    exit(0)
                                }
                            }
                        }) : 
                        .cancel(Text("나중에"))
                )
            }
        }
    }
    
    func checkAppVersion() async {
        // 현재 앱 버전 가져오기
        guard let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            return
        }
        
        do {
            // Supabase에서 버전 정보 가져오기 (예시: app_config 테이블에서 최신 버전 정보 조회)
            let queriedItems: [AppVersionResponse] = try await client
                .database
                .from("app_config")
                .select()
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
                .value
            
            let response: AppVersionResponse = queriedItems.first ?? AppVersionResponse(
                latestVersion: currentVersion,
                minimumVersion: currentVersion,
                appStoreURL: "https://apps.apple.com/app/id6746073903", // 실제 앱 ID로 변경 필요
                updateTitle: "업데이트 안내",
                updateMessage: "새로운 버전이 출시되었습니다."
            )
            
            // 버전 비교
            let isForceUpdate = compareVersions(currentVersion, response.minimumVersion)
            
            if isForceUpdate {
                // 메인 스레드에서 UI 업데이트
                await MainActor.run {
                    updateInfo = AppUpdateInfo(
                        title: response.updateTitle,
                        message: response.updateMessage,
                        appStoreURL: response.appStoreURL,
                        isForceUpdate: true
                    )
                    showUpdateAlert = true
                }
            }
        } catch {
            print("HAUApp: 버전 정보를 가져오는 중 오류 발생: \(error.localizedDescription)")
        }
    }
    
    // 버전 비교 함수 (더 낮은 버전이면 true 반환)
    private func compareVersions(_ version1: String, _ version2: String?) -> Bool {
        guard let version2 = version2 else { return false }

        let components1 = version1.split(separator: ".").map { Int($0) ?? 0 }
        let components2 = version2.split(separator: ".").map { Int($0) ?? 0 }

        let maxLength = max(components1.count, components2.count)
        
        let paddedComponents1 = components1 + Array(repeating: 0, count: maxLength - components1.count)
        let paddedComponents2 = components2 + Array(repeating: 0, count: maxLength - components2.count)

        for i in 0..<maxLength {
            if paddedComponents1[i] < paddedComponents2[i] {
                return true
            }
            if paddedComponents1[i] > paddedComponents2[i] {
                return false
            }
        }
        return false // 동일한 버전이면 false 반환 (낮은 버전이 아님)
    }
}

// 앱 업데이트 관련 모델
struct AppUpdateInfo {
    let title: String
    let message: String
    let appStoreURL: String
    let isForceUpdate: Bool
}

// Supabase에서 가져올 데이터 형식 (app_config 테이블 구조에 맞게 조정 필요)
struct AppVersionResponse: Decodable {
    let latestVersion: String?
    let minimumVersion: String
    let appStoreURL: String
    let updateTitle: String
    let updateMessage: String
    
    enum CodingKeys: String, CodingKey {
        case latestVersion = "latest_version"
        case minimumVersion = "minimum_version"
        case appStoreURL = "app_store_url"
        case updateTitle = "update_title"
        case updateMessage = "update_message"
    }
}
