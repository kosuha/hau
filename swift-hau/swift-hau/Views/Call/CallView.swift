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

struct CallView: View {
    @StateObject private var callManager = CallManager.shared
    @Environment(\.dismiss) private var dismiss
    
    // 통화 준비 상태 추적
    @State private var callState: CallState = .preparing
    
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
                // if true {
                    VStack(spacing: 20) {
                        // 통화 상태
                        Group {
                            switch callState {
                            case .preparing:
                                Text("통화 준비 중...")
                                    .font(.system(size: 20))
                                    .foregroundColor(AppTheme.Colors.lightTransparent)
                            case .connected:
                                Text("12:34")
                                    .font(.system(size: 20))
                                    .foregroundColor(AppTheme.Colors.lightTransparent)
                            case .disconnected:
                                Text("통화 종료")
                                    .font(.system(size: 20))
                                    .foregroundColor(AppTheme.Colors.lightTransparent)
                            }
                        }
                        .padding()

                        // 통화 상대
                        Text("범수")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(AppTheme.Colors.light)

                        Spacer()

                        Button(action: {
                            callState = .disconnected
                            callManager.endCall()
                            dismiss()
                        }) {
                            Image(systemName: "phone.down.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                        }
                        .padding(20)
                        .frame(width: 84, height: 84)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(999)
                    }
                    .padding(40)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                if callManager.shouldShowCallScreen {
                    // 통화 시작 시 상태를 '준비 중'으로 설정
                    callState = .preparing
                    // AI 연결 시작
                    connectAI()
                } else {
                    // 통화가 종료되면 AI 연결도 종료
                    disconnectAI()
                    dismiss()
                }
            }
            .onChange(of: callManager.shouldShowCallScreen) { newValue in
                if newValue == true {
                    callState = .preparing
                    connectAI()
                } else {
                    disconnectAI()
                    callState = .disconnected
                    dismiss()
                }
            }
            .onDisappear {
                // 화면이 사라질 때도 확실히 연결 종료
                disconnectAI()
                
                // 통화 상태 리셋 및 스택 정리
                callManager.resetCallStatus()
            }
        }
    }
    
    private func getTempToken() -> [String: Any]? {
        // 서버에 요청하여 openai 임시 토큰 발급
        let semaphore = DispatchSemaphore(value: 0)
        var resultData: [String: Any]? = nil
        
        let url = URL(string: "http://192.168.0.5:3000/api/v1/realtime/sessions")!
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data, error == nil {
                resultData = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            }
            semaphore.signal()
        }.resume()
        
        _ = semaphore.wait(timeout: .now() + 10)
        return resultData
    }

    private func connectAI() {
        print("AI 연결 시작...")
        callState = .preparing
        
        // 기존 연결 종료
        RealtimeAIConnection.shared.disconnect()
        
        // CallManager 설정
        RealtimeAIConnection.shared.setCallManager(callManager)
        
        // 콜백 설정 - 통화 상태 변경과 통화 종료 처리
        RealtimeAIConnection.shared.onStateChange = { isConnected in
            DispatchQueue.main.async {
                if isConnected {
                    self.callState = .connected
                } else if self.callState == .connected {
                    // 이미 연결된 상태에서만 끊김 처리
                    // 초기화 중에는 disconnected로 처리하지 않음
                    self.callState = .disconnected
                    
                    // 연결 끊김 시 통화 종료
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.dismiss()
                    }
                }
                // 초기 상태에서는 아무 동작 안함
            }
        }
        
        // 딜레이 추가 - 연결 해제가 완료되도록
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // 서버에 요청하여 openai 임시 토큰 발급
            let data = self.getTempToken()
            
            if let data = data,
               let clientSecret = data["client_secret"] as? [String: Any],
               let tokenValue = clientSecret["value"] as? String {
                
                // WebRTC 연결 초기화
                RealtimeAIConnection.shared.initialize(with: tokenValue) { success in
                    DispatchQueue.main.async {
                        if success {
                            print("AI 연결 성공!")
                            self.callState = .connected
                        } else {
                            print("AI 연결 실패")
                            // 연결 실패 시에도 통화 상태는 유지 (재시도 가능성)
                        }
                    }
                }
            } else {
                print("토큰 발급 실패")
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

