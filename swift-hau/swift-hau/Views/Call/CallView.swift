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
                    Task {
                        await connectAI()
                    }
                } else {
                    // 통화가 종료되면 AI 연결도 종료
                    disconnectAI()
                    dismiss()
                }
            }
            .onChange(of: callManager.shouldShowCallScreen) { newValue in
                if newValue == true {
                    callState = .preparing
                    Task {
                        await connectAI()
                    }
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
                print("세션 정보를 가져올 수 없습니다.")
                return nil
            }
            
            let userId = session.user.id.uuidString
            print("통화 기록 조회: 사용자 ID=\(userId)")
            
            // history 테이블에서 해당 사용자의 최근 3개 통화 기록 조회
            let response = try await client
                .from("history")
                .select("created_at, transcript")
                .eq("auth_id", value: userId)
                .order("created_at", ascending: false)
                .limit(3)
                .execute()
            
            if let jsonString = String(data: response.data, encoding: .utf8) {
                print("통화 기록 응답: \(jsonString)")
            }
            
            // 응답 JSON을 파싱해서 history 배열 생성
            if let jsonArray = try? JSONSerialization.jsonObject(with: response.data, options: []) as? [[String: Any]] {
                print("통화 기록 설정 완료: \(jsonArray.count)개 기록")
                callSettings["history"] = jsonArray
            } else {
                print("통화 기록 파싱 실패")
                callSettings["history"] = []
            }
        } catch {
            print("통화 기록 조회 오류: \(error.localizedDescription)")
        }
        
        // POST 요청 준비
        let url = URL(string: "http://192.168.0.5:3000/api/v1/realtime/sessions")!
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
                print("서버 응답: \(String(describing: resultData))")
            }
        } catch {
            print("토큰 요청 오류: \(error.localizedDescription)")
        }
        
        return resultData
    }

    private func connectAI() async {
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
            // 서버에 통화 설정을 포함하여 요청 전송
            Task {
                let serverResponse = await self.getTempToken()
                
                if let serverResponse = serverResponse,
                   let clientSecret = serverResponse["client_secret"] as? [String: Any],
                   let tokenValue = clientSecret["value"] as? String {
                    
                    // 통화 기록 생성 및 WebRTC 연결 초기화
                    do {
                        // 통화 기록 생성
                        await RealtimeAIConnection.shared.startCall()
                        
                        // WebRTC 연결 초기화
                        let success = await RealtimeAIConnection.shared.initialize(with: tokenValue)
                        
                        DispatchQueue.main.async {
                            if success {
                                print("AI 연결 성공!")
                                self.callState = .connected
                            } else {
                                print("AI 연결 실패")
                                // 연결 실패 시에도 통화 상태는 유지 (재시도 가능성)
                            }
                        }
                    } catch {
                        print("통화 시작 실패: \(error.localizedDescription)")
                    }
                } else {
                    print("서버 응답 처리 실패")
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

