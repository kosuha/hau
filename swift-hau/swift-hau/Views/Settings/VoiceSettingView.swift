//
//  VoiceSettingView.swift
//  swift-hau
//
//  Created by Seonho Kim on 4/11/25.
//

import SwiftUI

struct VoiceSettingView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var userViewModel: UserViewModel
    @State private var showDiscardAlert = false
    @State private var showSaveCompleteAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HeaderView(
                onPress: {
                    // 변경 사항이 있으면 경고 표시
                    if userViewModel.isVoiceModified {
                        showDiscardAlert = true
                    } else {
                        dismiss()
                    }
                },
                title: "목소리 설정"
            )
            
            // 콘텐츠
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 50) {
                        // 설명 텍스트
                        Text("원하는 목소리로 통화할 수 있어요.")
                            .font(.system(size: 16, weight: .medium))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // 목소리 옵션
                        VStack(spacing: 20) {
                            // 범수 목소리 옵션
                            VoiceOptionButton(
                                title: "범수",
                                description: "자상하고 차분한 남자 목소리",
                                isSelected: userViewModel.selectedVoice == "Beomsoo",
                                action: { userViewModel.selectedVoice = "Beomsoo" }
                            )
                            
                            // 진주 목소리 옵션
                            VoiceOptionButton(
                                title: "진주",
                                description: "친절하고 밝은 여자 목소리",
                                isSelected: userViewModel.selectedVoice == "Jinjoo",
                                action: { userViewModel.selectedVoice = "Jinjoo" }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
                
                Spacer()
                
                // 저장 버튼
                Button(action: {
                    userViewModel.silentlySaveVoiceSetting()
                    userViewModel.silentlySaveProfile()
                    showSaveCompleteAlert = true
                }) {
                    Text("저장하기")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppTheme.Colors.light)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(AppTheme.Colors.primary)
                        .cornerRadius(999)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 37)
            }
            .padding(.top, 16)
        }
        .background(Color.white.edgesIgnoringSafeArea(.all))
        .navigationBarHidden(true)
        .alert("주의", isPresented: $showDiscardAlert) {
            Button("취소", role: .cancel) { }
            Button("나가기", role: .destructive) {
                userViewModel.cancelVoiceEditing()
                dismiss()
            }
        } message: {
            Text("저장하지 않은 내용은 사라집니다.")
        }
        .alert("저장 완료", isPresented: $showSaveCompleteAlert) {
            Button("확인", role: .cancel) { }
        } message: {
            Text("목소리 설정이 성공적으로 저장되었습니다.")
        }
        .onAppear {
            userViewModel.beginVoiceEditing()
        }
    }
}

// 목소리 옵션 버튼 컴포넌트
struct VoiceOptionButton: View {
    let title: String
    let description: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 20) {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(isSelected ? AppTheme.Colors.dark : AppTheme.Colors.disabled)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? AppTheme.Colors.dark : AppTheme.Colors.disabled)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 130)
            .padding(20)
            .background(Color.white)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.disabled, lineWidth: 1)
            )
        }
    }
}
