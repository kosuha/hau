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
    @StateObject private var callManager = CallManager.shared
    
    var body: some View {
        VStack {
            Text("call 화면")
                .navigationBarTitle("call", displayMode: .inline)
            
            Button("수신 전화 시뮬레이션") {
                callManager.simulateIncomingCall()
            }

            Button("수신 전화 요청") {
                callManager.requestCallPush(receiverID: "test_id")
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
    }
}

