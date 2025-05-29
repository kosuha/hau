//
//  VoiceSettingView.swift
//  swift-hau
//
//  Created by Seonho Kim on 4/11/25.
//

import SwiftUI
import AVFoundation

struct VoiceSettingView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var userViewModel: UserViewModel
    @State private var showDiscardAlert = false
    @State private var showSaveCompleteAlert = false
    @State private var audioPlayer: AVAudioPlayer?
    
    // 목소리 옵션 배열
    private let voiceOptions = [
        VoiceOption(id: "ash", title: "ash", description: "맑고 또렷하며 정확한 톤"),
        VoiceOption(id: "alloy", title: "alloy", description: "중성적이고 균형 잡힌 톤"),
        VoiceOption(id: "ballad", title: "ballad", description: "서정적이고 부드러운 톤"),
        VoiceOption(id: "coral", title: "coral", description: "따뜻하고 친근한 톤"),
        VoiceOption(id: "echo", title: "echo", description: "공명감이 느껴지는 깊은 톤"),
        VoiceOption(id: "sage", title: "sage", description: "차분하고 사려 깊은 톤"),
        VoiceOption(id: "shimmer", title: "shimmer", description: "밝고 에너지 넘치는 톤"),
        VoiceOption(id: "verse", title: "verse", description: "다재다능하고 표현력이 풍부한 톤"),
    ]
    
    // 음성 샘플 재생 함수
    private func playVoiceSample() {
        guard let url = Bundle.main.url(forResource: userViewModel.selectedVoice, withExtension: "wav") else {
            print("음성 파일을 찾을 수 없습니다: \(userViewModel.selectedVoice).wav")
            return
        }
        
        do {
            audioPlayer?.stop()
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {
            print("음성 파일 재생 오류: \(error.localizedDescription)")
        }
    }
    
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
                title: "목소리 설정",
                isRightButton: true,
                rightButtonImage: "play.circle.fill",
                rightButtonAction: {
                    playVoiceSample()
                }
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
                            ForEach(voiceOptions) { option in
                                VoiceOptionButton(
                                    title: option.title,
                                    description: option.description,
                                    isSelected: userViewModel.selectedVoice == option.id,
                                    action: { userViewModel.selectedVoice = option.id }
                                )
                            }
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
                .padding(.bottom, 20)
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

// 목소리 옵션 모델
struct VoiceOption: Identifiable {
    let id: String
    let title: String
    let description: String
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
            .frame(height: 80)
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

