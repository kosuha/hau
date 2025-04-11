//
//  CallTimeSettingScreen.swift
//  swift-hau
//
//  Created by Seonho Kim on 4/11/25.
//

import SwiftUI

struct CallTimeSettingView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedTime: Date = Date()
    @State private var isTimePickerVisible: Bool = false
    @State private var isCustomTimeSelected: Bool = false
    
    // 미리 정의된 시간 옵션
    private let predefinedTimes = [
        "아침 (8:00 AM)",
        "점심 (12:00 PM)",
        "저녁 (7:00 PM)",
        "취침 전 (10:00 PM)",
        "직접 설정"
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            // 헤더
            HeaderView(
                onPress: { dismiss() },
                title: "통화 시간 설정"
            )
            
            ScrollView {
                VStack(spacing: 24) {
                    // 설명 텍스트
                    Text("하루 중 언제 통화하고 싶으신가요?")
                        .font(.system(size: 16))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                    
                    // 시간 옵션 목록
                    VStack(spacing: 12) {
                        ForEach(predefinedTimes, id: \.self) { timeOption in
                            TimeOptionButton(
                                title: timeOption,
                                isSelected: isCustomTimeSelected ? false : (timeOption == predefinedTimes.last ? isCustomTimeSelected : false),
                                action: {
                                    if timeOption == "직접 설정" {
                                        isCustomTimeSelected = true
                                        isTimePickerVisible = true
                                    } else {
                                        isCustomTimeSelected = false
                                        // 선택된 시간 옵션에 따라 시간 설정
                                        setTimeFromOption(timeOption)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // 커스텀 시간 선택기
                    if isCustomTimeSelected {
                        VStack {
                            Text("시간 선택")
                                .font(.system(size: 16, weight: .bold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            DatePicker(
                                "",
                                selection: $selectedTime,
                                displayedComponents: .hourAndMinute
                            )
                            .datePickerStyle(WheelDatePickerStyle())
                            .labelsHidden()
                        }
                        .padding(.horizontal, 20)
                        .transition(.opacity)
                    }
                    
                    Spacer()
                    
                    // 저장 버튼
                    Button(action: {
                        saveCallTime()
                        dismiss()
                    }) {
                        Text("저장")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(AppTheme.Colors.primary)
                            .cornerRadius(999)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .background(Color.white.edgesIgnoringSafeArea(.all))
        .navigationBarHidden(true)
    }
    
    // 선택된 옵션에 따라 시간 설정
    private func setTimeFromOption(_ option: String) {
        var components = DateComponents()
        components.calendar = Calendar.current
        
        switch option {
        case "아침 (8:00 AM)":
            components.hour = 8
            components.minute = 0
        case "점심 (12:00 PM)":
            components.hour = 12
            components.minute = 0
        case "저녁 (7:00 PM)":
            components.hour = 19
            components.minute = 0
        case "취침 전 (10:00 PM)":
            components.hour = 22
            components.minute = 0
        default:
            return
        }
        
        if let date = components.calendar?.date(from: components) {
            selectedTime = date
        }
    }
    
    // 통화 시간 저장
    private func saveCallTime() {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let timeString = formatter.string(from: selectedTime)
        
        // 여기서 UserDefaults나 다른 저장소에 시간 저장
        UserDefaults.standard.set(timeString, forKey: "callTime")
        print("통화 시간이 저장되었습니다: \(timeString)")
        
        // 실제 앱에서는 ViewModel을 통해 저장할 수 있음
        // userViewModel.updateUserData(callTime: timeString)
    }
}

// 시간 옵션 버튼 컴포넌트
struct TimeOptionButton: View {
    var title: String
    var isSelected: Bool
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.Colors.text)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isSelected ? AppTheme.Colors.primary : AppTheme.Colors.placeholder,
                        lineWidth: 1
                    )
            )
        }
    }
}
