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

struct CallView: View {
    @StateObject private var callManager = CallManager()
    
    var body: some View {
        VStack {
            Text("call 화면")
                .navigationBarTitle("call", displayMode: .inline)
            
            Button("수신 전화 시뮬레이션") {
                callManager.simulateIncomingCall()
            }
            
            if callManager.isCallActive {
                VStack(spacing: 20) {
                    Text("통화 중...")
                        .font(.title)
                        .foregroundColor(.green)
                    
                    Button("통화 종료") {
                        callManager.endCall()
                    }
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding()
            }
        }
        .onAppear {
            callManager.setupVoIP()
        }
    }
}

// CallKit과 PushKit을 관리하는 클래스
class CallManager: NSObject, ObservableObject, CXProviderDelegate, PKPushRegistryDelegate {
    @Published var isCallActive = false
    
    private let provider: CXProvider
    private let callController = CXCallController()
    private var pushRegistry: PKPushRegistry?
    private var uuid: UUID?
    
    override init() {
        // CallKit 제공자 설정
        let providerConfiguration = CXProviderConfiguration(localizedName: "앱 이름")
        providerConfiguration.supportsVideo = false
        providerConfiguration.maximumCallsPerCallGroup = 1
        providerConfiguration.supportedHandleTypes = [.phoneNumber]
        providerConfiguration.ringtoneSound = "ringtone.wav" // 앱 번들에 추가해야 함
        
        provider = CXProvider(configuration: providerConfiguration)
        
        super.init()
        
        provider.setDelegate(self, queue: nil)
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
    func reportIncomingCall(uuid: UUID, handle: String, hasVideo: Bool = false) {
        self.uuid = uuid
        
        // 통화 업데이트 설정
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .phoneNumber, value: handle)
        update.hasVideo = hasVideo
        update.localizedCallerName = "발신자 이름"
        
        // 수신 전화 표시
        provider.reportNewIncomingCall(with: uuid, update: update) { error in
            if let error = error {
                print("수신 전화 표시 오류: \(error.localizedDescription)")
            } else {
                self.isCallActive = true
            }
        }
    }
    
    // 통화 종료
    func endCall() {
        guard let uuid = uuid else { return }
        
        let endCallAction = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: endCallAction)
        
        callController.request(transaction) { error in
            if let error = error {
                print("통화 종료 오류: \(error.localizedDescription)")
            }
        }
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
            reportIncomingCall(uuid: uuid, handle: handle)
            completion()
        }
    }
}
