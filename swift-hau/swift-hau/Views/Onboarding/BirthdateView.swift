//
//  BirthdayView.swift
//  swift-hau
//
//  Created by Seonho Kim on 4/11/25.
//

import SwiftUI

struct BirthdateView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var userViewModel: UserViewModel
    @State private var selectedDate: Date
    var onNext: () -> Void
    var onBack: () -> Void
    
    // 초기화
    init(onNext: @escaping () -> Void, onBack: @escaping () -> Void) {
        self.onNext = onNext
        self.onBack = onBack
        // UserDefaults에서 저장된 생년월일을 가져오거나 현재 날짜 사용
        if let savedDate = UserDefaults.standard.object(forKey: "userBirthdate") as? Date {
            _selectedDate = State(initialValue: savedDate)
        } else {
            _selectedDate = State(initialValue: Date())
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HeaderView(onPress: { dismiss() })
            
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
                        
                        // 진행 바
                        Rectangle()
                            .frame(width: UIScreen.main.bounds.width * 0.6667, height: 6)
                            .foregroundColor(AppTheme.Colors.secondary)
                            .cornerRadius(999)
                    }
                }
                
                // 제목 및 설명
                VStack(alignment: .leading, spacing: 8) {
                    Text("생년월일을 알려주세요.")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(AppTheme.Colors.dark)
                        .padding(.top, 36)
                    
                    Text("더 진솔한 대화를 위해 필요해요.")
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.Colors.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // 날짜 선택기
                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(WheelDatePickerStyle())
                    .labelsHidden()
                    .padding(.top, 20)
                    .environment(\.locale, Locale(identifier: "ko_KR"))
                
                Spacer()
                
                // 다음 버튼
                Button(action: {
                    // 생년월일 저장
                    userViewModel.updateUserData(birthdate: selectedDate)
                    
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
            }
            .padding(.horizontal, 20)
        }
        .background(Color.white.edgesIgnoringSafeArea(.all))
        .navigationBarHidden(true)
    }
}

// 미리보기
struct BirthdateInputView_Previews: PreviewProvider {
    static var previews: some View {
        BirthdateView(onNext: {}, onBack: {})
            .environmentObject(UserViewModel())
    }
}
