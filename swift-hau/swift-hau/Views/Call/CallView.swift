//
//  CallView.swift
//  swift-hau
//
//  Created by Seonho Kim on 4/11/25.
//

import SwiftUI
import PushKit
import CallKit
import AVFoundation
import Supabase

struct CallView: View {
    @StateObject private var callManager = CallManager.shared
    @Environment(\.dismiss) private var dismiss
    
    // UserViewModel 주입
    @EnvironmentObject var userViewModel: UserViewModel
    // CoinViewModel 주입
    @EnvironmentObject var coinViewModel: CoinViewModel
    
    // *** 추가: 최대 통화 시간 상수 (20분 = 1200초) - 표시용으로만 사용 ***
    private let maxCallDurationSeconds = 1200
    
    // 통화 준비 상태 추적
    @State private var callState: CallState = .preparing {
        didSet {
            // *** 수정: callState 변경에 따른 타이머 로직 호출 ***
            if callState == .connected {
                startCallTimer()
            } else if callState == .disconnected {
                stopCallTimer()
            }
        }
    }
    
    // 타이머 관련 상태 변수 추가 시작
    @State private var callTimer: Timer? = nil
    @State private var callDurationSeconds: Int = 0
    @State private var callDurationFormatted: String = "00:00"
    // *** 19분 경고 관련 상태 변수 제거 ***
    // *** 타이머 관련 상태 변수 추가 끝 ***
    
    // *** 추가: 버튼 비활성화 상태 ***
    @State private var isEndingCall = false
    
    // *** 추가: 연결 시도 중복 방지 플래그 ***
    @State private var isConnecting = false
    
    // 통화 상태 정의
    enum CallState {
        case preparing   // 준비 중
        case connected   // 연결됨
        case disconnected // 연결 해제됨
    }
    
