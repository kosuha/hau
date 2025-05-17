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
    // *** 타이머 관련 상태 변수 추가 끝 ***
    
    // *** 추가: 버튼 비활성화 상태 ***
    @State private var isEndingCall = false
    
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

                if callManager.shouldShowCallScreen {
                    VStack(spacing: 20) {
                        // 통화 상태
                        switch callState {
                        case .preparing:
                            Text("통화 준비 중...")
                                .font(.system(size: 20))
                                .foregroundColor(AppTheme.Colors.lightTransparent)
                                .padding()
                        case .connected:
                            Text(callDurationFormatted)
                                .font(.system(size: 20))
                                .foregroundColor(AppTheme.Colors.lightTransparent)
                                .padding()
                        case .disconnected:
                            Text("통화 종료")
                                .font(.system(size: 20))
                                .foregroundColor(AppTheme.Colors.lightTransparent)
                                .padding()
                        }

                        // 통화 상대
                        Text(userViewModel.userData.voice ?? "HAU")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(AppTheme.Colors.light)

                        Spacer()

                        Button(action: {
                            // *** 수정: 버튼 비활성화 상태 설정 ***
                            isEndingCall = true
                            callState = .disconnected
                            callManager.endCall()
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
                    .id(callState)
                    .padding(40)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                if callManager.shouldShowCallScreen {
                    resetCallTimer()
                    callState = .preparing
                    Task {
                        await connectAI()
                    }
                } else {
                    // 통화가 종료되면 AI 연결도 종료 (이 경우는 거의 없을 것으로 예상)
                    disconnectAI()
                    dismiss()
                }
            }
            .onDisappear {
                disconnectAI()
            }
        }
    }
    
    // MARK: - Timer Functions (추가)
    private func startCallTimer() {
        // 기존 타이머가 있다면 중지
        stopCallTimer()
        // 매초마다 callDurationSeconds를 업데이트하고 포맷팅
        callTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            callDurationSeconds += 1
            callDurationFormatted = formatTime(seconds: callDurationSeconds)
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
            "history": []
        ]
        
        // 사용자 정보 추가
        if let birthdate = userViewModel.userData.birthdate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            callSettings["birthdate"] = formatter.string(from: birthdate)
        }
        
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
        resetCallTimer()
        callState = .preparing
        
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
                } else {
                    // 연결 실패/끊김 콜백: connected 상태일 때만 disconnected로 변경
                    if self.callState == .connected {
                        self.callState = .disconnected
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
        callState = .disconnected
    }
}

// preview
struct CallView_Previews: PreviewProvider {
    static var previews: some View {
        CallView()
    }
}

