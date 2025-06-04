//
//  PrivateSettingView.swift
//  swift-hau
//
//  Created by Seonho Kim on 4/11/25.
//

import SwiftUI
import AVFoundation

struct PrivateSettingView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var callManager = CallManager.shared
    @State private var showSaveCompleteAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HeaderView(
                onPress: {
                    dismiss()
                },
                title: "프라이빗 모드",
                isRightButton: false
            )
            
            // 콘텐츠
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 50) {
                        // 프라이빗 모드 토글
                        HStack(spacing: 15) {
                            Image(systemName: callManager.isPrivateMode ? "lock.fill" : "lock.open.fill")
                                .font(.system(size: 24))
                                .foregroundColor(callManager.isPrivateMode ? AppTheme.Colors.secondary : AppTheme.Colors.disabled)
                                .frame(width: 24, height: 24)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("프라이빗 모드")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(AppTheme.Colors.dark)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $callManager.isPrivateMode)
                                .labelsHidden()
                                .toggleStyle(SwitchToggleStyle(tint: AppTheme.Colors.secondary))
                        }
                        .padding(20)
                        .background(Color.white)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(callManager.isPrivateMode ? AppTheme.Colors.secondary : AppTheme.Colors.disabled, lineWidth: 1)
                        )
                        
                        // 추가 설명
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                Text("프라이빗 모드를 활성화하면 어떻게 되나요?")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(AppTheme.Colors.dark)
                            }
                            
                            HStack(spacing: 10) {
                                Text("•")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(AppTheme.Colors.dark)
                                Text("통화 내용이 하우의 서버에 저장되지 않아요.")
                                    .font(.system(size: 16))
                                    .foregroundColor(AppTheme.Colors.dark)
                            }
                            HStack(spacing: 10) {
                                Text("•")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(AppTheme.Colors.dark)
                                Text("AI 친구가 프라이빗 모드 상태의 통화 내용을 기억하지 못해요.")
                                    .font(.system(size: 16))
                                    .foregroundColor(AppTheme.Colors.dark)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
                
                Spacer()
            }
            .padding(.top, 16)
        }
        .background(Color.white.edgesIgnoringSafeArea(.all))
        .navigationBarHidden(true)
        .alert("저장 완료", isPresented: $showSaveCompleteAlert) {
            Button("확인", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("프라이빗 모드 설정이 성공적으로 저장되었습니다.")
        }
    }
}

// 프리뷰
struct PrivateSettingView_Previews: PreviewProvider {
    static var previews: some View {
        PrivateSettingView()
    }
}

