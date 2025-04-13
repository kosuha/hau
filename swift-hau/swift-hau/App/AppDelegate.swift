import UIKit
import PushKit
import CallKit

class AppDelegate: NSObject, UIApplicationDelegate, PKPushRegistryDelegate {
    // CallManager 싱글톤 인스턴스 참조
    let callManager = CallManager.shared
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        print("AppDelegate: 앱이 시작되었습니다.")
        
        // VoIP 푸시 등록
        registerForVoIPPushes()
        
        return true
    }
    
    // VoIP 푸시 등록
    func registerForVoIPPushes() {
        let voipRegistry = PKPushRegistry(queue: .main)
        voipRegistry.delegate = self
        voipRegistry.desiredPushTypes = [.voIP]
        
        print("AppDelegate: VoIP 푸시 등록 완료")
    }
    
    // MARK: - PKPushRegistryDelegate
    
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        // VoIP 푸시 토큰을 서버에 등록
        if type == .voIP {
            let token = pushCredentials.token.map { String(format: "%02.2hhx", $0) }.joined()
            print("AppDelegate: VoIP 푸시 토큰: \(token)")
            
            // 토큰을 서버에 등록
            callManager.sendTokenToServer(token)
        }
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        print("AppDelegate: VoIP 푸시 수신: \(payload.dictionaryPayload)")
        
        // VoIP 푸시 알림 수신
        if type == .voIP {
            // 페이로드에서 필요한 정보 추출
            guard let uuidString = payload.dictionaryPayload["uuid"] as? String,
                  let uuid = UUID(uuidString: uuidString),
                  let handle = payload.dictionaryPayload["handle"] as? String else {
                print("AppDelegate: 푸시 페이로드에서 필요한 정보를 찾을 수 없습니다.")
                completion()
                return
            }
            
            // 수신 전화 표시
            print("AppDelegate: 통화 UI 표시 시도")
            callManager.reportIncomingCall(uuid: uuid, handle: handle)
            completion()
        }
    }
}