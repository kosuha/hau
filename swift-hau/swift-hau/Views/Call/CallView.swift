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
    @EnvironmentObject var authViewModel: AuthViewModel
    
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
    
    // 오디오 재생용 추가
    @State private var audioEngine: AVAudioEngine?
    @State private var audioPlayerNode: AVAudioPlayerNode?
    
    // 오디오 플레이어 강한 참조 유지를 위한 변수
    @State private var currentAudioPlayer: AVAudioPlayer?
    
    // 오디오 재생 큐 관리 변수 추가
    @State private var audioQueue: [Data] = []
    @State private var isProcessingAudio = false
    @State private var lastAudioSampleRate: Float = 24000.0
    
    // 오디오 버퍼링 변수 추가
    @State private var audioBuffer: Data = Data()
    @State private var bufferTargetSize: Int = 48000 // 약 1초 분량 (24000Hz * 2bytes * 1초) - 끊김 방지를 위해 증가
    @State private var lastBufferPlayTime: Date = Date()
    
    // MARK: - 새로 추가: 오디오 인터럽트 관리 변수
    @State private var isUserSpeaking = false // 사용자가 말하고 있는지 추적
    @State private var shouldInterruptPlayback = false // 재생 중단 플래그
    @State private var audioPlaybackQueue = DispatchQueue(label: "audio.playback", qos: .userInitiated) // 오디오 재생 전용 큐
    
    // MARK: - 새로 추가: 안정적인 오디오 재생을 위한 추가 변수
    @State private var minimumBufferSize: Int = 24000 // 최소 0.5초 분량
    @State private var isWaitingForMoreAudio = false // 더 많은 오디오를 기다리는 중인지 추적
    
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
        resetCallTimer()
        callState = .preparing
        
        // MARK: - 오디오 엔진 설정 (임시 비활성화)
        // setupAudioEngine()
        
        // MARK: - Gemini Live API WebSocket 연결 (새로운 방식)
        
        // 기존 연결 종료
        await GeminiLiveConnection.shared.disconnect()
        
        // 상태 변경 콜백 설정
        GeminiLiveConnection.shared.onStateChange = { isConnected in
            DispatchQueue.main.async {
                if isConnected {
                    if self.callState == .preparing {
                        self.callState = .connected
                    }
                } else {
                    if self.callState == .connected {
                        self.callState = .disconnected
                    }
                }
            }
        }
        
        // 오디오 수신 콜백 설정
        GeminiLiveConnection.shared.onAudioReceived = { audioData, mimeType in
            // mimeType에서 샘플레이트 정보 추출
            let sampleRate = self.extractSampleRate(from: mimeType!)
            print("🎵 수신된 오디오 - 크기: \(audioData.count) bytes, mimeType: \(mimeType ?? "없음"), 샘플레이트: \(sampleRate)Hz")
            
            // 수신된 오디오 데이터를 재생하는 로직 구현
            self.playReceivedAudio(audioData, mimeType: mimeType ?? "")
        }
        
        // 텍스트 응답 수신 콜백 설정
        GeminiLiveConnection.shared.onTranscriptReceived = { transcript in
            DispatchQueue.main.async {
                // 텍스트 응답 처리 (필요시 UI 업데이트)
                print("AI 응답: \(transcript)")
            }
        }
        
        // MARK: - 새로 추가: 오디오 인터럽트 관련 콜백 설정
        
        // 턴 완료 시 오디오 버퍼 정리 (Python 예제의 turn_complete 패턴)
        GeminiLiveConnection.shared.onTurnComplete = {
            DispatchQueue.main.async {
                print("🔄 턴 완료 감지 - 오디오 버퍼 정리")
                self.clearAudioBuffers()
                self.resumeAudioPlayback() // 새로운 응답을 받을 준비
            }
        }
        
        // 사용자 발화 시작 시 오디오 재생 중단
        GeminiLiveConnection.shared.onUserSpeechStarted = {
            DispatchQueue.main.async {
                print("🎤 사용자 발화 시작 - 오디오 재생 중단")
                self.interruptAudioPlayback()
            }
        }
        
        // 사용자 발화 종료 시 오디오 재생 재개 준비
        GeminiLiveConnection.shared.onUserSpeechStopped = {
            DispatchQueue.main.async {
                print("🛑 사용자 발화 종료 - 오디오 재생 재개 준비")
                self.resumeAudioPlayback()
            }
        }
        
        // 사용자 데이터 준비
        let userName = userViewModel.userData.name
        let selfIntro = userViewModel.userData.selfIntro
        let voice = userViewModel.userData.voice
        
        // 통화 기록 가져오기
        var history: [HistoryResponse]? = nil
        do {
            guard let session = try? await client.auth.session else {
                return
            }
            
            let userId = session.user.id.uuidString
            
            // history 테이블에서 해당 사용자의 최근 3개 통화 기록 조회
            let historyRecords: [HistoryResponse] = try await client
                .from("history")
                .select()
                .eq("auth_id", value: userId)
                .order("created_at", ascending: false)
                .limit(3)
                .execute()
                .value
            
            history = historyRecords
        } catch {
            print("통화 기록 조회 오류: \(error.localizedDescription)")
        }
        
        // WebSocket 연결 시작
        let connectionSuccess = await GeminiLiveConnection.shared.initialize(
            userName: userName,
            selfIntro: selfIntro,
            voice: voice,
            history: history,
            language: "ko"
        )
        
        if !connectionSuccess {
            DispatchQueue.main.async {
                self.callState = .disconnected
                self.callManager.shouldShowCallScreen = false
            }
        }
        
        // MARK: - 기존 WebRTC 방식 (호환성을 위해 주석 처리하되 유지)
        /*
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
        */
    }

    // MARK: - AI 연결 해제 시 오디오 정리
    private func disconnectAI() {
        // 기존 오디오 관련 정리
        currentAudioPlayer?.stop()
        currentAudioPlayer = nil
        
        // 오디오 엔진 정리
        audioPlayerNode?.stop()
        audioEngine?.stop()
        audioPlayerNode = nil
        audioEngine = nil
        
        // 버퍼와 큐 초기화
        audioQueue.removeAll()
        audioBuffer = Data()
        isProcessingAudio = false
        
        // MARK: - 새로 추가: 오디오 인터럽트 상태 초기화
        isUserSpeaking = false
        shouldInterruptPlayback = false
        isWaitingForMoreAudio = false
        
        print("🔍 AI 연결 해제 및 오디오 버퍼 정리 완료")
        
        // Gemini Live 연결 종료
        Task {
            await GeminiLiveConnection.shared.disconnect()
        }
    }
    
    // MARK: - 수신된 오디오 재생
    private func playReceivedAudio(_ audioData: Data, mimeType: String) {
        // MARK: - 새로 추가: 사용자가 말하고 있으면 재생하지 않음
        if isUserSpeaking || shouldInterruptPlayback {
            print("🚫 사용자 발화 중이므로 오디오 재생 건너뜀")
            return
        }
        
        // mimeType에서 샘플레이트 파싱
        let sampleRate = extractSampleRate(from: mimeType)
        print("🎵 수신된 오디오 - 크기: \(audioData.count) bytes, mimeType: \(mimeType), 샘플레이트: \(sampleRate)Hz")
        
        // 샘플레이트 저장
        lastAudioSampleRate = sampleRate
        
        // 오디오 데이터를 버퍼에 추가
        audioBuffer.append(audioData)
        print("🔍 오디오 버퍼에 추가 - 현재 버퍼 크기: \(audioBuffer.count) bytes, 목표: \(bufferTargetSize) bytes")
        
        // MARK: - 수정: 더 보수적인 버퍼링 전략으로 끊김 최소화
        let currentTargetSize: Int
        let timeSinceLastPlay = Date().timeIntervalSince(lastBufferPlayTime)
        
        // 재생 중이거나 이미 처리 중이면 더 큰 버퍼를 요구
        if isProcessingAudio || isWaitingForMoreAudio {
            currentTargetSize = bufferTargetSize * 2 // 2초 분량
            print("🔍 재생 중이므로 더 큰 버퍼 요구: \(currentTargetSize) bytes")
        } else {
            currentTargetSize = bufferTargetSize // 1초 분량
            print("🔍 첫 재생이므로 기본 버퍼 크기: \(currentTargetSize) bytes")
        }
        
        // 더 엄격한 재생 조건 - 끊김 방지 우선
        let hasEnoughBuffer = audioBuffer.count >= currentTargetSize
        let hasMinimumBuffer = audioBuffer.count >= minimumBufferSize
        let hasBeenWaitingTooLong = timeSinceLastPlay > 2.0 // 2초 대기 후 강제 재생
        let hasEmergencyBuffer = audioBuffer.count > 12000 && timeSinceLastPlay > 1.0 // 0.5초 분량이고 1초 대기
        
        print("🔍 재생 조건 체크:")
        print("  - 충분한 버퍼: \(hasEnoughBuffer) (\(audioBuffer.count)/\(currentTargetSize))")
        print("  - 최소 버퍼: \(hasMinimumBuffer) (\(audioBuffer.count)/\(minimumBufferSize))")
        print("  - 오래 대기: \(hasBeenWaitingTooLong) (\(String(format: "%.1f", timeSinceLastPlay))초)")
        print("  - 응급 버퍼: \(hasEmergencyBuffer)")
        print("  - 처리 중: \(isProcessingAudio)")
        
        let shouldPlayBuffer = !isProcessingAudio && (
            hasEnoughBuffer || 
            (hasMinimumBuffer && hasBeenWaitingTooLong) ||
            hasEmergencyBuffer
        )
        
        if shouldPlayBuffer {
            if !hasEnoughBuffer {
                print("⚠️ 버퍼가 충분하지 않지만 대기 시간으로 인해 재생 시작")
                isWaitingForMoreAudio = true
            } else {
                isWaitingForMoreAudio = false
            }
            playBufferedAudio()
        } else if !isProcessingAudio {
            print("🔍 재생 조건 미충족, 더 많은 오디오 대기 중...")
            isWaitingForMoreAudio = true
        }
    }
    
    // MARK: - 오디오 버퍼 재생
    private func playBufferedAudio() {
        guard !isProcessingAudio, !audioBuffer.isEmpty else {
            return
        }
        
        // MARK: - 새로 추가: 재생 시작 시 인터럽트 플래그 확인
        if shouldInterruptPlayback {
            print("🚫 재생 인터럽트 플래그가 설정됨, 재생 중단")
            clearAudioBuffers()
            return
        }
        
        isProcessingAudio = true
        let bufferedData = audioBuffer
        audioBuffer = Data() // 버퍼 초기화
        lastBufferPlayTime = Date()
        
        print("🔍 버퍼된 오디오 재생 시작 - 크기: \(bufferedData.count) bytes (\(String(format: "%.2f", Double(bufferedData.count) / (Double(lastAudioSampleRate) * 2.0)))초)")
        
        // 기본 AVAudioPlayer 방식으로 강제 재생
        print("🎵 기본 AVAudioPlayer 방식으로 재생")
        playReceivedAudioAlternative(bufferedData, sampleRate: lastAudioSampleRate)
    }
    
    // MARK: - 새로 추가: 오디오 재생 중단 및 버퍼 정리 함수들
    
    /// 사용자가 말을 시작할 때 호출 - 현재 재생 중인 오디오를 중단하고 버퍼를 비움
    private func interruptAudioPlayback() {
        print("🚫 오디오 재생 인터럽트 시작")
        
        shouldInterruptPlayback = true
        isUserSpeaking = true
        
        // 현재 재생 중인 오디오 즉시 중단
        audioPlaybackQueue.async {
            self.currentAudioPlayer?.stop()
            DispatchQueue.main.async {
                self.currentAudioPlayer = nil
                self.clearAudioBuffers()
                print("✅ 현재 재생 중인 오디오 중단 완료")
            }
        }
    }
    
    /// 사용자 발화가 끝났을 때 호출 - 새로운 AI 응답을 받을 준비
    private func resumeAudioPlayback() {
        print("✅ 사용자 발화 종료, 오디오 재생 재개 준비")
        
        isUserSpeaking = false
        shouldInterruptPlayback = false
        
        // 버퍼에 대기 중인 오디오가 있으면 재생 시작
        if !audioBuffer.isEmpty && !isProcessingAudio {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.playBufferedAudio()
            }
        }
    }
    
    /// turn_complete와 유사한 역할 - 모든 오디오 버퍼와 큐를 비움
    private func clearAudioBuffers() {
        print("🧹 모든 오디오 버퍼 및 큐 정리")
        
        // 모든 오디오 관련 상태 초기화
        audioBuffer = Data()
        audioQueue.removeAll()
        isProcessingAudio = false
        isWaitingForMoreAudio = false
        
        // 재생 중인 오디오도 중단
        currentAudioPlayer?.stop()
        currentAudioPlayer = nil
        
        // 오디오 엔진도 정리
        audioPlayerNode?.stop()
        audioPlayerNode = nil
    }
    
    // MARK: - 재생 완료 시 호출될 함수 (수정됨)
    private func audioPlaybackCompleted() {
        print("🔍 버퍼된 오디오 재생 완료")
        isProcessingAudio = false
        isWaitingForMoreAudio = false
        
        // 인터럽트 플래그가 설정되어 있으면 버퍼를 비우고 종료
        if shouldInterruptPlayback {
            print("🚫 재생 완료 후 인터럽트 플래그 확인됨, 버퍼 정리")
            clearAudioBuffers()
            return
        }
        
        // 버퍼에 새로운 오디오가 쌓여있고 사용자가 말하고 있지 않으면 바로 재생
        if !audioBuffer.isEmpty && !isUserSpeaking {
            print("🔍 버퍼에 \(audioBuffer.count) bytes 대기 중, 즉시 다음 재생 시도")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { // 더 짧은 간격으로 다음 재생
                self.playBufferedAudio()
            }
        } else {
            print("🔍 재생할 오디오 없음 또는 사용자 발화 중")
        }
    }
    
    // MARK: - 오디오 재생 엔진 초기화
    private func setupAudioPlayback() {
        // 기존 엔진 정리
        audioPlayerNode?.stop()
        audioEngine?.stop()
        audioPlayerNode = nil
        audioEngine = nil
        
        // 새로운 오디오 엔진 생성
        audioEngine = AVAudioEngine()
        audioPlayerNode = AVAudioPlayerNode()
        
        guard let engine = audioEngine,
              let playerNode = audioPlayerNode else {
            print("❌ 오디오 엔진 생성 실패")
            return
        }
        
        // 먼저 노드를 엔진에 연결
        engine.attach(playerNode)
        
        // 출력 노드의 포맷 확인
        let outputFormat = engine.outputNode.inputFormat(forBus: 0)
        print("🔍 출력 노드 포맷: \(outputFormat)")
        
        // 방법 1: 출력 노드와 동일한 포맷으로 연결 시도
        do {
            engine.connect(playerNode, to: engine.outputNode, format: outputFormat)
            try engine.start()
            print("✅ 오디오 재생 엔진 시작 성공 (출력 노드 포맷)")
            return
        } catch {
            print("❌ 출력 노드 포맷으로 시작 실패: \(error)")
        }
        
        // 방법 2: 기본 포맷으로 연결 시도 (포맷 자동 변환)
        do {
            // 기존 연결 해제
            engine.disconnectNodeOutput(playerNode)
            
            // 포맷 없이 연결 (자동 변환)
            engine.connect(playerNode, to: engine.outputNode, format: nil)
            try engine.start()
            print("✅ 오디오 재생 엔진 기본 포맷으로 시작 성공")
            return
        } catch {
            print("❌ 기본 포맷으로도 시작 실패: \(error)")
        }
        
        // 방법 3: 표준 포맷으로 시도
        if let standardFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2) {
            do {
                engine.disconnectNodeOutput(playerNode)
                engine.connect(playerNode, to: engine.outputNode, format: standardFormat)
                try engine.start()
                print("✅ 오디오 재생 엔진 표준 포맷으로 시작 성공")
                return
            } catch {
                print("❌ 표준 포맷으로도 시작 실패: \(error)")
            }
        }
        
        print("❌ 모든 오디오 엔진 초기화 방법 실패")
        // 엔진 정리
        engine.detach(playerNode)
        audioPlayerNode = nil
        audioEngine = nil
    }
    
    // MARK: - 대안 오디오 재생 함수 (WAV 형식)
    private func playReceivedAudioAlternative(_ audioData: Data, sampleRate: Float) {
        print("🎵 대안 오디오 재생 시작 (데이터: \(audioData.count) bytes, \(sampleRate)Hz)")
        
        // 기존 플레이어 정지
        currentAudioPlayer?.stop()
        currentAudioPlayer = nil
        print("🔍 기존 플레이어 정리 완료")
        
        // 오디오 세션 카테고리 임시 변경
        let audioSession = AVAudioSession.sharedInstance()
        let originalCategory = audioSession.category
        let originalMode = audioSession.mode
        let originalOptions = audioSession.categoryOptions
        
        do {
            print("🔍 현재 오디오 세션: \(originalCategory), \(originalMode), options: \(originalOptions)")
            
            // MARK: - 수정: 더욱 강화된 오디오 세션 설정으로 끊김 방지
            // VoIP 통화 중에도 오디오 재생이 가능하도록 설정
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [
                .defaultToSpeaker, 
                .allowBluetooth, 
                .allowBluetoothA2DP,
                .mixWithOthers, // 다른 오디오와 혼합 허용
                .duckOthers, // 다른 오디오의 볼륨을 낮춤
                .interruptSpokenAudioAndMixWithOthers // 음성 오디오 중단하고 혼합
            ])
            
            // 오디오 세션 활성화 - 여러 번 시도
            var activationSuccess = false
            for attempt in 1...3 {
                do {
                    try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                    activationSuccess = true
                    print("✅ 오디오 세션 활성화 성공 (시도 \(attempt))")
                    break
                } catch {
                    print("⚠️ 오디오 세션 활성화 실패 (시도 \(attempt)): \(error)")
                    if attempt < 3 {
                        Thread.sleep(forTimeInterval: 0.1)
                    }
                }
            }
            
            if !activationSuccess {
                print("❌ 오디오 세션 활성화 최종 실패")
            }
            
            print("✅ 오디오 세션을 VoIP 호환 모드로 설정: .playAndRecord + .voiceChat + 혼합 옵션")
            
            // 스피커로 강제 출력
            try audioSession.overrideOutputAudioPort(.speaker)
            print("✅ 스피커 출력으로 강제 설정")
            
            // 현재 오디오 라우트 정보 출력
            let currentRoute = audioSession.currentRoute
            print("🔍 변경 후 오디오 라우트:")
            for output in currentRoute.outputs {
                print("  - 출력: \(output.portName) (\(output.portType.rawValue))")
            }
            
        } catch {
            print("⚠️ 오디오 세션 카테고리 변경 실패: \(error.localizedDescription)")
            
            // 기존 방식으로 fallback
            do {
                if !audioSession.isOtherAudioPlaying {
                    try audioSession.setActive(true)
                    try audioSession.overrideOutputAudioPort(.speaker)
                    print("✅ 기존 방식으로 오디오 세션 설정")
                }
            } catch {
                print("⚠️ 기존 방식 오디오 세션 설정도 실패: \(error.localizedDescription)")
            }
        }
        
        // WAV 헤더 생성
        print("🔍 WAV 데이터 생성 시작...")
        let wavData = createWAVData(from: audioData, sampleRate: sampleRate)
        print("🔍 WAV 데이터 생성 완료: \(wavData.count) bytes (원본: \(audioData.count) bytes)")
        
        // WAV 데이터 유효성 검사
        guard wavData.count > 44 else {
            print("❌ WAV 데이터가 너무 작음: \(wavData.count) bytes")
            restoreAudioSession(originalCategory: originalCategory, originalMode: originalMode)
            return
        }
        
        // 시스템 볼륨 확인
        print("🔍 시스템 볼륨: \(audioSession.outputVolume)")
        
        do {
            print("🔍 AVAudioPlayer 생성 시작...")
            let audioPlayer = try AVAudioPlayer(data: wavData)
            print("✅ AVAudioPlayer 생성 성공")
            
            // 플레이어 설정
            audioPlayer.volume = 1.0
            audioPlayer.numberOfLoops = 0
            audioPlayer.enableRate = false
            
            // 강한 참조 유지
            currentAudioPlayer = audioPlayer
            print("🔍 플레이어 참조 설정 완료, 볼륨: \(audioPlayer.volume)")
            
            // MARK: - 수정: 더 안정적인 재생을 위한 준비 과정 강화
            print("🔍 플레이어 준비 시작...")
            
            // 여러 번 prepareToPlay 시도
            var prepareSuccess = false
            for attempt in 1...3 {
                prepareSuccess = audioPlayer.prepareToPlay()
                print("🔍 준비 시도 \(attempt): \(prepareSuccess ? "성공" : "실패")")
                if prepareSuccess { break }
                Thread.sleep(forTimeInterval: 0.01) // 10ms 대기 후 재시도
            }
            
            print("🔍 오디오 플레이어 준비: \(prepareSuccess ? "성공" : "실패"), duration: \(audioPlayer.duration)초")
            
            if prepareSuccess && audioPlayer.duration > 0 {
                print("🔍 재생 시작 시도...")
                
                // 재생 전 오디오 세션 상태 상세 확인
                print("🔍 재생 전 오디오 세션 상태:")
                print("  - 카테고리: \(audioSession.category)")
                print("  - 모드: \(audioSession.mode)")
                print("  - 활성화됨: \(audioSession.isOtherAudioPlaying ? "다른 앱 재생 중" : "사용 가능")")
                print("  - 출력 볼륨: \(audioSession.outputVolume)")
                
                // 재생 전 플레이어 상태 확인
                print("🔍 재생 전 플레이어 상태:")
                print("  - isPlaying: \(audioPlayer.isPlaying)")
                print("  - currentTime: \(audioPlayer.currentTime)")
                print("  - duration: \(audioPlayer.duration)")
                print("  - volume: \(audioPlayer.volume)")
                print("  - numberOfChannels: \(audioPlayer.numberOfChannels)")
                print("  - format: \(audioPlayer.format.description)")
                
                let playSuccess = audioPlayer.play()
                print(playSuccess ? "✅ 대안 오디오 재생 시작 성공 (\(sampleRate)Hz)" : "❌ 대안 오디오 재생 시작 실패")
                
                // 재생 호출 직후 즉시 상태 확인 (동기적으로)
                print("🔍 play() 직후 즉시 상태:")
                print("  - isPlaying: \(audioPlayer.isPlaying)")
                print("  - currentTime: \(audioPlayer.currentTime)")
                
                if playSuccess {
                    print("🔍 재생 직후 상태 - isPlaying: \(audioPlayer.isPlaying), currentTime: \(audioPlayer.currentTime), duration: \(audioPlayer.duration)")
                    
                    // 재생 완료 모니터링 - 더 짧은 간격으로 체크
                    DispatchQueue.global(qos: .userInitiated).async {
                        var checkCount = 0
                        let maxChecks = 300 // 15초 최대 (0.05초 * 300)
                        var wasPlaying = false
                        var lastTime: TimeInterval = 0
                        
                        while checkCount < maxChecks {
                            let isCurrentlyPlaying = audioPlayer.isPlaying
                            let currentTime = audioPlayer.currentTime
                            
                            if isCurrentlyPlaying {
                                wasPlaying = true
                                lastTime = currentTime
                            }
                            
                            // 재생 진행 상황 체크 (끊김 감지)
                            let isStuck = wasPlaying && !isCurrentlyPlaying && currentTime == lastTime && currentTime < audioPlayer.duration * 0.9
                            
                            // 재생이 끝났거나 시간이 다 지났으면 종료
                            if (!isCurrentlyPlaying && wasPlaying && !isStuck) || currentTime >= audioPlayer.duration * 0.95 {
                                print("🔍 재생 완료 감지 at \(currentTime)초 (총 \(audioPlayer.duration)초)")
                                break
                            }
                            
                            // 끊김 감지 시 재시작 시도
                            if isStuck {
                                print("⚠️ 재생 끊김 감지, 재시작 시도")
                                let restartSuccess = audioPlayer.play()
                                print("🔍 재시작 결과: \(restartSuccess)")
                            }
                            
                            if checkCount % 20 == 0 { // 1초마다 로그 (0.05 * 20 = 1초)
                                print("🔍 재생 상태 [\(checkCount/20)초] - playing: \(isCurrentlyPlaying), time: \(String(format: "%.3f", currentTime))/\(String(format: "%.3f", audioPlayer.duration))")
                            }
                            
                            Thread.sleep(forTimeInterval: 0.05) // 50ms 간격으로 체크 (더 세밀한 모니터링)
                            checkCount += 1
                        }
                        
                        DispatchQueue.main.async {
                            if checkCount >= maxChecks {
                                print("⚠️ 재생 모니터링 타임아웃 (15초)")
                            } else if wasPlaying {
                                print("🎵 대안 오디오 재생 완료")
                            } else {
                                print("❌ 재생이 시작되지 않았음")
                            }
                            
                            if self.currentAudioPlayer === audioPlayer {
                                self.currentAudioPlayer = nil
                            }
                            
                            // 재생 완료 후 오디오 세션 복원
                            self.restoreAudioSession(originalCategory: originalCategory, originalMode: originalMode)
                            
                            // 다음 큐 처리
                            self.audioPlaybackCompleted()
                        }
                    }
                } else {
                    print("❌ play() 호출 실패")
                    currentAudioPlayer = nil
                    
                    // 플레이어 상태 상세 확인
                    print("🔍 실패 후 플레이어 상태:")
                    print("  - 준비됨: \(audioPlayer.prepareToPlay())")
                    print("  - duration: \(audioPlayer.duration)")
                    print("  - 볼륨: \(audioPlayer.volume)")
                    print("  - URL: \(audioPlayer.url?.absoluteString ?? "데이터 기반")")
                    
                    // 오디오 세션 복원
                    restoreAudioSession(originalCategory: originalCategory, originalMode: originalMode)
                    
                    // 다음 큐 처리
                    audioPlaybackCompleted()
                    
                    // 대안: 시스템 사운드 테스트
                    testSystemSound()
                }
            } else {
                print("❌ prepareToPlay() 실패 또는 duration이 0")
                currentAudioPlayer = nil
                
                // 오디오 세션 복원
                restoreAudioSession(originalCategory: originalCategory, originalMode: originalMode)
                
                // 다음 큐 처리
                audioPlaybackCompleted()
                
                // 대안: 시스템 사운드 테스트
                testSystemSound()
            }
            
        } catch {
            print("❌ 대안 오디오 재생 오류: \(error.localizedDescription)")
            currentAudioPlayer = nil
            
            // 오디오 세션 복원
            restoreAudioSession(originalCategory: originalCategory, originalMode: originalMode)
            
            // 다음 큐 처리
            audioPlaybackCompleted()
            
            // 대안: 시스템 사운드 테스트
            testSystemSound()
        }
    }
    
    // 오디오 세션 복원 함수 추가
    private func restoreAudioSession(originalCategory: AVAudioSession.Category, originalMode: AVAudioSession.Mode) {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // MARK: - 수정: 더 안정적인 오디오 세션 복원
            print("🔄 오디오 세션 복원 시작: \(originalCategory), \(originalMode)")
            
            // 단계적 복원 시도
            try audioSession.setCategory(originalCategory, mode: originalMode, options: [
                .allowBluetooth, 
                .allowBluetoothA2DP, 
                .defaultToSpeaker,
                .mixWithOthers // 혼합 옵션 유지
            ])
            
            // 활성화 시도 - 여러 번 시도
            for attempt in 1...3 {
                do {
                    try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                    print("✅ 오디오 세션 복원 완료 (시도 \(attempt)): \(originalCategory), \(originalMode)")
                    return
                } catch {
                    print("⚠️ 오디오 세션 복원 시도 \(attempt) 실패: \(error.localizedDescription)")
                    if attempt < 3 {
                        Thread.sleep(forTimeInterval: 0.1)
                    }
                }
            }
            
            print("❌ 오디오 세션 복원 최종 실패")
        } catch {
            print("⚠️ 오디오 세션 복원 실패: \(error.localizedDescription)")
            
            // 대안: 기본 VoIP 설정으로 복원
            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker])
                try audioSession.setActive(true)
                print("✅ 기본 VoIP 설정으로 복원 완료")
            } catch {
                print("❌ 기본 설정 복원도 실패: \(error.localizedDescription)")
            }
        }
    }
    
    // 시스템 사운드 테스트 함수
    private func testSystemSound() {
        print("🔔 시스템 사운드 테스트 시작")
        
        DispatchQueue.main.async {
            // 햅틱 피드백
            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
            impactFeedback.prepare()
            impactFeedback.impactOccurred()
            
            print("🔔 햅틱 피드백 실행")
            
            // 0.3초 후 두 번째 햅틱
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                impactFeedback.impactOccurred()
                print("🔔 두 번째 햅틱 피드백 실행")
            }
        }
    }
    
    private func createWAVData(from pcmData: Data, sampleRate: Float) -> Data {
        var wavData = Data()
        
        // WAV 헤더 정보
        let sampleRateUInt32: UInt32 = UInt32(sampleRate)
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let bytesPerSample: UInt16 = bitsPerSample / 8
        let blockAlign: UInt16 = channels * bytesPerSample
        let byteRate: UInt32 = sampleRateUInt32 * UInt32(blockAlign)
        
        print("🔍 WAV 헤더 생성 - 샘플레이트: \(sampleRateUInt32)Hz, 채널: \(channels), 비트: \(bitsPerSample)")
        
        // RIFF 헤더 (12 바이트)
        wavData.append("RIFF".data(using: .ascii)!)
        let fileSize = UInt32(36 + pcmData.count)
        wavData.append(withUnsafeBytes(of: fileSize.littleEndian) { Data($0) })
        wavData.append("WAVE".data(using: .ascii)!)
        
        // fmt 청크 (24 바이트)
        wavData.append("fmt ".data(using: .ascii)!)
        let fmtSize: UInt32 = 16
        wavData.append(withUnsafeBytes(of: fmtSize.littleEndian) { Data($0) })
        let audioFormat: UInt16 = 1 // PCM
        wavData.append(withUnsafeBytes(of: audioFormat.littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: channels.littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: sampleRateUInt32.littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: byteRate.littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: blockAlign.littleEndian) { Data($0) })
        wavData.append(withUnsafeBytes(of: bitsPerSample.littleEndian) { Data($0) })
        
        // data 청크 (8 바이트 + 데이터)
        wavData.append("data".data(using: .ascii)!)
        let dataSize = UInt32(pcmData.count)
        wavData.append(withUnsafeBytes(of: dataSize.littleEndian) { Data($0) })
        wavData.append(pcmData)
        
        print("🔍 WAV 생성 완료 - 총 크기: \(wavData.count) bytes (헤더: 44, 데이터: \(pcmData.count))")
        
        return wavData
    }
    
    private func extractSampleRate(from mimeType: String) -> Float {
        // 기본 샘플레이트 (Gemini Live API 기본값)
        var sampleRate: Float = 24000.0
        
        print("🔍 mimeType 파싱: \(mimeType)")
        
        // mimeType에서 rate 파라미터 추출
        // 예: "audio/pcm;rate=24000" -> 24000
        if let range = mimeType.range(of: "rate=") {
            let rateString = String(mimeType[range.upperBound...])
            if let extractedRate = Float(rateString.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) {
                sampleRate = extractedRate
                print("🔍 추출된 샘플레이트: \(sampleRate)Hz")
            }
        }
        
        return sampleRate
    }
    
    // MARK: - AVAudioEngine을 사용한 스트리밍 오디오 재생 (대안)
    private func setupAudioEngine() {
        do {
            audioEngine = AVAudioEngine()
            audioPlayerNode = AVAudioPlayerNode()
            
            guard let engine = audioEngine, let playerNode = audioPlayerNode else {
                print("❌ 오디오 엔진 또는 플레이어 노드 생성 실패")
                return
            }
            
            engine.attach(playerNode)
            
            // 오디오 포맷 설정 (24kHz, 모노, Float32)
            let format = AVAudioFormat(standardFormatWithSampleRate: 24000, channels: 1)!
            engine.connect(playerNode, to: engine.mainMixerNode, format: format)
            
            try engine.start()
            playerNode.play()
            
            print("✅ AVAudioEngine 설정 완료")
        } catch {
            print("❌ AVAudioEngine 설정 실패: \(error.localizedDescription)")
        }
    }
    
    private func playAudioWithEngine(_ audioData: Data, sampleRate: Float) {
        guard let engine = audioEngine, let playerNode = audioPlayerNode else {
            print("⚠️ 오디오 엔진이 설정되지 않음, 기본 방식 사용")
            playReceivedAudioAlternative(audioData, sampleRate: sampleRate)
            return
        }
        
        do {
            // PCM 데이터를 AVAudioPCMBuffer로 변환
            let format = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 1)!
            let frameCount = UInt32(audioData.count / 2) // 16-bit = 2 bytes per sample
            
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                print("❌ PCM 버퍼 생성 실패")
                return
            }
            
            buffer.frameLength = frameCount
            
            // Int16 PCM 데이터를 Float32로 변환
            let int16Pointer = audioData.withUnsafeBytes { $0.bindMemory(to: Int16.self) }
            let floatPointer = buffer.floatChannelData![0]
            
            for i in 0..<Int(frameCount) {
                floatPointer[i] = Float(int16Pointer[i]) / Float(Int16.max)
            }
            
            // 버퍼를 큐에 추가하여 재생
            playerNode.scheduleBuffer(buffer) {
                DispatchQueue.main.async {
                    self.audioPlaybackCompleted()
                }
            }
            
            print("✅ AVAudioEngine으로 오디오 재생 예약 완료: \(frameCount) 프레임")
            
        } catch {
            print("❌ AVAudioEngine 오디오 재생 오류: \(error.localizedDescription)")
            // 대안으로 기본 방식 사용
            playReceivedAudioAlternative(audioData, sampleRate: sampleRate)
        }
    }
}

// preview
struct CallView_Previews: PreviewProvider {
    static var previews: some View {
        CallView()
    }
}

