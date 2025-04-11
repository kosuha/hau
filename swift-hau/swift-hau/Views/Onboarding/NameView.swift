//
//  NameView.swift
//  swift-hau
//
//  Created by Seonho Kim on 4/11/25.
//

import SwiftUI

struct NameView: View {
    @EnvironmentObject var userViewModel: UserViewModel
    @State private var name: String = ""
    var onNext: () -> Void
    
    // 초기화
    init(onNext: @escaping () -> Void) {
        self.onNext = onNext
        // UserDefaults에서 저장된 이름을 가져오기
        if let savedName = UserDefaults.standard.string(forKey: "userName") {
            _name = State(initialValue: savedName)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HeaderView()
            
            // 콘텐츠
            VStack(spacing: 16) {
                // 상단 진행 바
                VStack(spacing: 0) {
                    ZStack(alignment: .leading) {
                        // 배경 바
                        Rectangle()
                            .frame(height: 6)
                            .foregroundColor(AppTheme.Colors.secondaryLight)
                            .cornerRadius(999)
                        
                        // 진행 바 (33.33%)
                        Rectangle()
                            .frame(width: UIScreen.main.bounds.width * 0.3333, height: 6)
                            .foregroundColor(AppTheme.Colors.secondary)
                            .cornerRadius(999)
                    }
                }
                
                // 제목 및 설명
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("만나서 반가워요.")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(AppTheme.Colors.dark)
                        
                        Text("이름이 어떻게 되나요?")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(AppTheme.Colors.dark)
                    }
                    .padding(.top, 36)
                    
                    Text("적어주신 이름으로 불러드려요.")
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.Colors.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // 이름 입력 필드
                TextField("이름 입력 (최대 12자)", text: $name)
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.Colors.dark)
                    .padding(.horizontal, 16)
                    .frame(height: 59)
                    .background(Color.white)
                    .cornerRadius(999)
                    .overlay(
                        RoundedRectangle(cornerRadius: 999)
                            .stroke(AppTheme.Colors.primary, lineWidth: 1)
                    )
                    .padding(.top, 40)
                    .onChange(of: name) { oldValue, newValue in
                        // 최대 12자로 제한
                        if newValue.count > 12 {
                            name = String(newValue.prefix(12))
                        }
                    }
                
                Spacer()
                
                // 다음 버튼
                Button(action: {
                    // 이름 저장
                    userViewModel.updateUserData(name: name)
                    
                    // 다음 화면으로 이동
                    onNext()
                }) {
                    Text("다음")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppTheme.Colors.light)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(AppTheme.Colors.primary)
                        .cornerRadius(999)
                }
                .padding(.bottom, 37)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)
            }
            .padding(.horizontal, 20)
        }
        .background(Color.white.edgesIgnoringSafeArea(.all))
        .navigationBarHidden(true)
        .onAppear {
            // 화면이 나타날 때 저장된 이름 불러오기
            if let savedName = userViewModel.userData.name {
                name = savedName
            }
        }
    }
}

// 미리보기
struct NameInputView_Previews: PreviewProvider {
    static var previews: some View {
        NameView(onNext: {})
            .environmentObject(UserViewModel())
    }
}
