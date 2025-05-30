//
//  GeminiLiveConnection.swift
//  swift-hau
//
//  Created on: 현재 날짜
//

import Foundation
import WebRTC
import AVFoundation
import CallKit
import Supabase

// MARK: - WebSocket을 사용하는 Gemini Live API 연결 클래스
class GeminiLiveConnection: NSObject {
    static let shared = GeminiLiveConnection()
    
    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    
    // 오디오 관련
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var audioFormat: AVAudioFormat?
    
    // 연결 상태 관리
    var isConnected: Bool = false
    var onStateChange: ((Bool) -> Void)?
    var onAudioReceived: ((Data, String?) -> Void)?
    var onTranscriptReceived: ((String) -> Void)?
    
    // MARK: - 새로 추가: 사용자 발화 상태 콜백
    var onUserSpeechStarted: (() -> Void)?
    var onUserSpeechStopped: (() -> Void)?
    var onTurnComplete: (() -> Void)? // 턴 완료 시 호출
    
    // 현재 통화 정보
    private var currentCallId: Int64?
    private var currentAuthId: String?
    
    // 대화 내용과 비용 기록
    private var conversations: [[String: Any]] = []
    private var currentSessionCost: Double = 0.0
    
    private override init() {
        super.init()
        setupAudioSession()
    }
    
