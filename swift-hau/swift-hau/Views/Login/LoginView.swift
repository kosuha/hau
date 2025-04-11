//
//  LoginView.swift
//  swift-hau
//
//  Created by Seonho Kim on 4/11/25.
//

import SwiftUI

struct LoginScreen: View {
    var body: some View {
        ZStack {
            AppTheme.Gradients.primary
                .ignoresSafeArea()
            
            VStack {
                Spacer(minLength: 70)
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("How are you?")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AppTheme.Colors.light)
                    
                    Text("오늘 당신의 하루는 어떤가요?")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(AppTheme.Colors.light)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 38)
                
                Spacer()
                
                VStack(spacing: 12) {
                    // Apple 로그인 버튼
                    Button(action: {
                        // Apple 로그인 처리
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 22))
                            
                            Text("Apple로 시작하기")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(AppTheme.Colors.light)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.black)
                        .cornerRadius(999)
                        .overlay(
                            RoundedRectangle(cornerRadius: 999)
                                .stroke(Color.black, lineWidth: 1)
                        )
                    }
                    
                    // Google 로그인 버튼
                    Button(action: {
                        // Google 로그인 처리
                    }) {
                        HStack(spacing: 6) {
                            GoogleLogo()
                                .frame(width: 22, height: 22)
                            
                            Text("Google로 시작하기")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(AppTheme.Colors.dark)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(AppTheme.Colors.light)
                        .cornerRadius(999)
                        .overlay(
                            RoundedRectangle(cornerRadius: 999)
                                .stroke(AppTheme.Colors.lightTransparent, lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer(minLength: 70)
            }
        }
    }
}

// Google 로고를 위한 커스텀 뷰
struct GoogleLogo: View {
    var body: some View {
        Image("google_logo") // 이미지 에셋으로 대체하는 것이 간단합니다
            .resizable()
            .aspectRatio(contentMode: .fit)
        
        // 또는 SF Symbols 사용
        // Image(systemName: "g.circle.fill")
        //     .resizable()
        //     .aspectRatio(contentMode: .fit)
    }
}

struct LoginScreen_Previews: PreviewProvider {
    static var previews: some View {
        LoginScreen()
    }
}