    var body: some View {
        ZStack {
            AppTheme.Gradients.primary
                    .ignoresSafeArea()

            VStack {
                // CallView는 항상 표시되고, shouldShowCallScreen이 false이면 자동으로 dismiss
                VStack(spacing: 20) {
                    // 통화 상태
                    switch callState {
                    case .preparing:
                        Text("통화 준비 중...")
                            .font(.system(size: 20))
                            .foregroundColor(AppTheme.Colors.lightTransparent)
                            .padding()
                    case .connected:
                        VStack(spacing: 8) {
                            HStack(spacing: 10) {
                                // 프라이빗 모드 아이콘 표시
                                if callManager.isPrivateMode {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(AppTheme.Colors.lightTransparent)
                                }

                                Text(callDurationFormatted)
                                    .font(.system(size: 20))
                                    .foregroundColor(AppTheme.Colors.lightTransparent)
                            }
                        }
                        .padding()
                    case .disconnected:
                        Text("통화 종료")
                            .font(.system(size: 20))
                            .foregroundColor(AppTheme.Colors.lightTransparent)
                            .padding()
                    }

                    // 통화 상대
                    Text("하우")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(AppTheme.Colors.light)

                    Spacer()

                    Button(action: {
                        endCallAction()
                    }) {
                        Image(systemName: "phone.down.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                    }
                    .disabled(isEndingCall)
                    .padding(20)
                    .frame(width: 84, height: 84)
                    .background(Color.red)
                    .opacity(isEndingCall ? 0.5 : 1.0)
                    .foregroundColor(.white)
                    .cornerRadius(999)
                }
                .padding(40)
            }
            .navigationBarHidden(true)
            .onAppear {
                print("CallView: onAppear - shouldShowCallScreen: \(callManager.shouldShowCallScreen)")
                
                // RealtimeAIConnection에 CoinViewModel 설정
                RealtimeAIConnection.shared.setCoinViewModel(coinViewModel)
                
                // CallView가 표시될 때 항상 초기화하고 연결 시도
                if !isConnecting {
                    // 초기 상태를 무조건 preparing으로 설정
                    callState = .preparing
                    
                    resetCallTimer()
                    
                    Task {
                        await connectAI()
                    }
                }
            }
            .onDisappear {
                print("CallView: onDisappear")
                // CallView가 사라질 때 AI 연결 해제
                disconnectAI()
                Task {
                    await coinViewModel.fetchCoinBalance()
                }
            }
            .onChange(of: callManager.shouldShowCallScreen) { oldValue, newValue in
                // shouldShowCallScreen이 false가 되면 화면을 닫음
                if !newValue {
                    print("CallView: shouldShowCallScreen이 false로 변경되어 화면을 닫습니다.")
                    dismiss()
                }
            }
        }
    }
    
    // *** 추가: 통화 종료 액션 메서드 ***
    private func endCallAction() {
        print("CallView: 통화 종료 버튼 클릭")
        // *** 수정: 버튼 비활성화 상태 설정 ***
        isEndingCall = true
        callState = .disconnected
        
        // AI 연결 해제
        disconnectAI()
        
        // CallManager의 통화 종료 처리
        callManager.endCall()
        
        // 화면 닫기는 CallManager의 shouldShowCallScreen 변경에 의해 자동으로 처리됨
    }
    
    // MARK: - Timer Functions (추가)
    private func startCallTimer() {
        // 기존 타이머가 있다면 중지
        stopCallTimer()
        // 매초마다 callDurationSeconds를 업데이트하고 포맷팅
        callTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            callDurationSeconds += 1
            callDurationFormatted = formatTime(seconds: callDurationSeconds)
            
            // *** 수정: RealtimeAIConnection과 동기화만 수행 (시간 제한 체크는 RealtimeAIConnection에서 처리) ***
            RealtimeAIConnection.shared.syncCallDuration(seconds: callDurationSeconds)
        }
    }
    
    private func stopCallTimer() {
        callTimer?.invalidate()
        callTimer = nil
    }
    
    private func resetCallTimer() {
        stopCallTimer()
        callDurationSeconds = 0
        callDurationFormatted = "00:00"
        // *** 상태 초기화 코드 제거 - RealtimeAIConnection에서 처리 ***
    }
    
    // 초를 "MM:SS" 형식으로 변환하는 헬퍼 함수
    private func formatTime(seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
    // *** Timer Functions 끝 ***

    private func getTempToken() async -> [String: Any]? {
        // 서버에 요청하여 openai 임시 토큰 발급
        var resultData: [String: Any]? = nil
        
        // 통화 설정 데이터 준비
        var callSettings: [String: Any] = [
            "language": "ko", // 사용할 언어
            "user_name": userViewModel.userData.name ?? "사용자",  // 사용자 이름
            "history": [],
            "private_mode": callManager.isPrivateMode // 프라이빗 모드 상태 전달
        ]
        
        if let selfIntro = userViewModel.userData.selfIntro {
            callSettings["self_intro"] = selfIntro
        }
        
        if let voice = userViewModel.userData.voice {
            callSettings["voice"] = voice
        }
        
        // Supabase에서 통화 기록 가져오기
        do {
            guard let session = try? await client.auth.session else {
                return nil
            }
            
            let userId = session.user.id.uuidString
            
            // history 테이블에서 해당 사용자의 최근 3개 통화 기록 조회
            let response = try await client
                .from("history")
                .select("created_at, transcript")
                .eq("auth_id", value: userId)
                .order("created_at", ascending: false)
                .limit(3)
                .execute()
            
            // 응답 JSON을 파싱해서 history 배열 생성
            if let jsonArray = try? JSONSerialization.jsonObject(with: response.data, options: []) as? [[String: Any]] {
                callSettings["history"] = jsonArray
            } else {
                callSettings["history"] = []
            }
        } catch {
            print("통화 기록 조회 오류: \(error.localizedDescription)")
        }
        
        // POST 요청 준비
        let url = URL(string: "\(AppConfig.baseURL)/realtime/sessions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            // 설정 값을 요청 본문에 포함
            request.httpBody = try JSONSerialization.data(withJSONObject: callSettings)
            
            // URLSession을 async/await 방식으로 사용
            let (data, _) = try await URLSession.shared.data(for: request)
            
            if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                resultData = jsonObject
            }
        } catch {
            print("토큰 요청 오류: \(error.localizedDescription)")
        }
        
        return resultData
    }

    private func connectAI() async {
        // 이미 통화 중인 경우 중복 실행 방지
        if callManager.isCallInProgress && callState == .connected {
            return
        }
        
        // 연결 시도 중복 방지
        if isConnecting {
            return
        }
        
        // AI 연결이 이미 되어 있는 경우 중복 방지
        if RealtimeAIConnection.shared.isConnected {
            DispatchQueue.main.async {
                if self.callState == .preparing {
                    self.callState = .connected
                }
            }
            return
        }
        
        isConnecting = true
        defer { isConnecting = false }
        
        resetCallTimer()
        
        DispatchQueue.main.async {
            self.callState = .preparing
        }
        
        // 콜백 제거 먼저 수행 (유지)
        RealtimeAIConnection.shared.onStateChange = nil
        
        // 기존 연결 종료 (유지)
        RealtimeAIConnection.shared.disconnect()
        
        // *** 수정: onStateChange 콜백 설정 위치 변경 및 로직 강화 ***
        RealtimeAIConnection.shared.onStateChange = { isConnected in
            DispatchQueue.main.async {
                if isConnected {
                    // 연결 성공 콜백: preparing 상태일 때만 connected로 변경
                    if self.callState == .preparing {
                        self.callState = .connected
                    }
                }
            }
        }
        
        // CallManager 설정 (유지)
        RealtimeAIConnection.shared.setCallManager(callManager)
        
        // 서버에 통화 설정을 포함하여 요청 전송
        Task {
            let serverResponse = await self.getTempToken()
            
            if let serverResponse = serverResponse,
               let clientSecret = serverResponse["client_secret"] as? [String: Any],
               let tokenValue = clientSecret["value"] as? String {
                
                // RealtimeAIConnection.startCall() 호출하고 결과 확인
                let canStartCall = await RealtimeAIConnection.shared.startCall()
                
                if canStartCall {
                    // startCall이 true를 반환한 경우 (포인트 충분 등)에만 initialize 호출
                    let initSuccess = await RealtimeAIConnection.shared.initialize(with: tokenValue)
                    
                    if initSuccess {
                        DispatchQueue.main.async {
                            if self.callState == .preparing { 
                                self.callState = .connected
                            }
                        }
                    } else {
                        // initialize 실패
                        DispatchQueue.main.async {
                            self.callState = .disconnected
                            self.callManager.shouldShowCallScreen = false // 화면 닫기
                            // 사용자에게 알림 (예: "AI 서버 연결에 실패했습니다.")
                        }
                    }
                } else {
                    // startCall이 false를 반환한 경우 (포인트 부족 등)
                    DispatchQueue.main.async {
                        self.callState = .disconnected
                        self.callManager.shouldShowCallScreen = false // 화면 닫기
                        // 사용자에게 알림 (예: "포인트가 부족하여 통화를 시작할 수 없습니다.")
                        // 여기에 사용자 알림 로직 추가 가능 (e.g., Alert)
                    }
                }
                // getTempToken은 성공하고 startCall/initialize에서 문제가 생기는 경우를 다룹니다.
                // getTempToken 자체가 실패하면 바깥 else에서 처리됩니다.
                
            } else {
                // 토큰 가져오기 실패 처리
                DispatchQueue.main.async {
                    self.callState = .disconnected
                    self.callManager.shouldShowCallScreen = false
                }
            }
        }
    }

    private func disconnectAI() {
        // openai webrtc 연결 해제
        RealtimeAIConnection.shared.disconnect()
        
        DispatchQueue.main.async {
            self.callState = .disconnected
        }
    }
}

// preview
struct CallView_Previews: PreviewProvider {
    static var previews: some View {
        CallView()
    }
}