    // MARK: - 오디오 세션 설정
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .defaultToSpeaker])
            try audioSession.setActive(true)
        } catch {
            print("GeminiLive: 오디오 세션 설정 실패: \(error)")
        }
    }
    
    // MARK: - WebSocket 연결 초기화
    func initialize(userName: String?, selfIntro: String?, voice: String?, history: [HistoryResponse]?, language: String = "ko") async -> Bool {
        
        // 기존 연결 정리
        await disconnect()
        
        // 서버 URL 구성
        let baseURL = AppConfig.baseURL
        if baseURL.isEmpty {
            print("GeminiLive: 서버 URL이 설정되지 않았습니다.")
            return false
        }
        
        var urlComponents = URLComponents(string: "\(baseURL)/gemini/live")!
        urlComponents.scheme = baseURL.hasPrefix("https") ? "wss" : "ws"
        
        // 쿼리 파라미터 추가
        var queryItems: [URLQueryItem] = []
        if let userName = userName { queryItems.append(URLQueryItem(name: "user_name", value: userName)) }
        if let selfIntro = selfIntro { queryItems.append(URLQueryItem(name: "self_intro", value: selfIntro)) }
        if let voice = voice { queryItems.append(URLQueryItem(name: "voice", value: voice)) }
        if let history = history {
            let historyData = try? JSONEncoder().encode(history)
            if let historyString = historyData.flatMap({ String(data: $0, encoding: .utf8) }) {
                queryItems.append(URLQueryItem(name: "history", value: historyString))
            }
        }
        queryItems.append(URLQueryItem(name: "language", value: language))
        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.url else {
            print("GeminiLive: 잘못된 URL 구성")
            return false
        }
        
        // WebSocket 연결 생성
        urlSession = URLSession(configuration: .default)
        webSocket = urlSession?.webSocketTask(with: url)
        
        // WebSocket 메시지 수신 시작
        startReceivingMessages()
        
        // 연결 시작
        webSocket?.resume()
        
        // 오디오 엔진 설정
        setupAudioEngine()
        
        return await withCheckedContinuation { continuation in
            // 연결 상태 확인을 위해 약간의 지연 후 확인
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                let connected = self.webSocket?.state == .running
                self.isConnected = connected
                self.onStateChange?(connected)
                continuation.resume(returning: connected)
            }
        }
    }
    
    // MARK: - 메시지 수신 시작
    private func startReceivingMessages() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                self?.handleReceivedMessage(message)
                // 다음 메시지 수신을 위해 재귀 호출
                self?.startReceivingMessages()
                
            case .failure(let error):
                print("GeminiLive: WebSocket 메시지 수신 오류: \(error)")
                self?.handleConnectionError()
            }
        }
    }
    
    // MARK: - 수신된 메시지 처리
    private func handleReceivedMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            handleTextMessage(text)
        case .data(let data):
            handleBinaryMessage(data)
        @unknown default:
            print("GeminiLive: 알 수 없는 메시지 타입")
        }
    }
    
    private func handleTextMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("GeminiLive: JSON 파싱 실패")
            return
        }
        
        guard let type = json["type"] as? String else {
            print("GeminiLive: 메시지 타입 없음")
            return
        }
        
        switch type {
        case "connection_established":
            print("GeminiLive: 연결 성공")
            isConnected = true
            DispatchQueue.main.async {
                self.onStateChange?(true)
            }
            
        case "gemini_message":
            handleGeminiMessage(json["data"] as? [String: Any])
            
        // MARK: - 새로 추가: 사용자 발화 상태 메시지 처리
        case "setup_complete":
            print("GeminiLive: API 설정 완료")
            
        case "user_speech_started":
            print("GeminiLive: 사용자 발화 시작 감지")
            DispatchQueue.main.async {
                self.onUserSpeechStarted?()
            }
            
        case "user_speech_stopped":
            print("GeminiLive: 사용자 발화 종료 감지")
            DispatchQueue.main.async {
                self.onUserSpeechStopped?()
            }
            
        case "error":
            print("GeminiLive: 서버 오류: \(json["message"] ?? "알 수 없는 오류")")
            handleConnectionError()
            
        default:
            print("GeminiLive: 알 수 없는 메시지 타입: \(type)")
        }
    }
    
    private func handleBinaryMessage(_ data: Data) {
        // 바이너리 오디오 데이터 처리
        DispatchQueue.main.async {
            self.onAudioReceived?(data, nil)
        }
    }
    
    private func handleGeminiMessage(_ geminiData: [String: Any]?) {
        guard let data = geminiData else { 
            print("🔍 GeminiLive: Gemini 데이터가 없습니다")
            return 
        }
        
        // print("🔍 GeminiLive: Gemini 메시지 수신: \(data)")
        
        // serverContent 확인
        guard let serverContent = data["serverContent"] as? [String: Any] else {
            print("🔍 GeminiLive: serverContent 없음")
            return
        }
        
        // generationComplete 확인
        if let generationComplete = serverContent["generationComplete"] as? Int, 
           generationComplete == 1 {
            print("✅ GeminiLive: 생성 완료")
            return
        }
        
        // turnComplete 확인
        if let turnComplete = serverContent["turnComplete"] as? Int, 
           turnComplete == 1 {
            print("✅ GeminiLive: 턴 완료")
            
            // MARK: - 새로 추가: 턴 완료 콜백 호출
            DispatchQueue.main.async {
                self.onTurnComplete?()
            }
            
            // 사용량 정보 확인
            if let usageMetadata = data["usageMetadata"] as? [String: Any] {
                print("📊 GeminiLive: 사용량 - \(usageMetadata)")
            }
            return
        }
        
        // modelTurn 확인 및 처리
        guard let modelTurn = serverContent["modelTurn"] as? [String: Any],
              let parts = modelTurn["parts"] as? [[String: Any]] else {
            print("🔍 GeminiLive: modelTurn/parts 구조 없음 - 다른 응답 유형")
            return
        }
        
        print("🔍 GeminiLive: parts 개수: \(parts.count)")
        
        for (index, part) in parts.enumerated() {
            // print("🔍 GeminiLive: part[\(index)]: \(part)")
            
            // 텍스트 응답 처리
            if let text = part["text"] as? String {
                print("📝 GeminiLive: 텍스트 응답 수신: \(text)")
                DispatchQueue.main.async {
                    self.onTranscriptReceived?(text)
                }
            }
            
            // 오디오 응답 처리
            if let inlineData = part["inlineData"] as? [String: Any] {
                // print("🎵 GeminiLive: inlineData 발견: \(inlineData)")
                
                if let audioData = inlineData["data"] as? String {
                    print("🎵 GeminiLive: Base64 오디오 데이터 길이: \(audioData.count)")
                    
                    if let audioBytes = Data(base64Encoded: audioData) {
                        print("🎵 GeminiLive: 오디오 바이트 변환 성공, 크기: \(audioBytes.count) bytes")
                        DispatchQueue.main.async {
                            self.onAudioReceived?(audioBytes, inlineData["mimeType"] as? String)
                        }
                    } else {
                        print("❌ GeminiLive: Base64 오디오 데이터 변환 실패")
                    }
                }
            } else {
                print("🔍 GeminiLive: inlineData 없음")
            }
        }
    }
    
    // MARK: - 오디오 엔진 설정
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        inputNode = audioEngine?.inputNode
        
        guard let audioEngine = audioEngine,
              let inputNode = inputNode else {
            print("GeminiLive: 오디오 엔진 초기화 실패")
            return
        }
        
        // 하드웨어 포맷 사용 (포맷 불일치 방지)
        let hardwareFormat = inputNode.inputFormat(forBus: 0)
        print("GeminiLive: 하드웨어 포맷: \(hardwareFormat)")
        
        // Gemini API가 요구하는 포맷 (16kHz, 16-bit, mono)
        let targetFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: false)
        
        guard let targetFormat = targetFormat else {
            print("GeminiLive: 타겟 오디오 포맷 설정 실패")
            return
        }
        
        // 포맷 변환기 생성
        let converter = AVAudioConverter(from: hardwareFormat, to: targetFormat)
        guard let converter = converter else {
            print("GeminiLive: 오디오 포맷 변환기 생성 실패")
            return
        }
        
        // 하드웨어 포맷으로 오디오 입력 처리
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: hardwareFormat) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer, converter: converter, targetFormat: targetFormat)
        }
        
        do {
            try audioEngine.start()
            print("GeminiLive: 오디오 엔진 시작 성공")
        } catch {
            print("GeminiLive: 오디오 엔진 시작 실패: \(error)")
        }
    }
    
    // MARK: - 오디오 버퍼 처리
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, converter: AVAudioConverter, targetFormat: AVAudioFormat) {
        guard let webSocket = webSocket,
              webSocket.state == .running else { return }
        
        // 변환된 버퍼 생성
        let frameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * targetFormat.sampleRate / buffer.format.sampleRate)
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCapacity) else {
            print("GeminiLive: 변환 버퍼 생성 실패")
            return
        }
        
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        // 오디오 포맷 변환
        converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)
        
        if let error = error {
            print("GeminiLive: 오디오 변환 오류: \(error)")
            return
        }
        
        // 변환된 PCM 데이터를 Base64로 인코딩
        guard let channelData = convertedBuffer.int16ChannelData?[0] else {
            print("GeminiLive: 채널 데이터 없음")
            return
        }
        
        let frameLength = Int(convertedBuffer.frameLength)
        let data = Data(bytes: channelData, count: frameLength * 2) // 16-bit = 2 bytes
        let base64Audio = data.base64EncodedString()
        
        // WebSocket으로 오디오 데이터 전송
        let message: [String: Any] = [
            "type": "audio_data",
            "audio": base64Audio
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: message),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            webSocket.send(.string(jsonString)) { error in
                if let error = error {
                    print("GeminiLive: 오디오 전송 오류: \(error)")
                }
            }
        }
    }
    
    // MARK: - 대화 턴 종료
    func endTurn() {
        guard let webSocket = webSocket,
              webSocket.state == .running else { return }
        
        let message: [String: Any] = [
            "type": "end_turn"
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: message),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            webSocket.send(.string(jsonString)) { error in
                if let error = error {
                    print("GeminiLive: 턴 종료 신호 전송 오류: \(error)")
                }
            }
        }
    }
    
    // MARK: - 연결 종료
    func disconnect() async {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        urlSession = nil
        
        isConnected = false
        DispatchQueue.main.async {
            self.onStateChange?(false)
        }
    }
    
    // MARK: - 연결 오류 처리
    private func handleConnectionError() {
        Task {
            await disconnect()
        }
    }
    
    // MARK: - 통화 기록 저장 (기존 코드와 호환성을 위해 유지)
    func saveConversationHistory(transcript: String, summary: String) async {
        guard let currentAuthId = currentAuthId else { return }
        
        let record = HistoryRecord(
            transcript: transcript,
            summary: summary,
            auth_id: currentAuthId
        )
        
        do {
            let _: [HistoryResponse] = try await client
                .database
                .from("history")
                .insert(record)
                .execute()
                .value
            
            print("GeminiLive: 통화 기록 저장 성공")
        } catch {
            print("GeminiLive: 통화 기록 저장 실패: \(error)")
        }
    }
} 
