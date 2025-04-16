//
//  RealtimeAIConnection.swift
//  swift-hau
//
//  Created on: 현재 날짜
//

import Foundation
import WebRTC
import AVFoundation

class RealtimeAIConnection: NSObject {
    static let shared = RealtimeAIConnection()
    
    private var peerConnection: RTCPeerConnection?
    private var dataChannel: RTCDataChannel?
    private var audioTrack: RTCAudioTrack?
    private var factory: RTCPeerConnectionFactory?
    private var localMediaStream: RTCMediaStream?
    private var isInitialized = false
    private var connectionLock = NSLock() // 연결 동기화용 락
    
    // 오디오 관련 변수들을 클래스 본문으로 이동
    private var audioStart: Int = 0
    private var audioEnd: Int = 0
    private var audioDuration: Int = 0
    
    // 연결 상태 관리
    var isConnected: Bool = false
    var onStateChange: ((Bool) -> Void)?
    
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
    
    func initialize(with ephemeralKey: String, completion: @escaping (Bool) -> Void) {
        // 동기화 락 사용
        connectionLock.lock()
        
        // 이전 연결 완전히 정리
        cleanupConnection()
        
        print("AI 연결 초기화 시작...")
        
        // 상태 업데이트
        isConnected = false
        onStateChange?(false)
        
        // RTCPeerConnection 생성
        setupPeerConnection()
        
        // 로컬 오디오 트랙 추가
        setupLocalAudioTrack()
        
        // 데이터 채널 설정
        setupDataChannel()
        
        // SDP 오퍼 생성 및 전송
        createAndSendOffer(ephemeralKey: ephemeralKey) { success in
            self.connectionLock.unlock()
            
            if success {
                self.isConnected = true
                self.onStateChange?(true)
                print("AI 연결 성공!")
            } else {
                print("AI 연결 실패")
                // 실패 시 연결 정리
                self.cleanupConnection()
            }
            
            completion(success)
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
        onStateChange?(false)
        
        print("WebRTC 연결 정리 완료")
    }
    
    func disconnect() {
        connectionLock.lock()
        cleanupConnection()
        connectionLock.unlock()
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
            onStateChange?(false)
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
                                
                                print("AI 응답: \(transcript)\n")
                                print("비용 내역: 오디오 입력=$\(String(format: "%.6f", audioInputCost)), 텍스트 입력=$\(String(format: "%.6f", textInputCost))")
                                print("         캐시된 오디오=$\(String(format: "%.6f", audioCachedCost)), 캐시된 텍스트=$\(String(format: "%.6f", textCachedCost))")
                                print("         오디오 출력=$\(String(format: "%.6f", audioOutputCost)), 텍스트 출력=$\(String(format: "%.6f", textOutputCost))")
                                print("         음성 기록=$\(String(format: "%.6f", audioCost))")
                                print("총 비용: $\(String(format: "%.6f", totalCost))")
                            }
                        }
                        
                        if let type = jsonData["type"] as? String, type == "conversation.item.input_audio_transcription.completed" {
                            // print("jsonData: \(jsonData)")
                            if let transcript = jsonData["transcript"] as? String {
                                print("음성 입력: \(transcript)\n")
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