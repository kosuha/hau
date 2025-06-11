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
                            if authViewModel.isLoading {
                                CircularLoadingView(color: .white)
                            } else {
                                Image(systemName: "apple.logo")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                                
                                Text("Apple로 로그인")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.black)
                        .cornerRadius(999)
                    }
                    .disabled(authViewModel.isLoading)
                    
                    // Google 로그인 버튼
                    Button(action: {
                        authViewModel.signInWithGoogle()
                    }) {
                        HStack(spacing: 6) {
                            if authViewModel.isLoading {
                                CircularLoadingView(color: AppTheme.Colors.dark)
                            } else {
                                Text("Google로 시작하기")
                                    .font(.system(size: 16, weight: .bold))
                            }
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
                    .disabled(authViewModel.isLoading)
                }
                .padding(.horizontal, 20)
                
                Spacer(minLength: 70)
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

// 커스텀 원형 로딩 아이콘
struct CircularLoadingView: View {
    let color: Color
    @State private var isAnimating = false
    
    var body: some View {
        Circle()
            .trim(from: 0.0, to: 0.7)
            .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            .frame(width: 24, height: 24)
            .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
            .animation(Animation.linear(duration: 1).repeatForever(autoreverses: false), value: isAnimating)
            .onAppear {
                isAnimating = true
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
