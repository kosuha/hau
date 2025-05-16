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
    
    // 오디오 관련 변수들을 클래스 본문으로 이동
    private var audioStart: Int = 0
    private var audioEnd: Int = 0
    private var audioDuration: Int = 0
    
    // 연결 상태 관리
    var isConnected: Bool = false
    var onStateChange: ((Bool) -> Void)?
    
    // 대화 내용과 비용 기록
    private var conversations: [[String: Any]] = []
    private var currentSessionCost: Double = 0.0
    private var costLimit: Double = 0.010 // 기본 비용 제한 (0.050달러)
    
    // 서버 통신 URL
    private let serverURL = URL(string: "https://your-api-server.com/conversations")!
    
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
    
    private override init() {
        super.init()
        // 앱 시작 시 한 번만 SSL 초기화
        RTCInitializeSSL()
        factory = RTCPeerConnectionFactory()
        print("RealtimeAIConnection: WebRTC 초기화 완료")
    }
    
    deinit {
        // 앱 종료 시 한 번만 SSL 정리
        RTCCleanupSSL()
    }
    
    func initialize(with ephemeralKey: String) async -> Bool {
        // 동기화 락 사용
        connectionLock.lock()
        
        // 이전 연결 완전히 정리
        cleanupConnection()
        
        print("AI 연결 초기화 시작...")
        
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
                    print("AI 연결 성공!")
                } else {
                    print("AI 연결 실패")
                    // 실패 시 연결 정리
                    self.cleanupConnection()
                }
                
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
        print("setupLocalAudioTrack: 시작")
        let audioConstrains = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        guard let audioSource = factory?.audioSource(with: audioConstrains) else {
            print("setupLocalAudioTrack: ERROR - 오디오 소스 생성 실패")
            return
        }
        print("setupLocalAudioTrack: 오디오 소스 생성됨")

        audioTrack = factory?.audioTrack(with: audioSource, trackId: "audio0")
        guard let currentAudioTrack = audioTrack else {
            print("setupLocalAudioTrack: ERROR - 오디오 트랙 생성 실패")
            return
        }
        print("setupLocalAudioTrack: 오디오 트랙 생성됨 (ID: \(currentAudioTrack.trackId), Enabled: \(currentAudioTrack.isEnabled))") // 상태 확인

        let streamId = "stream0"
        guard let localStream = factory?.mediaStream(withStreamId: streamId) else {
             print("setupLocalAudioTrack: ERROR - 로컬 미디어 스트림 생성 실패")
             return
        }
        print("setupLocalAudioTrack: 로컬 미디어 스트림 생성됨 (ID: \(streamId))")

        localStream.addAudioTrack(currentAudioTrack)
        print("setupLocalAudioTrack: 오디오 트랙 로컬 스트림에 추가됨")

        guard let pc = peerConnection else {
             print("setupLocalAudioTrack: ERROR - PeerConnection이 nil 상태")
             return
        }
        pc.add(currentAudioTrack, streamIds: [streamId])
        print("setupLocalAudioTrack: 오디오 트랙 PeerConnection에 추가됨")
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
                print("SDP 생성 에러: \(error?.localizedDescription ?? "알 수 없는 에러")")
                completion(false)
                return
            }
            
            self.peerConnection?.setLocalDescription(sdp) { error in
                if let error = error {
                    print("로컬 SDP 설정 에러: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                self.sendOffer(sdp: sdp.sdp, ephemeralKey: ephemeralKey, completion: completion)
            }
        }
    }
    
    private func sendOffer(sdp: String, ephemeralKey: String, completion: @escaping (Bool) -> Void) {
        let baseUrl = "https://api.openai.com/v1/realtime"
        let model = "gpt-4o-realtime-preview-2024-12-17"
        
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
                print("네트워크 에러: \(error?.localizedDescription ?? "알 수 없는 에러")")
                completion(false)
                return
            }
            
            if let sdpString = String(data: data, encoding: .utf8) {
                let sdp = RTCSessionDescription(type: .answer, sdp: sdpString)
                self.peerConnection?.setRemoteDescription(sdp) { error in
                    if let error = error {
                        print("원격 SDP 설정 에러: \(error.localizedDescription)")
                        completion(false)
                    } else {
                        print("WebRTC 연결 완료!")
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
        print("WebRTC 연결 정리 중...")
        
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
        
        isConnected = false
        // 메인 스레드에서 콜백 호출
        DispatchQueue.main.async {
            self.onStateChange?(false)
        }
        
        print("WebRTC 연결 정리 완료")
    }
    
    func disconnect() {
        connectionLock.lock()
        cleanupConnection()
        connectionLock.unlock()
    }
    
    func setCostLimit(_ limit: Double) {
        costLimit = limit
    }
    
    private func sendConversationsToServer() {
        guard !conversations.isEmpty else { return }
        
        var request = URLRequest(url: serverURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "conversations": conversations,
            "totalCost": currentSessionCost
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("서버 전송 에러: \(error.localizedDescription)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    print("대화 내용 서버 전송 성공")
                    // 성공 시 대화 내용 초기화 (선택적)
                    // self.conversations = []
                }
            }.resume()
        } catch {
            print("대화 내용 JSON 변환 에러: \(error.localizedDescription)")
        }
    }
    
    private func stopConversationIfLimitReached(currentCost: Double) {
        // 1) 이미 한 번 트리거했다면 중복 방지
        guard currentCost >= costLimit, !pendingEndCall else { return }
        print("비용 제한(\(costLimit)달러)에 도달")
    }
    
    // 콜 매니저 설정 메소드 추가
    func setCallManager(_ manager: CallManager) {
        self.callManager = manager
    }

    // 통화 시작 시 호출되는 메서드
    // 반환 타입을 Bool로 변경하여 포인트 부족 시 실패를 알림
    func startCall() async -> Bool {
        print("startCall")
        
        // currentAuthId를 startCall 시작 시점에 session으로부터 가져오도록 수정
        do {
            let session = try await client.auth.session
            self.currentAuthId = session.user.id.uuidString
            print("사용자 인증 ID 설정: \(self.currentAuthId ?? "없음")")
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
            print("사용자 포인트 확인 중... 사용자 ID: \(currentAuthUserId)")
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
            } else {
                 // 데이터가 비어있으면 pointsResponse는 nil로 유지
                 print("포인트 조회 결과 데이터가 비어있습니다. 사용자 ID: \(currentAuthUserId)")
            }

            if pointsResponse == nil {
                print("startCall 실패: 사용자 ID \(currentAuthUserId)에 대한 포인트 레코드가 없어 통화를 시작할 수 없습니다.")
                return false // 데이터(포인트 레코드)가 없어서 통화 시작 실패
            }

            // 레코드가 있으면 실제 포인트 값 확인
            // pointsResponse가 nil이 아니므로 강제 언래핑 사용 가능 (위에서 nil 체크됨)
            let currentPoints = pointsResponse!.points 
            print("현재 사용자 포인트: \(currentPoints)")

            if currentPoints <= 0 {
                print("포인트 부족(\(currentPoints) 포인트)으로 통화를 시작할 수 없습니다.")
                return false // 포인트 부족 시 false 반환
            }
        } catch {
            print("startCall 오류: 사용자 포인트를 가져오는데 실패했습니다 - \(error.localizedDescription)")
            // 포인트 조회 실패 시 통화 시작을 막을지, 아니면 일단 진행하고 나중에 차감 시도할지 정책 필요
            // 여기서는 일단 실패로 간주하고 false 반환
            return false
        }

        // 포인트가 충분하면 통화 기록 생성 및 나머지 로직 진행
        print("포인트 충분. 통화 기록 생성 시작...")
        conversations = [] // 대화 내용 초기화
        
        do {
            // 사용자 ID는 위에서 이미 currentAuthUserId로 가져왔으므로 재사용
            let newHistory = HistoryRecord(
                transcript: "",
                summary: "",
                auth_id: currentAuthUserId 
            )

            print("insert 요청: \(newHistory)")
            let result = try await client
                .from("history")
                .insert(newHistory)
                .select()
                .single()
                .execute()

            print("Supabase 응답 전체: \(result)")
            
            // JSON 데이터로 직접 파싱
            let data = result.data
            if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let id = json["id"] as? Int64 {
                currentCallId = id
                print("새로운 통화 기록 생성 완료: \(id)")
            } else {
                print("통화 기록 생성 실패: 응답 데이터 파싱 실패")
            }
        } catch {
            print("통화 기록 생성 오류: \(error)")
            return false // 통화 기록 생성 중 오류 발생
        }

        return true // 통화 기록 생성 성공
    }

    // Supabase에서 사용자 포인트 업데이트 및 부족 시 통화 종료 처리
    private func updateUserPoints(pointsToDeduct: Int) async {
        guard let authId = self.currentAuthId else {
            print("포인트 차감 오류: 사용자 인증 ID를 찾을 수 없습니다.")
            CallManager.shared.callError = "사용자 정보를 확인할 수 없어 포인트 차감에 실패했습니다."
            return
        }

        guard pointsToDeduct > 0 else {
            print("차감할 포인트가 없습니다.")
            return
        }

        print("포인트 차감 시도: \(pointsToDeduct) 포인트, 사용자 ID: \(authId)")

        do {
            let response = try await client
                .from("user_monthly_points")
                .select("points")
                .eq("user_id", value: authId)
                .limit(1)
                .execute()

            var currentPointsResult: CurrentPointsResponse? = nil
            if !response.data.isEmpty {
                let currentPointsResults = try JSONDecoder().decode([CurrentPointsResponse].self, from: response.data)
                currentPointsResult = currentPointsResults.first
            } else {
                print("포인트 업데이트 중 조회 결과 데이터가 비어있습니다. 사용자 ID: \(authId)")
                CallManager.shared.callError = "포인트 정보를 업데이트하는 중 문제가 발생했습니다 (코드: UPU-ND)."
                disconnect()
                if let manager = self.callManager {
                    DispatchQueue.main.async { manager.endCall() }
                }
                return
            }

            guard let unwrappedPointsResult = currentPointsResult else {
                print("포인트 차감 오류: 사용자 ID \(authId)에 대한 포인트 레코드를 찾을 수 없습니다. 통화를 종료합니다.")
                CallManager.shared.callError = "포인트 정보를 찾을 수 없어 통화가 중단되었습니다 (코드: UPU-NR)."
                disconnect()
                if let manager = self.callManager {
                    DispatchQueue.main.async { manager.endCall() }
                }
                return
            }

            let currentPoints = unwrappedPointsResult.points
            print("현재 포인트: \(currentPoints)")

            let newPoints = currentPoints - pointsToDeduct

            if newPoints < 0 {
                print("포인트 부족! 현재 포인트: \(currentPoints), 필요 포인트: \(pointsToDeduct). 통화를 종료합니다.")
                CallManager.shared.callError = "무료 사용량을 모두 소진하여 통화가 중단되었습니다. 무료 사용량은 매월 1일 초기화됩니다."
                
                try await client
                    .from("user_monthly_points")
                    .update(["points": 0])
                    .eq("user_id", value: authId)
                    .execute()
                
                disconnect()
                if let manager = self.callManager {
                    DispatchQueue.main.async {
                        manager.endCall()
                    }
                }
            } else {
                try await client
                    .from("user_monthly_points")
                    .update(["points": newPoints])
                    .eq("user_id", value: authId)
                    .execute()
                print("포인트 차감 완료. 새로운 포인트: \(newPoints)")
                CallManager.shared.callError = nil // 성공적인 차감 후에는 기존 오류 메시지 클리어
            }
        } catch {
            print("Supabase 포인트 업데이트/조회 오류: \(error.localizedDescription)")
            CallManager.shared.callError = "포인트 처리 중 오류가 발생하여 통화가 중단될 수 있습니다: \(error.localizedDescription)"
            // 오류 발생 시에도 통화가 계속 진행되지 않도록 종료 처리하는 것이 안전할 수 있습니다.
            // disconnect()
            // if let manager = self.callManager {
            //    DispatchQueue.main.async { manager.endCall() }
            // }
        }
    }

    // 통화 내용을 Supabase에 저장하는 메서드
    private func saveConversationToSupabase(transcript: String) {
        print("통화 기록 저장 시작: \(currentCallId)")
        guard let callId = currentCallId else { return }
        
        Task {
            do {
                print("통화 기록 업데이트 시작: \(callId)")
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
                    
                    print("통화 기록 업데이트 완료: \(callId)")
                } else {
                    print("기존 transcript 가져오기 실패")
                }
            } catch {
                print("Supabase 저장 오류: \(error.localizedDescription)")
            }
        }
    }

    // 포인트만 확인하는 함수
    public func checkSufficientPoints() async -> Bool { // 접근 제어 수준을 public으로 명시하거나 생략(internal)
        // currentAuthId 설정 (startCall과 유사하게 세션에서 가져오기)
        do {
            let session = try await client.auth.session
            self.currentAuthId = session.user.id.uuidString
        } catch {
            print("checkSufficientPoints 오류: 사용자 세션 정보를 가져오는데 실패했습니다 - \(error.localizedDescription)")
            // MainView에서 이 오류를 사용자에게 알릴 수 있도록 CallManager 등을 통해 오류 전달 고려
            // callManager.callError = "사용자 정보를 확인할 수 없습니다." 
            return false
        }
        
        guard let currentAuthUserId = self.currentAuthId else {
            print("checkSufficientPoints 오류: 사용자 인증 ID가 없습니다.")
            // callManager.callError = "사용자 인증 정보를 찾을 수 없습니다."
            return false
        }

        print("checkSufficientPoints: 사용자 포인트 확인 중... 사용자 ID: \(currentAuthUserId)")
        do {
            let response = try await client
                .from("user_monthly_points")
                .select("points")
                .eq("user_id", value: currentAuthUserId)
                .limit(1)
                .execute()

            var pointsResponse: CurrentPointsResponse? = nil
            if !response.data.isEmpty {
                let pointsResponses = try JSONDecoder().decode([CurrentPointsResponse].self, from: response.data)
                pointsResponse = pointsResponses.first
            }

            if pointsResponse == nil {
                print("checkSufficientPoints: 사용자 ID \(currentAuthUserId)에 대한 포인트 레코드가 없습니다.")
                // MainView에서 알림을 위해 CallManager를 통해 오류 메시지 설정 가능
                // CallManager.shared.callError = "포인트 정보를 찾을 수 없습니다. 고객센터에 문의해주세요."
                return false 
            }

            let currentPoints = pointsResponse!.points
            print("checkSufficientPoints: 현재 사용자 포인트: \(currentPoints)")

            if currentPoints <= 0 {
                print("checkSufficientPoints: 포인트 부족(\(currentPoints) 포인트).")
                CallManager.shared.callError = "무료 사용량을 모두 소진하셨습니다. 무료 사용량은 매월 1일 초기화됩니다."
                return false
            }
            
            print("checkSufficientPoints: 포인트 충분함 (\(currentPoints) 포인트).")
            return true // 포인트 충분

        } catch {
            print("checkSufficientPoints 오류: 사용자 포인트를 가져오는데 실패했습니다 - \(error.localizedDescription)")
            CallManager.shared.callError = "포인트 조회 중 오류가 발생했습니다."
            return false // 오류 발생 시 실패로 간주
        }
    }
}

