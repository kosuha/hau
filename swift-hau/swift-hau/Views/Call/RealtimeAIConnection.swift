//
//  RealtimeAIConnection.swift
//  swift-hau
//
//  Created on: 현재 날짜
//

import Foundation
import WebRTC
import AVFoundation
import CallKit
import Supabase

// 알림 이름 정의
extension Notification.Name {
    static let aiAudioDebugUpdate = Notification.Name("aiAudioDebugUpdateNotification")
}

// Supabase 응답을 디코딩하기 위한 구조체
private struct CurrentPointsResponse: Decodable {
    let points: Int
}

class RealtimeAIConnection: NSObject {
    static let shared = RealtimeAIConnection()
    
    private var peerConnection: RTCPeerConnection?
    private var dataChannel: RTCDataChannel?
    private var audioTrack: RTCAudioTrack?
    private var factory: RTCPeerConnectionFactory?
    private var localMediaStream: RTCMediaStream?
    private var isInitialized = false
    private var connectionLock = NSLock() // 연결 동기화용 락
    
    // 현재 통화 ID
    private var currentCallId: Int64?
    private var currentAuthId: String? // 사용자 인증 ID 저장
    private var currentTransactionId: String? // 현재 통화의 거래 ID 저장
    private var totalCoinsUsed: Int = 0 // 총 사용된 코인 수
    
    // 시간 기반 코인 차감 관련 변수들
    private var callStartTime: Date?
    private var coinDeductionTimer: Timer?
    private var elapsedMinutes: Int = 0
    private var callDurationSeconds: Int = 0  // CallView와 동기화를 위한 초 단위 카운터
    private var isDeducting: Bool = false  // 중복 차감 방지 플래그
    
    // 오디오 관련 변수들을 클래스 본문으로 이동
    private var audioStart: Int = 0
    private var audioEnd: Int = 0
    private var audioDuration: Int = 0
    
    // 연결 상태 관리
    var isConnected: Bool = false
    var onStateChange: ((Bool) -> Void)?
    
    // 전역 연결 상태 관리 추가
    private var isConnectionInProgress: Bool = false
    
    // 대화 내용 기록 (비용 추적 제거)
    private var conversations: [[String: Any]] = []
    
    // 콜 매니저 변수 추가
    private var callManager: CallManager?
    
    // 클래스 멤버 변수에 추가
    private var pendingEndCall: Bool = false
    private var pendingCallManager: CallManager? = nil
    
    // 통화 기록 구조체
    private struct HistoryRecord: Encodable {
        let transcript: String
        let summary: String
        let auth_id: String
    }
    
    // 통화 기록 응답 구조체
    private struct HistoryResponse: Decodable {
        let id: Int64
        let transcript: String
        let summary: String
        let auth_id: String
    }
    
    // CoinViewModel 인스턴스 추가
    private var coinViewModel: CoinViewModel?
    
    private override init() {
        super.init()
        // 앱 시작 시 한 번만 SSL 초기화
        RTCInitializeSSL()
        factory = RTCPeerConnectionFactory()
    }
    
    deinit {
        // 앱 종료 시 한 번만 SSL 정리
        RTCCleanupSSL()
    }
    
    func initialize(with ephemeralKey: String) async -> Bool {
        // 동기화 락 사용
        connectionLock.lock()
        
        // 이미 연결 시도 중이면 중복 차단
        if isConnectionInProgress {
            connectionLock.unlock()
            return false
        }
        
        isConnectionInProgress = true
        
        // 이전 연결 완전히 정리
        cleanupConnection()
        
        // 상태 업데이트
        isConnected = false
        // 메인 스레드에서 콜백 호출
        DispatchQueue.main.async {
            self.onStateChange?(false)
        }
        
        // RTCPeerConnection 생성
        setupPeerConnection()
        
        // 로컬 오디오 트랙 추가
        setupLocalAudioTrack()
        
        // 데이터 채널 설정
        setupDataChannel()
        
        // SDP 오퍼 생성 및 전송
        return await withCheckedContinuation { continuation in
            createAndSendOffer(ephemeralKey: ephemeralKey) { success in
                self.connectionLock.unlock()
                
                if success {
                    self.isConnected = true
                    // 메인 스레드에서 콜백 호출
                    DispatchQueue.main.async {
                        self.onStateChange?(true)
                    }
                } else {
                    // 실패 시 연결 정리
                    self.cleanupConnection()
                }
                
                self.isConnectionInProgress = false
                continuation.resume(returning: success)
            }
        }
    }
    
