//
//  SettingsView.swift
//  swift-hau
//
//  Created by Seonho Kim on 4/11/25.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 16) {
            // 헤더
            HeaderView(onPress: {
                presentationMode.wrappedValue.dismiss()
            })
            
            ScrollView {
                VStack(spacing: 40) {
                    // 멤버십 정보
                    HStack {
                        Text("나의 멤버십")
                            .font(.system(size: 16))
                        
                        Spacer()
                        
                        Text("무료")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .padding(.horizontal, 20)
                    .frame(height: 78)
                    .background(AppTheme.Colors.secondaryLight)
                    .cornerRadius(16)
                    
                    // 설정 섹션
                    VStack(spacing: 16) {
                        // 섹션 헤더
                        VStack(spacing: 16) {
                            HStack {
                                Text("설정")
                                    .font(.system(size: 18, weight: .bold))
                                Spacer()
                            }
                            
                            Divider()
                                .background(AppTheme.Colors.text)
                        }
                        
                        // 설정 메뉴 아이템
                        VStack(spacing: 24) {
                            SettingsItemView(title: "프로필", destination: AnyView(ProfileView()))
                            SettingsItemView(title: "통화 시간 설정", destination: AnyView(CallTimeSettingView()))
                            SettingsItemView(title: "목소리 설정", destination: AnyView(VoiceSettingView()))
                        }
                    }
                    
                    // 기타 섹션
                    VStack(spacing: 16) {
                        // 섹션 헤더
                        VStack(spacing: 16) {
                            HStack {
                                Text("기타")
                                    .font(.system(size: 18, weight: .bold))
                                Spacer()
                            }
                            
                            Divider()
                                .background(AppTheme.Colors.text)
                        }
                        
                        // 기타 메뉴 아이템
                        VStack(spacing: 24) {
                            SettingsItemView(title: "오픈소스 라이브러리", destination: AnyView(OpenSourceView()))
                            SettingsItemView(title: "문의하기", destination: AnyView(InquiryView()))
                            SettingsItemView(title: "이용약관", destination: AnyView(TermsOfServiceView()))
                            SettingsItemView(title: "개인정보처리방침", destination: AnyView(PrivacyPolicyView()))
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .navigationBarHidden(true)
        .background(Color.white.edgesIgnoringSafeArea(.all))
    }
}

// 설정 항목 컴포넌트
struct SettingsItemView: View {
    var title: String
    var destination: AnyView
    
    var body: some View {
        NavigationLink(destination: destination) {
            HStack {
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.Colors.text)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(AppTheme.Colors.text)
            }
        }
    }
}
