import SwiftUI
import PushKit
import CallKit
import AVFoundation

// CallKit과 PushKit을 관리하는 클래스
class CallManager: NSObject, ObservableObject, CXProviderDelegate, PKPushRegistryDelegate {
    @Published var isCallActive = false
    @Published var shouldShowCallScreen = false
    @Published var isCallInProgress = false  // 통화 중 또는 통화 알림 진행 중 상태 추적
    @Published var callScreenPresentationID = UUID()
    @Published var userViewModel: UserViewModel = UserViewModel()
    @Published var callError: String? = nil // 통화 오류 메시지 저장
    
    // 사용자 ID 추가
    private var currentUserId: String? = nil
    private var hasPendingToken: Bool = false
    private var pendingToken: String? = nil
    
    // 싱글톤 인스턴스
    static let shared = CallManager()
    
    private let provider: CXProvider
    private let callController = CXCallController()
    private var pushRegistry: PKPushRegistry?
    private var uuid: UUID?
    
    // 서버 API 엔드포인트
    private let serverURL = "http://3.34.190.29:3000/api/v1"
    
    override init() {
        // CallKit 제공자 설정
        let providerConfiguration = CXProviderConfiguration()
        providerConfiguration.supportsVideo = false
        providerConfiguration.maximumCallsPerCallGroup = 1
        providerConfiguration.supportedHandleTypes = [.phoneNumber, .generic]
        providerConfiguration.ringtoneSound = "ringtone.wav" // 앱 번들에 추가해야 함
        
        provider = CXProvider(configuration: providerConfiguration)
        
        super.init()
        
        provider.setDelegate(self, queue: nil)
        
        print("CallManager: 초기화됨")
    }
    
    // VoIP 푸시 알림 설정
    func setupVoIP() {
        pushRegistry = PKPushRegistry(queue: .main)
        pushRegistry?.delegate = self
        pushRegistry?.desiredPushTypes = [.voIP]
    }
    
    // 수신 전화 시뮬레이션 (실제로는 서버에서 푸시 알림을 받음)
    func simulateIncomingCall() {
        reportIncomingCall(uuid: UUID(), handle: "010-1234-5678", hasVideo: false)
    }
    
    // 수신 전화 보고
    func reportIncomingCall(uuid: UUID, handle: String, hasVideo: Bool = false, completion: ((Bool) -> Void)? = nil) {
        // 이미 통화 중이거나 알림이 진행 중이면 새 통화 거부
        if isCallInProgress {
            print("이미 통화 중이거나, 통화 알림이 진행 중입니다. 새 통화 요청 무시")
            completion?(false)
            return
        }
        
        self.uuid = uuid
        isCallInProgress = true  // 통화 알림 진행 중으로 상태 설정
        
        // 통화 업데이트 설정
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .phoneNumber, value: handle)
        update.hasVideo = hasVideo
        update.localizedCallerName = handle
        
