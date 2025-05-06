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
        let audioConstrains = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        let audioSource = factory?.audioSource(with: audioConstrains)
        audioTrack = factory?.audioTrack(with: audioSource!, trackId: "audio0")
        
        let streamId = "stream0"
        let localStream = factory?.mediaStream(withStreamId: streamId)
        localStream?.addAudioTrack(audioTrack!)
        
        peerConnection?.add(audioTrack!, streamIds: [streamId])
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
    func startCall() async {
        print("startCall")
        conversations = []
        do {
            let session = try await client.auth.session
            let userId = session.user.id.uuidString
            print("userId: \(userId)")

            let newHistory = HistoryRecord(
                transcript: "",
                summary: "",
                auth_id: userId
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
}

// MARK: - RTCPeerConnectionDelegate
extension RealtimeAIConnection: RTCPeerConnectionDelegate {
    func peerConnectionDidStartCommunication(_ peerConnection: RTCPeerConnection) {
        print("통신이 시작되었습니다")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didStartReceivingOn transceiver: RTCRtpTransceiver) {
        print("수신 시작됨: \(transceiver.mid ?? "unknown")")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        print("데이터 채널 열림: \(dataChannel.label)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCPeerConnectionState) {
        print("PeerConnection 상태 변경: \(newState.rawValue)")
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
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        print("ICE 연결 상태 변경: \(newState.rawValue)")
        if newState == .disconnected || newState == .failed || newState == .closed {
            isConnected = false
            // 메인 스레드에서 콜백 호출
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
    }
    
    func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        if let message = String(data: buffer.data, encoding: .utf8) {
            // print("데이터 채널 메시지 수신: \(message)")
            if let json = message.data(using: .utf8) {
                do {
                    if let jsonData = try JSONSerialization.jsonObject(with: json, options: []) as? [String: Any] {
                        /*
                            gpt-4o-mini-realtime-preview audio
                            input
                            $10.00 = 1,000,000 tokens (1 token = $0.000010)
                            cached
                            $0.30 = 1,000,000 tokens (1 token = $0.0000003)
                            output
                            $20.00 = 1,000,000 tokens (1 token = $0.000020)

                            gpt-4o-mini-realtime-preview text
                            input
                            $0.60 = 1,000,000 tokens (1 token = $0.0000006)
                            cached
                            $0.30 = 1,000,000 tokens (1 token = $0.0000003)
                            output
                            $2.40 = 1,000,000 tokens (1 token = $0.0000024)
                        
                            [
                                "input_token_details": {
                                    "audio_tokens" = 728;
                                    "cached_tokens" = 1408;
                                    "cached_tokens_details" = {
                                        "audio_tokens" = 640;
                                        "text_tokens" = 768;
                                    };
                                    "text_tokens" = 801;
                                }, 
                                "output_token_details": {
                                    "audio_tokens" = 255;
                                    "text_tokens" = 75;
                                }, 
                                "total_tokens": 1859, 
                                "output_tokens": 330, 
                                "input_tokens": 1529
                            ]
                        */

                        // if let type = jsonData["type"] as? String {
                        //     if type != "response.audio_transcript.delta" {
                        //         print("type: \(type)")

                        //         do {
                        //             let jsonDataUTF8 = try JSONSerialization.data(withJSONObject: jsonData, options: .prettyPrinted)
                        //             if let jsonString = String(data: jsonDataUTF8, encoding: .utf8) {
                        //                 print("jsonData (UTF-8): \n\(jsonString)")
                        //             }
                        //         } catch {
                        //                 print("JSON 변환 오류: \(error)")
                        //         }
                        //     }
                        // }

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
                               let message = output.first?["content"] as? [[String: Any]],
                               let transcript = message.first?["transcript"] as? String,
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
                                
                                print("AI 응답: \(transcript)\n")
                                print("비용 내역: 오디오 입력=$\(String(format: "%.6f", audioInputCost)), 텍스트 입력=$\(String(format: "%.6f", textInputCost))")
                                print("         캐시된 오디오=$\(String(format: "%.6f", audioCachedCost)), 캐시된 텍스트=$\(String(format: "%.6f", textCachedCost))")
                                print("         오디오 출력=$\(String(format: "%.6f", audioOutputCost)), 텍스트 출력=$\(String(format: "%.6f", textOutputCost))")
                                print("         음성 기록=$\(String(format: "%.6f", audioCost))")
                                print("총 비용: $\(String(format: "%.6f", totalCost))")
                                print("누적 비용: $\(String(format: "%.6f", currentSessionCost))")
                                
                                // AI 응답 기록
                                let aiResponse: [String: Any] = [
                                    "role": "assistant",
                                    "content": transcript,
                                    "cost": totalCost,
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
                                
                                // Supabase에 저장
                                saveConversationToSupabase(transcript: "AI: \(transcript)")
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