    private func setupPeerConnection() {
        let config = RTCConfiguration()
        // STUN/TURN 서버 설정도 필요하다면 여기에 추가
        
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: ["DtlsSrtpKeyAgreement": "true"]
        )
        
        peerConnection = factory?.peerConnection(with: config, constraints: constraints, delegate: self)
    }
    
    private func setupLocalAudioTrack() {
        let audioConstrains = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        guard let audioSource = factory?.audioSource(with: audioConstrains) else {
            return
        }

        audioTrack = factory?.audioTrack(with: audioSource, trackId: "audio0")
        guard let currentAudioTrack = audioTrack else {
            return
        }

        let streamId = "stream0"
        guard let localStream = factory?.mediaStream(withStreamId: streamId) else {
             return
        }

        localStream.addAudioTrack(currentAudioTrack)

        guard let pc = peerConnection else {
             return
        }
        pc.add(currentAudioTrack, streamIds: [streamId])
    }
    
    private func setupDataChannel() {
        let config = RTCDataChannelConfiguration()
        dataChannel = peerConnection?.dataChannel(forLabel: "oai-events", configuration: config)
        dataChannel?.delegate = self
    }
    
    private func createAndSendOffer(ephemeralKey: String, completion: @escaping (Bool) -> Void) {
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: [
                "OfferToReceiveAudio": "true"
            ],
            optionalConstraints: nil
        )
        
        peerConnection?.offer(for: constraints) { [weak self] (sdp, error) in
            guard let self = self, let sdp = sdp, error == nil else {
                completion(false)
                return
            }
            
            self.peerConnection?.setLocalDescription(sdp) { error in
                if let error = error {
                    completion(false)
                    return
                }
                
                self.sendOffer(sdp: sdp.sdp, ephemeralKey: ephemeralKey, completion: completion)
            }
        }
    }
    
    private func sendOffer(sdp: String, ephemeralKey: String, completion: @escaping (Bool) -> Void) {
        let baseUrl = "https://api.openai.com/v1/realtime"
        let model = "gpt-4o-mini-realtime-preview"
        
        guard let url = URL(string: "\(baseUrl)?model=\(model)") else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = sdp.data(using: .utf8)
        request.addValue("Bearer \(ephemeralKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/sdp", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self, let data = data, error == nil else {
                completion(false)
                return
            }
            
            if let sdpString = String(data: data, encoding: .utf8) {
                let sdp = RTCSessionDescription(type: .answer, sdp: sdpString)
                self.peerConnection?.setRemoteDescription(sdp) { error in
                    if let error = error {
                        completion(false)
                    } else {
                        completion(true)
                    }
                }
            } else {
                completion(false)
            }
        }.resume()
    }
    
    // 연결만 정리 (SSL은 초기화하지 않음)
    private func cleanupConnection() {
        
        // 통화 진행 중이 아닐 때만 타이머 정리
        if currentTransactionId == nil {
            stopCoinDeductionTimer()
        }
        
        // 중복 차감 방지 플래그 초기화
        isDeducting = false
        
        // 통화 관련 변수는 여기서 리셋하지 않음 (WebRTC 연결과 별개의 생명주기)
        // currentTransactionId = nil
        // totalCoinsUsed = 0
        
        if let dataChannel = self.dataChannel {
            dataChannel.close()
            self.dataChannel = nil
        }
        
        if let audioTrack = self.audioTrack {
            audioTrack.isEnabled = false
            self.audioTrack = nil
        }
        
        if let localMediaStream = self.localMediaStream {
            localMediaStream.videoTracks.forEach { $0.isEnabled = false }
            localMediaStream.audioTracks.forEach { $0.isEnabled = false }
            self.localMediaStream = nil
        }
        
        if let peerConnection = self.peerConnection {
            peerConnection.close()
            self.peerConnection = nil
        }
        
        // 연결 상태가 실제로 변경된 경우에만 콜백 호출
        if isConnected {
            isConnected = false
            // 메인 스레드에서 콜백 호출
            DispatchQueue.main.async {
                self.onStateChange?(false)
            }
        }
    }
    
    func disconnect() {
        connectionLock.lock()
        
        var shouldResetTransaction = true
        // CallManager 인스턴스가 있고, 해당 인스턴스가 통화가 진행 중이고 화면도 보여줘야 한다고 판단하면,
        // WebRTC 연결은 정리하되, 통화 트랜잭션 ID는 즉시 리셋하지 않습니다.
        // 이는 CallView가 잠깐 사라졌다가 다시 나타나는 경우 등, WebRTC는 재연결되지만 통화 세션은 유지되어야 하는 상황을 위함입니다.
        if let cm = self.callManager, cm.isCallInProgress, cm.shouldShowCallScreen {
            shouldResetTransaction = false
        }

        if shouldResetTransaction {
            currentTransactionId = nil
            totalCoinsUsed = 0
        }
        
        // cleanupConnection은 currentTransactionId 상태를 확인한 후 호출
        cleanupConnection()
        
        // 통화 완전 종료 시에만 타이머도 정리
        if shouldResetTransaction {
            stopCoinDeductionTimer()
        }
        
        // isConnectionInProgress는 연결 시도 자체의 상태이므로 항상 false로 설정합니다.
        isConnectionInProgress = false
        
        connectionLock.unlock()
    }
    
    // 콜 매니저 설정 메소드 추가
    func setCallManager(_ manager: CallManager) {
        self.callManager = manager
    }

    // 통화 시작 시 호출되는 메서드
    // 반환 타입을 Bool로 변경하여 포인트 부족 시 실패를 알림
    func startCall() async -> Bool {
        // 이미 통화가 진행 중인 경우 중복 시작 방지
        if currentTransactionId != nil {
            // 타이머 상태 확인 및 재시작
            if coinDeductionTimer == nil {
                startCoinDeductionTimer()
            }
            
            return true // 이미 진행 중이므로 성공으로 처리
        }
        
        // 연결이 진행 중인 경우에도 중복 시작 방지
        if isConnectionInProgress {
            return false
        }
        
        // currentAuthId를 startCall 시작 시점에 session으로부터 가져오도록 수정
        do {
            let session = try await client.auth.session
            self.currentAuthId = session.user.id.uuidString
        } catch {
            print("startCall 오류: 사용자 세션 정보를 가져오는데 실패했습니다 - \(error.localizedDescription)")
            return false // 세션 정보 없으면 시작 불가
        }

        // authId 재확인 (위에서 설정되었으므로 nil이 아니어야 함)
        guard let currentAuthUserId = self.currentAuthId else {
            print("startCall 오류: 사용자 인증 ID가 없습니다.")
            return false
        }

        // 1. 사용자 포인트 확인
        do {
            let response = try await client // PostgrestResponse를 받도록 변경
                .from("user_monthly_points")
                .select("points")
                .eq("user_id", value: currentAuthUserId)
                .limit(1) // 최대 1개의 레코드만 가져오도록 제한
                .execute()

            // 데이터를 [CurrentPointsResponse] 배열로 디코딩 시도
            // response.data가 비어있는 경우 빈 배열로 디코딩되거나 오류 발생 가능성에 따라 처리
            var pointsResponse: CurrentPointsResponse? = nil
            if !response.data.isEmpty {
                let pointsResponses = try JSONDecoder().decode([CurrentPointsResponse].self, from: response.data)
                pointsResponse = pointsResponses.first // 첫 번째 요소 가져오기 (없으면 nil)
            }

            if pointsResponse == nil {
                return false // 데이터(포인트 레코드)가 없어서 통화 시작 실패
            }

            // 레코드가 있으면 실제 포인트 값 확인
            // pointsResponse가 nil이 아니므로 강제 언래핑 사용 가능 (위에서 nil 체크됨)
            let currentPoints = pointsResponse!.points 

            if currentPoints <= 0 {
                return false // 포인트 부족 시 false 반환
            }
        } catch {
            print("startCall 오류: 사용자 포인트를 가져오는데 실패했습니다 - \(error.localizedDescription)")
            // 포인트 조회 실패 시 통화 시작을 막을지, 아니면 일단 진행하고 나중에 차감 시도할지 정책 필요
            // 여기서는 일단 실패로 간주하고 false 반환
            return false
        }

        // 포인트가 충분하면 통화 기록 생성 및 나머지 로직 진행
        conversations = [] // 대화 내용 초기화
        totalCoinsUsed = 0 // 총 사용 코인 초기화
        
        // 통화 시작 API 호출하여 거래 ID 받기
        do {
            let apiBaseURL = AppConfig.baseURL
            if apiBaseURL.isEmpty {
                print("API Base URL이 설정되지 않았습니다.")
                // 에러 처리 필요
                return false
            } else {
                let url = URL(string: "\(apiBaseURL)/coins/call/start")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let requestBody: [String: Any] = [
                    "user_id": currentAuthUserId,
                    "description": "통화 1분 미만"
                ]
                
                request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse {
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("통화 시작 API 응답 데이터: \(responseString)")
                    }
                    
                    if httpResponse.statusCode == 200 {
                        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            if let success = json["success"] as? Bool,
                               success,
                               let transactionId = json["transaction_id"] as? String {
                                currentTransactionId = transactionId
                            }
                        }
                    }
                }
            }
        } catch {
            print("통화 시작 API 호출 오류: \(error)")
            // 에러 처리 필요
            return false
        }
        
        // 코인 차감 타이머 시작 (CallView 타이머와 동기화)
        startCoinDeductionTimer()
        
        // 프라이빗 모드인 경우 가상 ID 생성 (대화 내용 저장하지 않음)
        if CallManager.shared.isPrivateMode {
            currentCallId = Int64(Date().timeIntervalSince1970)
            
            // 통화 시작 시 인사말 전송
            sendInitialGreeting()
            
            return true
        }
        
        do {
            // 사용자 ID는 위에서 이미 currentAuthUserId로 가져왔으므로 재사용
            let newHistory = HistoryRecord(
                transcript: "",
                summary: "",
                auth_id: currentAuthUserId 
            )

            let result = try await client
                .from("history")
                .insert(newHistory)
                .select()
                .single()
                .execute()

            // JSON 데이터로 직접 파싱
            let data = result.data
            if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let id = json["id"] as? Int64 {
                currentCallId = id
                
                // 통화 시작 시 인사말 전송
                sendInitialGreeting()
            }
        } catch {
            print("통화 기록 생성 오류: \(error)")
            return false // 통화 기록 생성 중 오류 발생
        }

        return true // 통화 기록 생성 성공
    }
    
    // AI에게 인사말을 전송하는 메서드
    private func sendInitialGreeting() {
        // 데이터 채널이 준비될 때까지 약간 지연 후 시도
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.attemptToSendGreeting(retryCount: 5)
        }
    }
    
    // 인사말 전송 시도 (재시도 기능 포함)
    private func attemptToSendGreeting(retryCount: Int) {
        guard let dataChannel = self.dataChannel else {
            print("인사말 전송 오류: 데이터 채널이 nil입니다.")
            if retryCount > 0 {
                DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.attemptToSendGreeting(retryCount: retryCount - 1)
                }
            }
            return
        }
        
        if dataChannel.readyState != .open {
            if retryCount > 0 {
                DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.attemptToSendGreeting(retryCount: retryCount - 1)
                }
            }
            return
        }
        
        do {
            // 빈 메시지 전송 없이 바로 응답 생성만 트리거
            let responseCreate: [String: Any] = ["type": "response.create"]
            let responseData = try JSONSerialization.data(withJSONObject: responseCreate)
            let responseBuffer = RTCDataBuffer(data: responseData, isBinary: false)
            dataChannel.sendData(responseBuffer)
        } catch {
            print("AI 응답 트리거 전송 오류: \(error.localizedDescription)")
        }
    }

    // 통화 내용을 Supabase에 저장하는 메서드
    private func saveConversationToSupabase(transcript: String) {
        // 프라이빗 모드가 활성화되어 있으면 저장하지 않음
        if CallManager.shared.isPrivateMode {
            return
        }
        
        guard let callId = currentCallId else { return }
        
        Task {
            do {
                // history 테이블에서 해당 통화 ID의 레코드를 찾아 transcript 업데이트
                let query = client
                    .from("history")
                    .select()
                    .eq("id", value: String(callId))
                    .single()
                
                let result = try await query.execute()
                
                // JSON 데이터로 직접 파싱
                let data = result.data
                if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let currentTranscript = json["transcript"] as? String {
                    // 기존 transcript에 새로운 내용 추가
                    let updatedTranscript = currentTranscript + "\n" + transcript
                    
                    // 업데이트 쿼리 실행
                    try await client
                        .from("history")
                        .update(["transcript": updatedTranscript])
                        .eq("id", value: String(callId))
                        .execute()
                    
                } else {
                    print("기존 transcript 가져오기 실패")
                }
            } catch {
                print("Supabase 저장 오류: \(error.localizedDescription)")
            }
        }
    }

    // CoinViewModel 설정 메서드 추가
    func setCoinViewModel(_ viewModel: CoinViewModel) {
        self.coinViewModel = viewModel
    }

    // 통화용 코인 차감 메서드
    private func deductCoinsForCall(amount: Int) async {
        guard let authId = self.currentAuthId else {
            return
        }
        
        guard let transactionId = self.currentTransactionId else {
            return
        }
        
        let apiBaseURL = AppConfig.baseURL
        if apiBaseURL.isEmpty {
            DispatchQueue.main.async {
                CallManager.shared.callError = "서버 설정 오류로 통화가 중단되었습니다."
            }
            return
        }
        
        // 총 사용 코인 수 업데이트 (첫 번째 분 10개 + 추가 차감)
        totalCoinsUsed += amount
        
        let url = URL(string: "\(apiBaseURL)/coins/call/update")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "user_id": authId,
            "transaction_id": transactionId,
            "total_amount": 10 + totalCoinsUsed, // 첫 번째 분(10개) + 추가 차감
            "description": "통화 \(elapsedMinutes + 1)분 미만"
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    // 성공적으로 코인 차감됨
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let success = json["success"] as? Bool,
                       success {
                        // 서버 응답에서 새로운 잔액을 받은 경우 업데이트
                        if let currentBalance = json["current_balance"] as? Int {
                            DispatchQueue.main.async {
                                self.coinViewModel?.updateLocalBalance(currentBalance)
                            }
                        } else {
                            // 서버에서 잔액을 제공하지 않은 경우 로컬에서 차감
                            DispatchQueue.main.async {
                                Task {
                                    if let success = await self.coinViewModel?.deductCoins(amount: amount, description: "통화 \(self.elapsedMinutes + 1)분 미만") {
                                        if !success {
                                            print("⚠️ 로컬 코인 차감 실패")
                                        }
                                    }
                                }
                            }
                        }
                        
                        DispatchQueue.main.async {
                            CallManager.shared.callError = nil
                        }
                    }
                } else if httpResponse.statusCode == 400 {
                    // 코인 부족 - 통화 종료
                    DispatchQueue.main.async {
                        CallManager.shared.callError = "코인을 모두 소진하여 통화가 중단되었습니다."
                    }
                    
                    // 즉시 통화 종료
                    disconnect()
                    if let manager = self.callManager {
                        DispatchQueue.main.async {
                            manager.endCall()
                        }
                    }
                } else {
                    // 기타 오류
                    print("코인 차감 API 오류: \(httpResponse.statusCode)")
                    DispatchQueue.main.async {
                        CallManager.shared.callError = "코인 처리 중 오류가 발생했습니다."
                    }
                }
            }
        } catch {
            print("코인 차감 API 호출 오류: \(error)")
            DispatchQueue.main.async {
                CallManager.shared.callError = "코인 처리 중 네트워크 오류가 발생했습니다: \(error.localizedDescription)"
            }
        }
    }

    // 코인 차감 타이머 시작 (CallView 타이머와 동기화)
    private func startCoinDeductionTimer() {
        
        // currentTransactionId가 이미 있는 경우 (기존 통화 계속)
        if currentTransactionId != nil && callStartTime != nil {
            // 기존 callStartTime과 경과 시간 정보를 유지
            print("🔍 기존 통화 계속 - 기존 시간 정보 유지")
            print("📍 기존 경과 시간: \(callDurationSeconds)초")
        } else {
            // 새로운 통화 시작
            callStartTime = Date()
            elapsedMinutes = 0
            callDurationSeconds = 0
        }

        // CallView의 타이머에 의존하므로 별도 타이머 생성하지 않음
        coinDeductionTimer = nil // 기존 타이머가 있다면 제거
    }
    
    // 코인 차감 타이머 정지
    private func stopCoinDeductionTimer() {
        coinDeductionTimer?.invalidate()
        coinDeductionTimer = nil
        callStartTime = nil
        elapsedMinutes = 0
        callDurationSeconds = 0
    }
    
    // 실제 코인 차감 수행
    private func performCoinDeduction() {
        // 중복 차감 방지
        if isDeducting {
            return
        }
        
        // 차감 시작 플래그 설정
        isDeducting = true
        
        // 경과 시간을 초 단위 카운터로 계산 (CallView와 동일)
        let currentElapsedMinutes = callDurationSeconds / 60
        elapsedMinutes = currentElapsedMinutes
        
        // 차감할 코인 계산: 10분마다 2개씩 증가
        let tenMinuteSegment = elapsedMinutes / 10
        let coinsToDeduct = 10 + (tenMinuteSegment * 2)
        
        let displayMinute = elapsedMinutes + 1
        let displaySeconds = callDurationSeconds % 60
        
        // 비동기적으로 코인 차감 (이번 분에 해당하는 코인만 차감)
        Task {
            await deductCoinsForCall(amount: coinsToDeduct)
            // 차감 완료 후 플래그 초기화
            isDeducting = false
        }
    }

    // CallView와 시간 동기화 메서드 추가
    func syncCallDuration(seconds: Int) {
        // CallView에서 전달받은 시간으로 동기화
        self.callDurationSeconds = seconds
        
        // 코인 차감 로직 실행
        if currentTransactionId != nil {
            // 61초부터 매 60초마다 코인 차감 (2분 01초, 3분 01초...)
            if self.callDurationSeconds > 60 && (self.callDurationSeconds - 1) % 60 == 0 {
                let minutes = self.callDurationSeconds / 60
                let seconds = self.callDurationSeconds % 60
                self.performCoinDeduction()
            }
        }
    }
}

