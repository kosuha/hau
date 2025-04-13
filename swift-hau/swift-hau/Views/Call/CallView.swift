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
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            if callManager.shouldShowCallScreen {
                VStack(spacing: 20) {
                    Text("통화 중...")
                        .font(.title)
                        .foregroundColor(.green)
                    
                    Button("통화 종료") {
                        callManager.endCall()
                        dismiss()
                    }
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding()
            } else {
                Text("통화 종료")
                Button("돌아가기") {
                    dismiss()
                }
            }
        }
        .navigationBarHidden(true)
    }
}

