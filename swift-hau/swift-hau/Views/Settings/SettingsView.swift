//
//  SettingsView.swift
//  swift-hau
//
//  Created by Seonho Kim on 4/11/25.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var coinViewModel: CoinViewModel
    @EnvironmentObject var purchaseViewModel: InAppPurchaseViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            // 헤더
            HeaderView(onPress: {
                presentationMode.wrappedValue.dismiss()
            })
            
            ScrollView {
                VStack(spacing: 40) {
                    // 멤버십 정보
                    NavigationLink(destination: PayView()
                        .environmentObject(coinViewModel)
                        .environmentObject(purchaseViewModel)
                    ) {
                        HStack {
                            AppTheme.Coin.coinIcon
                                .font(.system(size: 24))
                            Text("나의 코인")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.text)
                            
                            Spacer()
                            
                            Text(coinViewModel.formattedBalance())
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(AppTheme.Colors.text)
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 78)
                        .background(AppTheme.Colors.secondaryLight)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(AppTheme.Colors.secondary, lineWidth: 1)
                        )
                    }

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
                            SettingsItemView(title: "프라이빗 모드", destination: AnyView(PrivateSettingView()))
                            SettingsItemView(title: "대화 내역 초기화", destination: AnyView(ResetHistoryView()))
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
                            SettingsItemView(title: "문의하기", destination: AnyView(InquiryView()))
                            Link(destination: URL(string: "https://seonhoki.notion.site/HAU-1f58d444fd4880c488a1eb8ae7021b0d")!) {
                                HStack {
                                    Text("이용약관")
                                        .font(.system(size: 16))
                                        .foregroundColor(AppTheme.Colors.text)
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .foregroundColor(AppTheme.Colors.text)
                                }
                            }
                            Link(destination: URL(string: "https://seonhoki.notion.site/HAU-1f58d444fd4880bdba79dbabcf97a8d2")!) {
                                HStack {
                                    Text("개인정보처리방침")
                                        .font(.system(size: 16))
                                        .foregroundColor(AppTheme.Colors.text)
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .foregroundColor(AppTheme.Colors.text)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
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

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(CoinViewModel())
            .environmentObject(InAppPurchaseViewModel())
    }
}

