//
//  MainView.swift
//  swift-hau
//
//  Created by Seonho Kim on 4/11/25.
//

import SwiftUI

struct MainView: View {
    @EnvironmentObject var userViewModel: UserViewModel
    @StateObject private var coinViewModel = CoinViewModel()
    @State private var navigationPath = NavigationPath()
    @ObservedObject private var callManager = CallManager.shared
    @State private var showCallViewAsSheet = false
    @State private var showCallRequestAlert = false
    @State private var showCallErrorAlert = false
    
    enum Destination: Hashable {
        case settings
        case callTimeSetting
        case privateSettings
        case pay
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                AppTheme.Gradients.primary
                    .ignoresSafeArea()
                
                VStack {
                    // 헤더
                    HStack {
                        Spacer()
                        
                        Button(action: { navigationPath.append(Destination.pay) }) {
                            Image(systemName: "diamond.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                            Text(coinViewModel.formattedBalance())
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .cornerRadius(99)
                        .overlay(
                            RoundedRectangle(cornerRadius: 99)
                                .stroke(AppTheme.Colors.light, lineWidth: 1.5)
                        )

                        Button(action: { navigationPath.append(Destination.settings) }) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                        }
                        .padding(.leading, 10)
                        .padding(.trailing, 20)
                    }
                    .frame(height: UIScreen.main.bounds.height * 0.1)
                    
                    // 콘텐츠
                    VStack(alignment: .leading, spacing: 0) {
                        VStack(alignment: .leading, spacing: 10) {
                            if let name = userViewModel.userData.name {
                                Text("\(name)님,")
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundColor(.white)
                            } else {
                                Text("안녕,")
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            Text("반가워요!")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.bottom, 43)
                        
                        // 알림 박스
                        Button(action: { navigationPath.append(Destination.callTimeSetting) }) {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(AppTheme.Colors.light)
                                        .frame(width: 44, height: 44)
                                    
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(AppTheme.Colors.tertiary)
                                }
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    
                                    if let nextSchedule = userViewModel.getNextCallSchedule() {
                                        let dayText = nextSchedule.isDayLabel ? nextSchedule.day : "\(nextSchedule.day)요일"
                                        Text("\(dayText) \(nextSchedule.time)")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(AppTheme.Colors.dark)
                                        Text("통화하기로 한거 잊지않으셨죠?")
                                            .font(.system(size: 16))
                                            .foregroundColor(AppTheme.Colors.dark)
                                    } else {
                                        Text("언제 통화할까요?")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(AppTheme.Colors.dark)
                                        Text("원하는 시간을 알려주세요.")
                                            .font(.system(size: 16))
                                            .foregroundColor(AppTheme.Colors.dark)
                                    }
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 22)
                            .padding(.vertical, 17)
                            .background(AppTheme.Colors.lightTransparent)
                            .cornerRadius(16)
                        }
                        
                        Spacer()
                        
                        // 프라이빗 모드 상태 표시
                        if callManager.isPrivateMode {
                            Button(action: {
                                navigationPath.append(Destination.privateSettings)
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(AppTheme.Colors.dark)
                                    
                                    Text("프라이빗 모드 활성화됨")
                                        .font(.system(size: 14))
                                        .foregroundColor(AppTheme.Colors.dark)
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 16)
                                .background(AppTheme.Colors.lightTransparent)
                                .cornerRadius(8)
                            }
                            .padding(.bottom, 16)
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                        
                        // 통화 버튼
                        Button(action: { 
                            callManager.callError = nil // 오류 상태 초기화
                            Task {
                                if await coinViewModel.checkSufficientCoinsForCall() {
                                    callManager.requestCallPush()
                                    // 오류 없을 때만 성공 알림 표시
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        if callManager.callError == nil {
                                            showCallRequestAlert = true
                                        } else {
                                            showCallErrorAlert = true
                                        }
                                    }
                                } else {
                                    showCallErrorAlert = true
                                }
                            }
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "phone.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(AppTheme.Colors.accent)
                                
                                Text("지금 통화하기")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(AppTheme.Colors.dark)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 70)
                            .padding(.vertical, 16)
                            .background(AppTheme.Colors.light)
                            .cornerRadius(999)
                            .overlay(
                                RoundedRectangle(cornerRadius: 999)
                                    .stroke(AppTheme.Colors.light, lineWidth: 1)
                            )
                        }
                        .padding(.bottom, 57)
                    }
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: Destination.self) { destination in
                switch destination {
                case .settings:
                    SettingsView()
                        .environmentObject(coinViewModel)
                case .callTimeSetting:
                    CallTimeSettingView()
                case .privateSettings:
                    PrivateSettingView()
                case .pay:
                    PayView()
                        .environmentObject(coinViewModel)
                }
            }
            .fullScreenCover(isPresented: $showCallViewAsSheet) {
                CallView()
                    .id(callManager.callScreenPresentationID)
                    .environmentObject(userViewModel)
                    .environmentObject(coinViewModel)
            }
            .alert("통화 요청 완료", isPresented: $showCallRequestAlert) {
                Button("확인", role: .cancel) { }
            } message: {
                Text("곧 전화가 올거에요, 전화를 받아주세요!")
            }
            .onAppear {
                // CoinViewModel 사용자 ID 설정
                if let userId = userViewModel.userData.authId {
                    coinViewModel.setUserId(userId)
                    Task {
                        await coinViewModel.fetchCoinBalance()
                    }
                }
                
                if callManager.shouldShowCallScreen {
                    showCallViewAsSheet = true
                }
                
                setupCallScreenObserver()
            }
            .onChange(of: userViewModel.userData.authId) { newUserId in
                if let userId = newUserId {
                    coinViewModel.setUserId(userId)
                    Task {
                        await coinViewModel.fetchCoinBalance()
                    }
                }
            }
            .onChange(of: callManager.callError) { newValue in
                print("callError 변경 감지: \(newValue ?? "nil")")
                if newValue != nil {
                    DispatchQueue.main.async {
                        print("오류 알림 표시 시도")
                        showCallErrorAlert = true
                    }
                }
            }
            .onChange(of: callManager.shouldShowCallScreen) { newValue in
                if !newValue {
                    showCallViewAsSheet = false
                }
                // newValue가 true일 때는 setupCallScreenObserver에서 처리하므로 별도 로직 필요 없음
            }
            .alert("통화 요청 오류", isPresented: $showCallErrorAlert) {
                Button("확인", role: .cancel) { 
                    // 오류 확인 후 오류 상태 초기화
                    callManager.callError = nil
                }
            } message: {
                Text(callManager.callError ?? "알 수 없는 오류가 발생했습니다.")
            }
        }
    }
    
    private func setupCallScreenObserver() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("ShowCallScreen"), object: nil)
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ShowCallScreen"),
            object: nil,
            queue: .main) { _ in
                DispatchQueue.main.async {
                    showCallViewAsSheet = true
                }
            }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
            .environmentObject(UserViewModel())
            .environmentObject(CallManager.shared)
    }
}