// MARK: - RTCPeerConnectionDelegate
extension RealtimeAIConnection: RTCPeerConnectionDelegate {
    func peerConnectionDidStartCommunication(_ peerConnection: RTCPeerConnection) {
        NotificationCenter.default.post(name: .aiAudioDebugUpdate, object: nil, userInfo: ["message": "AI: PeerConnection 통신 시작됨"])
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didStartReceivingOn transceiver: RTCRtpTransceiver) {
        NotificationCenter.default.post(name: .aiAudioDebugUpdate, object: nil, userInfo: ["message": "AI: PeerConnection 수신 시작됨 (mid: \(transceiver.mid ?? "unknown"))"])
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        NotificationCenter.default.post(name: .aiAudioDebugUpdate, object: nil, userInfo: ["message": "AI: 데이터 채널 열림 (label: \(dataChannel.label))"])
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCPeerConnectionState) {
        var stateMessage = ""
        switch newState {
        case .new:
            stateMessage = "new"
        case .connecting:
            stateMessage = "connecting"
        case .connected:
            stateMessage = "connected"
        case .disconnected:
            stateMessage = "disconnected"
        case .failed:
            stateMessage = "failed"
        case .closed:
            stateMessage = "closed"
        @unknown default:
            stateMessage = "unknown"
        }
        NotificationCenter.default.post(name: .aiAudioDebugUpdate, object: nil, userInfo: ["message": "AI: PeerConnection 상태 변경 - \(stateMessage)"])
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd receiver: RTCRtpReceiver, streams mediaStreams: [RTCMediaStream]) {
        print("미디어 수신기 추가됨")
        if let audioTrack = receiver.track as? RTCAudioTrack {
            print("원격 오디오 트랙 추가됨")
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        if let audioTrack = stream.audioTracks.first {
            print("원격 오디오 트랙 추가됨")
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        // print("ICE 후보 생성됨")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        print("스트림 제거됨")
    }
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        print("협상 필요")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        print("신호 상태 변경: \(stateChanged.rawValue)")
        var stateMessage = ""
        switch stateChanged {
        case .stable:
            stateMessage = "stable"
        case .haveLocalOffer:
            stateMessage = "haveLocalOffer"
        case .haveLocalPrAnswer:
            stateMessage = "haveLocalPrAnswer"
        case .haveRemoteOffer:
            stateMessage = "haveRemoteOffer"
        case .haveRemotePrAnswer:
            stateMessage = "haveRemotePrAnswer"
        case .closed:
            stateMessage = "closed"
        @unknown default:
            stateMessage = "unknown"
        }
        NotificationCenter.default.post(name: .aiAudioDebugUpdate, object: nil, userInfo: ["message": "AI: Signaling 상태 변경 - \(stateMessage)"])
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        var stateMessage = ""
        switch newState {
        case .new:
            stateMessage = "new"
        case .checking:
            stateMessage = "checking"
        case .connected:
            stateMessage = "connected (ICE)"
        case .completed:
            stateMessage = "completed (ICE)"
        case .failed:
            stateMessage = "failed (ICE)"
        case .disconnected:
            stateMessage = "disconnected (ICE)"
        case .closed:
            stateMessage = "closed (ICE)"
        case .count:
             stateMessage = "count (ICE)" // 이 케이스는 보통 사용되지 않음
        @unknown default:
            stateMessage = "unknown (ICE)"
        }
        NotificationCenter.default.post(name: .aiAudioDebugUpdate, object: nil, userInfo: ["message": "AI: ICE 연결 상태 변경 - \(stateMessage)"])
        
        // ICE 연결이 완전히 실패하거나 닫힌 경우에만 연결 상태를 false로 설정
        // disconnected는 일시적일 수 있으므로 제외
        if newState == .failed || newState == .closed {
            if isConnected {
                isConnected = false
                DispatchQueue.main.async {
                    self.onStateChange?(false)
                }
            }
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        print("ICE 수집 상태 변경: \(newState.rawValue)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        print("ICE 후보 제거됨")
    }
}

// MARK: - RTCDataChannelDelegate
extension RealtimeAIConnection: RTCDataChannelDelegate {
    func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        var stateMessage = ""
        switch dataChannel.readyState {
        case .connecting:
            stateMessage = "connecting"
        case .open:
            stateMessage = "open"
        case .closing:
            stateMessage = "closing"
        case .closed:
            stateMessage = "closed"
        @unknown default:
            stateMessage = "unknown"
        }
        NotificationCenter.default.post(name: .aiAudioDebugUpdate, object: nil, userInfo: ["message": "AI: 데이터 채널 상태 변경 (label: \(dataChannel.label)) - \(stateMessage)"])
    }
    
    func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        if let message = String(data: buffer.data, encoding: .utf8) {
            if let json = message.data(using: .utf8) {
                do {
                    if let jsonData = try JSONSerialization.jsonObject(with: json, options: []) as? [String: Any] {
                        
                        // 알림을 보낼 메시지
                        var debugMessage: String? = nil

                        if let type = jsonData["type"] as? String {
                            switch type {
                            case "input_audio_buffer.speech_started":
                                debugMessage = "AI: 음성 입력 시작 감지"
                                if let audioStartMs = jsonData["audio_start_ms"] as? Int {
                                    audioStart = audioStartMs
                                }
                            case "input_audio_buffer.speech_stopped":
                                debugMessage = "AI: 음성 입력 종료 감지"
                                if let audioEndMs = jsonData["audio_end_ms"] as? Int {
                                    audioEnd = audioEndMs
                                    // audioDuration 계산 추가 (필요시)
                                    audioDuration = audioEnd - audioStart
                                }
                            case "conversation.item.input_audio_transcription.completed":
                                if let transcript = jsonData["transcript"] as? String {
                                    // 큰따옴표 제거하여 단순화
                                    debugMessage = "AI: 음성 텍스트 변환 완료 - \(transcript)"
                                    
                                    // 사용자 음성 입력 기록
                                    let userInput: [String: Any] = [
                                        "role": "user",
                                        "content": transcript,
                                        "timestamp": Date().timeIntervalSince1970
                                    ]
                                    conversations.append(userInput)
                                    
                                    // Supabase에 저장
                                    saveConversationToSupabase(transcript: "사용자: \(transcript)")
                                } else {
                                    debugMessage = "AI: 음성 텍스트 변환 완료 (내용 없음)"
                                }
                            case "response.audio_transcript.delta":
                                // 델타 업데이트는 너무 빈번하므로 디버그 메시지 생략
                                break
                            case "response.done":
                                if let response = jsonData["response"] as? [String: Any],
                                   let output = response["output"] as? [[String: Any]],
                                   let messageContent = output.first?["content"] as? [[String: Any]],
                                   let transcript = messageContent.first?["transcript"] as? String {

                                    debugMessage = "AI: 응답 완료 - \(transcript)"
                                    
                                    // AI 응답 기록 (비용 계산 제거)
                                    let aiResponse: [String: Any] = [
                                        "role": "assistant",
                                        "content": transcript,
                                        "timestamp": Date().timeIntervalSince1970
                                    ]
                                    conversations.append(aiResponse)
                                    
                                    // Supabase에 저장 (AI 응답)
                                    saveConversationToSupabase(transcript: "AI: \(transcript)")
                                }
                            case "output_audio_buffer.started":
                                 debugMessage = "AI: 응답 오디오 재생 시작"
                            case "output_audio_buffer.stopped":
                                 debugMessage = "AI: 응답 오디오 재생 종료"
                            default:
                                // 다른 타입의 메시지는 일단 무시 (필요시 추가)
                                break
                            }
                            
                            // 디버그 메시지가 있으면 알림 발송
                            if let msg = debugMessage {
                                NotificationCenter.default.post(name: .aiAudioDebugUpdate, object: nil, userInfo: ["message": msg])
                            }
                        }

                        if let type = jsonData["type"] as? String, type == "input_audio_buffer.speech_started" {
                            if let audioStartMs = jsonData["audio_start_ms"] as? Int {
                                audioStart = audioStartMs
                            }
                        }

                        if let type = jsonData["type"] as? String, type == "input_audio_buffer.speech_stopped" {
                            if let audioEndMs = jsonData["audio_end_ms"] as? Int {
                                audioEnd = audioEndMs
                            }
                        }

                        if let type = jsonData["type"] as? String, type == "conversation.item.input_audio_transcription.completed" {
                            if let transcript = jsonData["transcript"] as? String {
                                
                                // 사용자 음성 입력 기록
                                let userInput: [String: Any] = [
                                    "role": "user",
                                    "content": transcript,
                                    "timestamp": Date().timeIntervalSince1970
                                ]
                                conversations.append(userInput)
                                
                                // Supabase에 저장
                                saveConversationToSupabase(transcript: "사용자: \(transcript)")
                            }
                        }
                        
                        if let type = jsonData["type"] as? String, type == "response.function_call_arguments.done" {
                            if let functionName = jsonData["name"] as? String, 
                               let callId = jsonData["call_id"] as? String {
                                if functionName == "endCall" {
                                    // 1. 함수 실행 결과를 대화 히스토리에 삽입
                                    let fnResult = "통화가 종료되었습니다." // 함수 실행 결과
                                    let item: [String: Any] = [
                                        "type": "function_call_output",
                                        "call_id": callId,
                                        "output": fnResult
                                    ]
                                    let payload: [String: Any] = [
                                        "type": "conversation.item.create",
                                        "item": item
                                    ]
                                    
                                    do {
                                        let data = try JSONSerialization.data(withJSONObject: payload)
                                        let buffer = RTCDataBuffer(data: data, isBinary: false)
                                        dataChannel.sendData(buffer)
                                        
                                        // 2. 모델에 "후속 메시지 생성" 트리거
                                        let followUp: [String: Any] = ["type": "response.create"]
                                        let followUpData = try JSONSerialization.data(withJSONObject: followUp)
                                        let followUpBuffer = RTCDataBuffer(data: followUpData, isBinary: false)
                                        dataChannel.sendData(followUpBuffer)
                                        
                                        // 종료 플래그 설정
                                        self.pendingEndCall = true
                                        self.pendingCallManager = self.callManager
                                        
                                        // AI가 오디오 출력을 완료할 때까지 기다림
                                    } catch {
                                        // 오류 발생 시 바로 종료
                                        disconnect()
                                        if let callManager = self.callManager {
                                            DispatchQueue.main.async {
                                                callManager.endCall()
                                            }
                                        }
                                    }
                                }
                            } else {
                                print("call_id가 없는 함수 호출")
                            }
                        }

                        // output_audio_buffer.stopped 처리 부분 추가
                        if let type = jsonData["type"] as? String, type == "output_audio_buffer.stopped" {
                            // 종료 플래그가 설정되어 있으면 실제로 종료 실행
                            if pendingEndCall {
                                pendingEndCall = false
                                
                                // 연결 종료
                                disconnect()
                                
                                // 통화 종료
                                if let callManager = pendingCallManager {
                                    DispatchQueue.main.async {
                                        callManager.endCall()
                                    }
                                    pendingCallManager = nil
                                }
                            }
                        }
                    }
                } catch {
                    print("JSON 파싱 오류: \(error)")
                }
            }
        }
    }
}