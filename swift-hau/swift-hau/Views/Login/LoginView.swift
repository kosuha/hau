//
//  LoginView.swift
//  swift-hau
//
//  Created by Seonho Kim on 4/11/25.
//

import SwiftUI
import AuthenticationServices
import GoogleSignIn

struct LoginScreen: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showingAlert = false
    
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
                
                VStack(spacing: 16) {
                    // 애플로 로그인 버튼
                    Button(action: {
                        authViewModel.signInWithApple()
                    }) {
                        HStack {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                            
                            Text("Apple로 로그인")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.black)
                        .cornerRadius(999)
                    }
                    
                    // Google 로그인 버튼
                    Button(action: {
                        authViewModel.signInWithGoogle()
                    }) {
                        HStack(spacing: 6) {
                            Image("google_logo") // 구글 로고 이미지 사용 또는 아래 커스텀 뷰 유지
                                .resizable()
                                .aspectRatio(contentMode: .fit)
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
            
            // 로딩 표시
            if authViewModel.isLoading {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(2)
            }
        }
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text("오류"),
                message: Text(authViewModel.errorMessage ?? "알 수 없는 오류가 발생했습니다."),
                dismissButton: .default(Text("확인"))
            )
        }
        .onChange(of: authViewModel.errorMessage) { newValue in
            if newValue != nil {
                showingAlert = true
            }
        }
    }
}

// Google 로고를 위한 커스텀 뷰 (필요시 사용)
struct GoogleLogo: View {
    var body: some View {        
        Image("google_logo")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 22, height: 22)
    }
}

struct LoginScreen_Previews: PreviewProvider {
    static var previews: some View {
        LoginScreen()
    }
}
