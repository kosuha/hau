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
        VStack {
            if callManager.shouldShowCallScreen {
                VStack(spacing: 20) {
                    // 통화 상태에 따라 다른 메시지 표시
                    Group {
                        switch callState {
                        case .preparing:
                            Text("통화 준비 중...")
                                .font(.title)
                                .foregroundColor(.orange)
                        case .connected:
                            Text("통화 중...")
                                .font(.title)
                                .foregroundColor(.green)
                        case .disconnected:
                            Text("통화가 종료되었습니다")
                                .font(.title)
                                .foregroundColor(.red)
                        }
                    }
                    .padding()
                    
                    // 준비 중일 때는 프로그레스 인디케이터 표시
                    if callState == .preparing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(1.5)
                            .padding()
                    }
                    
                    Button("통화 종료") {
                        callState = .disconnected
                        callManager.endCall()
                        dismiss()
                    }
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding()
            } else {
                Text("통화 종료")
                Button("돌아가기") {
                    dismiss()
                }
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
            }
        }
        .onChange(of: callManager.shouldShowCallScreen) { newValue in
            if newValue == true {
                callState = .preparing
                connectAI()
            } else {
                disconnectAI()
                callState = .disconnected
            }
        }
        .onDisappear {
            // 화면이 사라질 때도 확실히 연결 종료
            disconnectAI()
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
        
        // 연결 상태 변경 콜백 설정
        RealtimeAIConnection.shared.onStateChange = { isConnected in
            DispatchQueue.main.async {
                if isConnected {
                    self.callState = .connected
                } else {
                    self.callState = .preparing
                }
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