// MARK: - RTCPeerConnectionDelegate
extension RealtimeAIConnection: RTCPeerConnectionDelegate {
    func peerConnectionDidStartCommunication(_ peerConnection: RTCPeerConnection) {
        print("통신이 시작되었습니다")
        NotificationCenter.default.post(name: .aiAudioDebugUpdate, object: nil, userInfo: ["message": "AI: PeerConnection 통신 시작됨"])
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didStartReceivingOn transceiver: RTCRtpTransceiver) {
        print("수신 시작됨: \(transceiver.mid ?? "unknown")")
        NotificationCenter.default.post(name: .aiAudioDebugUpdate, object: nil, userInfo: ["message": "AI: PeerConnection 수신 시작됨 (mid: \(transceiver.mid ?? "unknown"))"])
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        print("데이터 채널 열림: \(dataChannel.label)")
        NotificationCenter.default.post(name: .aiAudioDebugUpdate, object: nil, userInfo: ["message": "AI: 데이터 채널 열림 (label: \(dataChannel.label))"])
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCPeerConnectionState) {
        print("PeerConnection 상태 변경: \(newState.rawValue)")
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
        print("ICE 연결 상태 변경: \(newState.rawValue)")
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
        
        if newState == .disconnected || newState == .failed || newState == .closed {
            isConnected = false
            DispatchQueue.main.async {
                self.onStateChange?(false)
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
        print("데이터 채널 상태 변경: \(dataChannel.readyState.rawValue)")
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
            // print("데이터 채널 메시지 수신: \\(message)")
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
                                    print("음성 입력: \(transcript)\n")
                                    
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
                                // AI 응답 완료 시 (텍스트만 있는 경우)
                                if let response = jsonData["response"] as? [String: Any],
                                   let output = response["output"] as? [[String: Any]],
                                   let messageContent = output.first?["content"] as? [[String: Any]],
                                   let transcript = messageContent.first?["transcript"] as? String {
                                    debugMessage = "AI: 응답 완료 - \(transcript)"
                                    // ... 기존 비용 계산 및 저장 로직 ...
                                }
                            case "output_audio_buffer.started":
                                 debugMessage = "AI: 응답 오디오 재생 시작"
                            case "output_audio_buffer.stopped":
                                 debugMessage = "AI: 응답 오디오 재생 종료"
                                 // ... 기존 종료 처리 로직 ...
                            default:
                                // 다른 타입의 메시지는 일단 무시 (필요시 추가)
                                break
                            }
                            
                            // 디버그 메시지가 있으면 알림 발송
                            if let msg = debugMessage {
                                print("AI Debug: \(msg)") // 콘솔에도 로그 출력
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
                            // print("jsonData: \(jsonData)")
                            if let transcript = jsonData["transcript"] as? String {
                                print("음성 입력: \(transcript)\n")
                                
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
                        
                        if let type = jsonData["type"] as? String, type == "response.done" {
                            // print(jsonData)
                            if let response = jsonData["response"] as? [String: Any],
                               let output = response["output"] as? [[String: Any]],
                               let messageContent = output.first?["content"] as? [[String: Any]],
                               let transcript = messageContent.first?["transcript"] as? String,
                               let usage = response["usage"] as? [String: Any],
                               let inputTokens = usage["input_token_details"] as? [String: Any],
                               let inputAudioTokens = inputTokens["audio_tokens"] as? Int,
                               let inputTextTokens = inputTokens["text_tokens"] as? Int,
                               let inputCachedTokens = inputTokens["cached_tokens_details"] as? [String: Any],
                               let inputCachedAudioTokens = inputCachedTokens["audio_tokens"] as? Int,
                               let inputCachedTextTokens = inputCachedTokens["text_tokens"] as? Int,
                               let outputTokens = usage["output_token_details"] as? [String: Any],
                               let outputAudioTokens = outputTokens["audio_tokens"] as? Int,
                               let outputTextTokens = outputTokens["text_tokens"] as? Int {

                                // 백만 토큰당 비용 (gpt-4o-mini-realtime-preview)
                                let audioInputRate = 10.0  // $10.00 per 1M tokens
                                let textInputRate = 0.6    // $0.60 per 1M tokens
                                let cachedRate = 0.3       // $0.30 per 1M tokens 
                                let audioOutputRate = 20.0 // $20.00 per 1M tokens
                                let textOutputRate = 2.4   // $2.40 per 1M tokens
                                
                                let millionTokens = 1_000_000.0
                                
                                let audioInputCost = Double(inputAudioTokens) * audioInputRate / millionTokens
                                let textInputCost = Double(inputTextTokens) * textInputRate / millionTokens
                                let audioCachedCost = Double(inputCachedAudioTokens) * cachedRate / millionTokens
                                let textCachedCost = Double(inputCachedTextTokens) * cachedRate / millionTokens
                                let audioOutputCost = Double(outputAudioTokens) * audioOutputRate / millionTokens
                                let textOutputCost = Double(outputTextTokens) * textOutputRate / millionTokens

                                // 음성 기록 $0.0001 = 1000 ms (whisper-1)
                                let audioDurationSeconds = Double(audioDuration) / 1000.0
                                let audioCost = audioDurationSeconds * 0.0001
                                
                                let totalCost = audioInputCost + textInputCost + audioCachedCost + textCachedCost + audioOutputCost + textOutputCost + audioCost
                                
                                // 현재 세션 비용 누적
                                currentSessionCost += totalCost
                                
                                // 비용을 포인트로 변환 (0.000001 달러당 1 포인트)
                                let pointsToDeduct = Int(totalCost / 0.000001)

                                debugMessage = "AI: 응답 완료 - \(transcript)"
                                print("AI 응답: \(transcript)\n")
                                print("비용 내역: 오디오 입력=$\(String(format: "%.6f", audioInputCost)), 텍스트 입력=$\(String(format: "%.6f", textInputCost))")
                                print("         캐시된 오디오=$\(String(format: "%.6f", audioCachedCost)), 캐시된 텍스트=$\(String(format: "%.6f", textCachedCost))")
                                print("         오디오 출력=$\(String(format: "%.6f", audioOutputCost)), 텍스트 출력=$\(String(format: "%.6f", textOutputCost))")
                                print("         음성 기록=$\(String(format: "%.6f", audioCost))")
                                print("총 비용: $\(String(format: "%.6f", totalCost)) (차감될 포인트: \(pointsToDeduct))")
                                print("누적 비용: $\(String(format: "%.6f", currentSessionCost))")
                                
                                // AI 응답 기록
                                let aiResponse: [String: Any] = [
                                    "role": "assistant",
                                    "content": transcript,
                                    "cost": totalCost,
                                    "pointsDeducted": pointsToDeduct, // 차감된 포인트도 기록
                                    "costDetails": [
                                        "audioInputCost": audioInputCost,
                                        "textInputCost": textInputCost,
                                        "audioCachedCost": audioCachedCost,
                                        "textCachedCost": textCachedCost,
                                        "audioOutputCost": audioOutputCost,
                                        "textOutputCost": textOutputCost,
                                        "audioCost": audioCost
                                    ],
                                    "timestamp": Date().timeIntervalSince1970
                                ]
                                conversations.append(aiResponse)
                                
                                // Supabase에 저장 (AI 응답)
                                saveConversationToSupabase(transcript: "AI: \(transcript)")

                                // 포인트 차감 로직 호출 (비동기적으로 실행)
                                if pointsToDeduct > 0 {
                                    Task {
                                        await updateUserPoints(pointsToDeduct: pointsToDeduct)
                                    }
                                }
                            }
                        }

                        if let type = jsonData["type"] as? String, type == "response.function_call_arguments.done" {
                            print("response.function_call_arguments.done")
                            if let functionName = jsonData["name"] as? String, 
                               let callId = jsonData["call_id"] as? String {
                                if functionName == "endCall" {
                                    print("endCall 함수 호출")
                                    
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
                                        print("함수 호출 결과 전송 오류: \(error)")
                                        
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
                            print("AI 오디오 출력 종료")
                            
                            // 종료 플래그가 설정되어 있으면 실제로 종료 실행
                            if pendingEndCall {
                                print("AI 응답 완료 후 종료 실행")
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

                            // 비용 제한 확인 및 필요시 대화 중단
                            // stopConversationIfLimitReached(currentCost: currentSessionCost)
                        }
                    }
                } catch {
                    print("JSON 파싱 오류: \(error)")
                }
            }
        }
    }
}