        // 수신 전화 표시
        provider.reportNewIncomingCall(with: uuid, update: update) { error in
            if let error = error {
                print("수신 전화 표시 오류: \(error.localizedDescription)")
                self.isCallActive = false
                self.isCallInProgress = false  // 오류 발생 시 상태 초기화
                self.callError = error.localizedDescription
                completion?(false)
                return
            }
            
            print("수신 전화 표시 성공")
            self.isCallActive = true
            self.callError = nil
            completion?(true)
        }
    }
    
    // 통화 종료
    func endCall(with uuid: UUID) {
        let endCallAction = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: endCallAction)
        
        // CallKit에 종료 요청
        callController.request(transaction) { error in
            print("CallManager: endCall transaction completion. Error: \(error?.localizedDescription ?? "nil")")
            
            if let error = error {
                print("CallManager: 통화 종료 요청 오류: \(error.localizedDescription)")
                // 오류 발생 시에도 상태는 초기화 (메인 스레드에서)
                DispatchQueue.main.async {
                    self.shouldShowCallScreen = false
                    self.isCallActive = false
                    self.isCallInProgress = false
                }
            } else {
                print("CallManager: 통화 종료 요청 성공")
                
                // *** 수정: shouldShowCallScreen 업데이트에 딜레이 추가 ***
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { // 0.5초 딜레이
                    self.shouldShowCallScreen = false // 화면 전환 트리거
                    print("CallManager: Setting shouldShowCallScreen = false on main thread after delay")
                }
                
                // 나머지 상태 업데이트 및 AI 연결 종료는 딜레이 없이 즉시 수행
                self.isCallActive = false
                self.isCallInProgress = false
                
                if RealtimeAIConnection.shared.isConnected {
                    print("CallManager: Disconnecting AI connection...")
                    RealtimeAIConnection.shared.disconnect()
                }
            }
        }
    }
    
    // 기존 endCall 메서드 (현재 활성화된 통화 종료)
    func endCall() {
        guard let uuid = uuid else { return }
        endCall(with: uuid)
    }
    
    // 서버에 통화 푸시 알림 요청
    func requestCallPush() {
        // 초기 상태 설정
        self.callError = nil
        
        // 사용자 ID 확인
        guard let userId = currentUserId else {
            self.callError = "로그인이 필요합니다."
            print("CallManager: 사용자 ID가 없어 통화 요청을 보낼 수 없습니다.")
            return
        }
        
        // 서버에 보낼 데이터 준비
        let parameters: [String: Any] = [
            "caller_id": userId,  // 발신자 ID는 현재 로그인한 사용자
            "receiver_id": userId,  // 수신자 ID는 파라미터로 전달받은 값
            "caller_name": "HAU"  // 사용자 이름 또는 선택한 음성
        ]
        
        // 서버 요청 생성
        guard let url = URL(string: "\(serverURL)/send-call-push") else { 
            self.callError = "유효하지 않은 서버 주소입니다."
            return 
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10 // 10초 타임아웃
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            print("JSON 직렬화 오류: \(error.localizedDescription)")
            self.callError = "요청 처리 중 오류가 발생했습니다."
            return
        }
        
        print("통화 요청 시작: \(url.absoluteString)")
        
        // 서버 요청 전송
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    print("서버 요청 오류: \(error.localizedDescription)")
                    self.callError = "서버 연결 오류: \(error.localizedDescription)"
                    print("callError 설정됨: \(self.callError ?? "nil")")
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("유효하지 않은 응답")
                    self.callError = "서버로부터 유효하지 않은 응답을 받았습니다."
                    return
                }
                
                print("서버 응답 상태 코드: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    print("통화 푸시 요청이 성공적으로 전송되었습니다.")
                    self.callError = nil
                    
                    // 테스트를 위해 로컬에서 수신 전화 시뮬레이션
                    // 실제로는 서버에서 푸시 알림을 보내고, 그 알림을 받아서 처리함
                    if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let success = json["success"] as? Bool, success == true {
                        print("서버 응답: \(json)")
                    }
                } else {
                    print("서버 오류: 상태 코드 \(httpResponse.statusCode)")
                    
                    if let data = data {
                        do {
                            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let errorMessage = json["error"] as? String {
                                self.callError = errorMessage
                                print("오류 메시지: \(errorMessage)")
                            } else if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                                    let message = json["message"] as? String {
                                self.callError = message
                                print("오류 메시지: \(message)")
                            } else {
                                let responseString = String(data: data, encoding: .utf8) ?? "데이터 없음"
                                print("응답 내용: \(responseString)")
                                self.callError = "서버 오류가 발생했습니다. (코드: \(httpResponse.statusCode))"
                            }
                        } catch {
                            print("응답 파싱 오류: \(error.localizedDescription)")
                            self.callError = "서버 응답을 처리할 수 없습니다."
                        }
                    } else {
                        self.callError = "서버 오류가 발생했습니다. (코드: \(httpResponse.statusCode))"
                    }
                }
            }
        }
        
        task.resume()
    }
    
    // 사용자 ID 설정 메서드 (로그인 성공 후 호출)
    func setUserId(_ userId: String) {
        print("CallManager: 사용자 ID 설정됨 - \(userId)")
        currentUserId = userId
        
        // 이전에 저장된 토큰이 있으면 사용자 ID와 함께 다시 전송
        if hasPendingToken, let token = pendingToken {
            print("CallManager: 보류 중인 토큰을 현재 사용자 ID로 전송합니다.")
            sendTokenToServer(token)
            hasPendingToken = false
            pendingToken = nil
        }
    }
    
    // 사용자 ID 초기화 (로그아웃 시 호출)
    func clearUserId() {
        print("CallManager: 사용자 ID 초기화됨")
        currentUserId = nil
        hasPendingToken = false
        pendingToken = nil
    }
    
    // 서버에 토큰 전송 (public으로 변경)
    func sendTokenToServer(_ token: String) {
        // 사용자 ID가 없으면 토큰을 임시 저장하고 종료
        guard let userId = currentUserId else {
            print("CallManager: 사용자 ID가 없어 토큰을 임시 저장합니다.")
            hasPendingToken = true
            pendingToken = token
            return
        }
        
        // 서버에 보낼 데이터 준비
        let parameters: [String: Any] = [
            "user_id": userId, // 실제 사용자 ID 사용
            "device_token": token,
            "token_type": "voip"
        ]
        
        // 서버 요청 생성
        guard let url = URL(string: "\(serverURL)/register-token") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            print("JSON 직렬화 오류: \(error.localizedDescription)")
            return
        }
        
        print("CallManager: 사용자 ID \(userId)로 VoIP 토큰 등록 요청")
        
        // 서버 요청 전송
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("토큰 등록 오류: \(error.localizedDescription)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("유효하지 않은 응답")
                return
            }
            
            if httpResponse.statusCode == 200 {
                print("VoIP 푸시 토큰이 성공적으로 등록되었습니다.")
            } else {
                print("서버 오류: 상태 코드 \(httpResponse.statusCode)")
            }
        }
        
        task.resume()
    }
    
    // MARK: - CXProviderDelegate
    
    func providerDidReset(_ provider: CXProvider) {
        // 제공자가 재설정되었을 때 호출됨
        // 원복: 상태 초기화 유지, 연결 종료는 endCall에서 처리하므로 제거
        isCallActive = false
        shouldShowCallScreen = false
        isCallInProgress = false
        // RealtimeAIConnection.shared.disconnect() 제거
        print("CallManager: Provider 리셋됨, 상태 초기화")
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        // 사용자가 전화를 받았을 때
        isCallActive = true
        shouldShowCallScreen = true
        isCallInProgress = true
        
        // 메인 스레드에서 UI 업데이트 확보
        DispatchQueue.main.async {
            self.navigateToCallScreen()
        }
        
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        // 사용자가 전화를 종료했을 때 (또는 시스템에 의해 종료될 때)
        // *** 로그 추가 ***
        print("CallManager: provider(_:perform: CXEndCallAction) called for UUID: \(action.callUUID)")
        action.fulfill()
    }
    
    // 통화가 활성화될 때 (오디오 세션 관련)
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        // 오디오 세션이 활성화되었을 때
        print("CallManager: CXProvider가 오디오 세션 활성화를 요청함")
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            print("CallManager: AVAudioSession 활성화 성공")
        } catch {
            print("CallManager: AVAudioSession 활성화 오류: \(error.localizedDescription)")
        }
    }
    
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        // 오디오 세션이 비활성화되었을 때
        print("CallManager: CXProvider가 오디오 세션 비활성화를 요청함")
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            print("CallManager: AVAudioSession 비활성화 성공")
        } catch {
            print("CallManager: AVAudioSession 비활성화 오류: \(error.localizedDescription)")
        }
        // 원복: AI 연결 종료 로직 제거 (endCall completion에서 처리)
    }
    
    // 사용자가 통화를 거부했을 때 (통화 UI에서 "거부" 버튼을 누른 경우)
    // CXRejectCallAction은 존재하지 않으므로 대신 didRejectIncomingCall을 사용
    func provider(_ provider: CXProvider, didReject callUUID: UUID) {
        print("통화 거부됨")
        isCallActive = false
        shouldShowCallScreen = false
        isCallInProgress = false  // 상태 초기화
    }
    
    // 오류 초기화 메서드
    func resetCallError() {
        DispatchQueue.main.async {
            self.callError = nil
        }
    }
    
    // 통화 상태 리셋 메서드 수정
    func resetCallStatus() {
        // 통화 관련 상태 초기화 (통화 종료시에만 호출되도록)
        if isCallActive {
            isCallActive = false
            shouldShowCallScreen = false
            isCallInProgress = false
            
            // AI 연결 확실히 종료
            if RealtimeAIConnection.shared.isConnected {
                RealtimeAIConnection.shared.disconnect()
            }
            
            // 다음 통화를 위해 UI 상태 정리
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("CleanupCallScreen"), object: nil)
            }
        }
    }
    
    // navigateToCallScreen 메서드 수정
    private func navigateToCallScreen() {
        // 항상 통화 화면을 표시하도록 설정
        shouldShowCallScreen = true
        
        // 새로운 프레젠테이션 ID 생성 (화면 갱신 트리거)
        callScreenPresentationID = UUID()
        
        // NotificationCenter를 통해 앱 내에서 통화 화면 전환 알림
        NotificationCenter.default.post(name: NSNotification.Name("ShowCallScreen"), object: nil)
        print("통화 화면으로 이동 요청됨")
    }
    
    // MARK: - PKPushRegistryDelegate
    
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        // VoIP 푸시 토큰을 서버에 등록
        if type == .voIP {
            let token = pushCredentials.token.map { String(format: "%02.2hhx", $0) }.joined()
            print("VoIP 푸시 토큰: \(token)")
            // 여기서 토큰을 서버에 전송
            sendTokenToServer(token)
        }
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        // VoIP 푸시 알림 수신
        if type == .voIP {
            // 페이로드에서 필요한 정보 추출
            guard let uuidString = payload.dictionaryPayload["uuid"] as? String,
                  let uuid = UUID(uuidString: uuidString),
                  let handle = payload.dictionaryPayload["handle"] as? String else {
                completion()
                return
            }
            
            // 수신 전화 표시
            reportIncomingCall(uuid: uuid, handle: handle) { success in
                if success {
                    print("수신 전화 표시 성공")
                } else {
                    print("수신 전화 표시 실패")
                }
                completion()
            }
        }
    }
}