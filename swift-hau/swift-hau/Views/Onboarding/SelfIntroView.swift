//
//  SelfIntro.swift
//  swift-hau
//
//  Created by Seonho Kim on 4/11/25.
//

import SwiftUI

struct SelfIntroView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var userViewModel: UserViewModel
    @State private var text: String = ""
    private let maxLength = 2000
    var onNext: () -> Void
    var onBack: () -> Void

    // 초기화
    init(onNext: @escaping () -> Void, onBack: @escaping () -> Void) {
        self.onNext = onNext
        self.onBack = onBack
        // UserDefaults에서 저장된 자기 소개를 가져오기
        if let savedStory = UserDefaults.standard.string(forKey: "userSelfStory") {
            _text = State(initialValue: savedStory)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HeaderView(onPress: { dismiss() })
            
            // 콘텐츠
            ScrollView {
                VStack(spacing: 0) {
                    // 상단 진행 바
                    ZStack(alignment: .leading) {
                        // 배경 바
                        Rectangle()
                            .frame(height: 6)
                            .foregroundColor(AppTheme.Colors.secondaryLight)
                            .cornerRadius(999)
                        
                        // 진행 바 (100%)
                        Rectangle()
                            .frame(height: 6)
                            .foregroundColor(AppTheme.Colors.secondary)
                            .cornerRadius(999)
                    }
                    
                    // 제목 및 설명
                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("함께 나누고싶은")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(AppTheme.Colors.dark)
                            
                            Text("나의 이야기를 적어주세요.")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(AppTheme.Colors.dark)
                        }
                        .padding(.top, 36)
                        
                        Text("함께 더 많은 이야기를 할 수 있어요.")
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.Colors.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 24)
                    
                    // 자기 소개 입력 영역
                    ZStack(alignment: .bottomTrailing) {
                        TextEditor(text: $text)
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.Colors.dark)
                            .frame(minHeight: 200)
                            .padding(.bottom, 24) // 글자 수 카운터를 위한 여백
                            .onChange(of: text) { oldValue, newValue in
                                // 최대 글자 수 제한
                                if newValue.count > maxLength {
                                    text = String(newValue.prefix(maxLength))
                                }
                            }
                        
                        // 글자 수 카운터
                        Text("\(text.count)/\(maxLength)")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Colors.secondary)
                            .padding(.bottom, 8)
                            .padding(.trailing, 8)
                    }
                    .padding(20)
                    .background(Color.white)
                    .cornerRadius(28)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(AppTheme.Colors.primary, lineWidth: 1)
                    )
                    
                    Spacer()
                    
                    // 시작하기 버튼
                    Button(action: {
                        // 자기 소개 저장
                        userViewModel.updateUserData(selfStory: text)
                        
                        // 권한 요청 화면으로 이동
                        // 여기서는 네비게이션 스택을 사용한다고 가정
                        // 실제 구현에서는 네비게이션 방식에 맞게 수정 필요
                    }) {
                        Text("시작하기")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(AppTheme.Colors.light)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(AppTheme.Colors.primary)
                            .cornerRadius(999)
                    }
                    .padding(.vertical, 37)
                }
                .padding(.horizontal, 20)
            }
        }
        .background(Color.white.edgesIgnoringSafeArea(.all))
        .navigationBarHidden(true)
        .onAppear {
            // 화면이 나타날 때 저장된 자기 소개 불러오기
            if let savedStory = userViewModel.userData.selfIntro {
                text = savedStory
            }
        }
    }
}

// 미리보기
struct SelfStoryView_Previews: PreviewProvider {
    static var previews: some View {
        SelfIntroView(onNext: {}, onBack: {})
            .environmentObject(UserViewModel())
    }
}
