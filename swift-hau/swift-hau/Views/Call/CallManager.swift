import SwiftUI
import PushKit
import CallKit

// CallKit과 PushKit을 관리하는 클래스
class CallManager: NSObject, ObservableObject, CXProviderDelegate, PKPushRegistryDelegate {
    @Published var isCallActive = false
    
    // 싱글톤 인스턴스
    static let shared = CallManager()
    
    private let provider: CXProvider
    private let callController = CXCallController()
    private var pushRegistry: PKPushRegistry?
    private var uuid: UUID?
    
    // AI 정보
    private let aiName = "AI 어시스턴트"
    
    // 서버 API 엔드포인트
    private let serverURL = "http://192.168.0.5:3000/api/v1"
    
    override init() {
        // CallKit 제공자 설정
        let providerConfiguration = CXProviderConfiguration(localizedName: "앱 이름")
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
        self.uuid = uuid
        
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
                completion?(false)
                return
            }
            
            print("수신 전화 표시 성공")
            self.isCallActive = true
            completion?(true)
        }
    }
    
    // 통화 종료
    func endCall(with uuid: UUID) {
        let endCallAction = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: endCallAction)
        
        callController.request(transaction) { error in
            if let error = error {
                print("통화 종료 오류: \(error.localizedDescription)")
            } else {
                print("통화 종료 성공")
                self.isCallActive = false
            }
        }
    }
    
    // 기존 endCall 메서드 (현재 활성화된 통화 종료)
    func endCall() {
        guard let uuid = uuid else { return }
        endCall(with: uuid)
    }
    
    // 서버에 통화 푸시 알림 요청
    func requestCallPush(receiverID: String) {
        // 서버에 보낼 데이터 준비
        let parameters: [String: Any] = [
            "caller_id": "test_id",
            "receiver_id": receiverID,
            "caller_name": "test_id"
        ]
        
        // 서버 요청 생성
        guard let url = URL(string: "\(serverURL)/send-call-push") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            print("JSON 직렬화 오류: \(error.localizedDescription)")
            return
        }
        
        // 서버 요청 전송
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("서버 요청 오류: \(error.localizedDescription)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("유효하지 않은 응답")
                return
            }
            
            if httpResponse.statusCode == 200 {
                print("통화 푸시 요청이 성공적으로 전송되었습니다.")
                
                // 테스트를 위해 로컬에서 수신 전화 시뮬레이션
                // 실제로는 서버에서 푸시 알림을 보내고, 그 알림을 받아서 처리함
                if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let success = json["success"] as? Bool, success == true {
                    print("서버 응답: \(json)")
                }
            } else {
                print("서버 오류: 상태 코드 \(httpResponse.statusCode)")
                
                if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("서버 오류 응답: \(json)")
                }
            }
        }
        
        task.resume()
    }
    
    // 서버에 토큰 전송 (public으로 변경)
    func sendTokenToServer(_ token: String) {
        // 서버에 보낼 데이터 준비
        let parameters: [String: Any] = [
            "user_id": "test_id", // 실제 사용자 ID로 변경
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
        isCallActive = false
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        // 사용자가 전화를 받았을 때
        isCallActive = true
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        // 사용자가 전화를 종료했을 때
        isCallActive = false
        action.fulfill()
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