import UIKit
import PushKit
import CallKit
import AVFoundation
import GoogleSignIn

class AppDelegate: NSObject, UIApplicationDelegate, PKPushRegistryDelegate {
    // CallManager 싱글톤 인스턴스 참조
    let callManager = CallManager.shared
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        print("AppDelegate: 앱이 시작되었습니다.")
        
        // 오디오 세션 설정
        configureAudioSession()
        
        return true
    }
    
    // 오디오 세션 설정 함수
    private func configureAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // 카테고리 및 모드 설정 (VoIP 통신에 적합하게)
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .duckOthers])
            try audioSession.setPreferredIOBufferDuration(0.005) // 낮은 버퍼 지연 설정 (선택 사항)
            try audioSession.setActive(false) // 시작 시 비활성화 상태 유지
            print("AppDelegate: 오디오 세션 설정 완료")
        } catch {
            print("AppDelegate: 오디오 세션 설정 오류: \(error.localizedDescription)")
        }
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
        
        // 이미 통화 중이면 새 푸시 무시
        if callManager.isCallInProgress {
            print("AppDelegate: 이미 통화 중이거나 알림이 진행 중입니다. 새 VoIP 푸시 무시")
            completion()
            return
        }
        
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
    
    // iOS 13 이상에서 VoIP 푸시 처리를 위한 메서드
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType) {
        print("AppDelegate: iOS 13+ VoIP 푸시 수신 (completion 없음)")
        
        // 이미 통화 중이면 새 푸시 무시
        if callManager.isCallInProgress {
            print("AppDelegate: 이미 통화 중이거나 알림이 진행 중입니다. 새 VoIP 푸시 무시")
            return
        }
        
        // VoIP 푸시 알림 처리 (iOS 13 이상)
        if type == .voIP {
            guard let uuidString = payload.dictionaryPayload["uuid"] as? String,
                  let uuid = UUID(uuidString: uuidString),
                  let handle = payload.dictionaryPayload["handle"] as? String else {
                print("AppDelegate: 푸시 페이로드에서 필요한 정보를 찾을 수 없습니다.")
                return
            }
            
            // iOS 13 이상에서는 반드시 이 메서드에서 CallKit을 보여줘야 함
            callManager.reportIncomingCall(uuid: uuid, handle: handle)
        }
    }
    
    // URL 스키마를 통한 앱 호출 처리 (구글 로그인 콜백)
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}