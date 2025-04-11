//
//  MainView.swift
//  swift-hau
//
//  Created by Seonho Kim on 4/11/25.
//

import SwiftUI

struct MainView: View {
    @EnvironmentObject var userViewModel: UserViewModel
    @State private var navigationPath = NavigationPath()
    
    enum Destination: Hashable {
        case settings
        case call
        case callTimeSetting
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                AppTheme.Gradients.primary
                    .ignoresSafeArea()
                
                VStack {
                    // 헤더
                    HStack {
                        Spacer()
                        Button(action: { navigationPath.append(Destination.settings) }) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 20)
                    }
                    .frame(height: UIScreen.main.bounds.height * 0.1)
                    
                    // 콘텐츠
                    VStack(alignment: .leading, spacing: 0) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("\(userViewModel.userData.name ?? "주야")님,")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("좋은 아침이에요!")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.bottom, 43)
                        
                        // 알림 박스
                        Button(action: { navigationPath.append(Destination.callTimeSetting) }) {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(AppTheme.Colors.light)
                                        .frame(width: 44, height: 44)
                                    
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(AppTheme.Colors.tertiary)
                                }
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("언제 통화할까요?")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(AppTheme.Colors.dark)
                                    
                                    Text("원하는 시간을 알려주세요.")
                                        .font(.system(size: 16))
                                        .foregroundColor(AppTheme.Colors.dark)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 22)
                            .padding(.vertical, 17)
                            .background(AppTheme.Colors.lightTransparent)
                            .cornerRadius(16)
                        }
                        
                        Spacer()
                        
                        // 통화 버튼
                        Button(action: { navigationPath.append(Destination.call) }) {
                            HStack(spacing: 10) {
                                Image(systemName: "phone.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(AppTheme.Colors.accent)
                                
                                Text("지금 통화하기")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(AppTheme.Colors.dark)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 70)
                            .padding(.vertical, 16)
                            .background(AppTheme.Colors.light)
                            .cornerRadius(999)
                            .overlay(
                                RoundedRectangle(cornerRadius: 999)
                                    .stroke(AppTheme.Colors.light, lineWidth: 1)
                            )
                        }
                        .padding(.bottom, 57)
                    }
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: Destination.self) { destination in
                switch destination {
                case .settings:
                    SettingsView()
                case .call:
                    CallView()
                case .callTimeSetting:
                    CallTimeSettingView()
                }
            }
        }
        
    }
}
