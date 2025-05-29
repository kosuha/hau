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
                title: "프라이빗 모드 설정",
                isRightButton: false
            )
            
            // 콘텐츠
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 50) {
                        // 설명 텍스트
                        Text("프라이빗 모드를 활성화하면 통화 내용이 저장되지 않습니다.")
                            .font(.system(size: 16, weight: .medium))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // 프라이빗 모드 토글
                        HStack(spacing: 15) {
                            Image(systemName: callManager.isPrivateMode ? "lock.fill" : "lock.open.fill")
                                .font(.system(size: 24))
                                .foregroundColor(callManager.isPrivateMode ? AppTheme.Colors.accent : AppTheme.Colors.disabled)
                                .frame(width: 24, height: 24)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("프라이빗 모드")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(AppTheme.Colors.dark)
                                
                                Text("통화 내용을 저장하지 않습니다")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppTheme.Colors.disabled)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $callManager.isPrivateMode)
                                .labelsHidden()
                                .toggleStyle(SwitchToggleStyle(tint: AppTheme.Colors.accent))
                        }
                        .padding(20)
                        .background(Color.white)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(callManager.isPrivateMode ? AppTheme.Colors.accent : AppTheme.Colors.disabled, lineWidth: 1)
                        )
                        
                        // 추가 설명
                        if callManager.isPrivateMode {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 10) {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundColor(AppTheme.Colors.accent)
                                    Text("프라이빗 모드 활성화 상태")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(AppTheme.Colors.dark)
                                }
                                
                                Text("• 통화 내용이 하우의 서버와 데이터베이스에 저장되지 않습니다.")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppTheme.Colors.dark)
                                
                                Text("• AI 친구가 프라이빗 모드 상태의 통화 내용을 기억하지 못합니다.")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppTheme.Colors.dark)
                                
                            }
                            .padding(20)
                            .background(AppTheme.Colors.lightTransparent)
                            .cornerRadius(16)
                        }
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

