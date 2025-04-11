//
//  ProfileView.swift
//  swift-hau
//
//  Created by Seonho Kim on 4/11/25.
//

import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = ProfileViewModel()
    
    @State private var showDatePicker = false
    @State private var showDiscardAlert = false
    
    var body: some View {
        VStack(spacing: 16) {
            // 헤더
            HeaderView(
                onPress: {
                    // 변경 사항이 있으면 경고 표시
                    if viewModel.isModified {
                        showDiscardAlert = true
                    } else {
                        dismiss()
                    }
                },
                title: "프로필"
            )
            
            ScrollView {
                VStack(spacing: 34) {
                    // 이름 입력
                    VStack(alignment: .leading, spacing: 8) {
                        Text("이름")
                            .font(.system(size: 16, weight: .medium))
                        
                        TextField("이름을 입력하세요", text: $viewModel.name)
                            .padding(.horizontal, 20)
                            .frame(height: 50)
                            .background(Color.white)
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.gray, lineWidth: 1)
                            )
                    }
                    
                    // 생년월일 선택
                    VStack(alignment: .leading, spacing: 8) {
                        Text("생년월일")
                            .font(.system(size: 16, weight: .medium))
                        
                        Button(action: {
                            showDatePicker = true
                        }) {
                            HStack {
                                Text(viewModel.formattedBirthdate)
                                    .font(.system(size: 16))
                                    .foregroundColor(AppTheme.Colors.text)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .frame(height: 50)
                            .background(Color.white)
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.gray, lineWidth: 1)
                            )
                        }
                    }
                    
                    // 나의 이야기 입력
                    VStack(alignment: .leading, spacing: 8) {
                        Text("나의 이야기")
                            .font(.system(size: 16, weight: .medium))
                        
                        Text("나의 이야기는 통화할 때 항상 기억하고 있어요.")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.Colors.secondary)
                        
                        ZStack(alignment: .bottomTrailing) {
                            TextEditor(text: $viewModel.selfStory)
                                .padding(20)
                                .frame(height: 300)
                                .background(Color.white)
                                .cornerRadius(14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.gray, lineWidth: 1)
                                )
                            
                            // 글자 수 표시
                            Text("\(viewModel.selfStory.count)/\(viewModel.maxLength)")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.Colors.disabled)
                                .padding(10)
                        }
                    }
                    
                    // 로그아웃 및 회원탈퇴 버튼
                    HStack(spacing: 24) {
                        Button(action: {
                            viewModel.logout()
                        }) {
                            Text("로그아웃")
                                .font(.system(size: 16))
                                .foregroundColor(AppTheme.Colors.disabled)
                                .underline()
                        }
                        
                        Button(action: {
                            viewModel.deleteAccount()
                        }) {
                            Text("회원탈퇴")
                                .font(.system(size: 16))
                                .foregroundColor(AppTheme.Colors.disabled)
                                .underline()
                        }
                    }
                    .padding(.vertical, 22)
                    
                    Spacer()
                    
                    // 저장 버튼
                    Button(action: {
                        viewModel.saveProfile()
                        dismiss()
                    }) {
                        Text("저장하기")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(AppTheme.Colors.primary)
                            .cornerRadius(999)
                    }
                    .padding(.bottom, 37)
                }
                .padding(.horizontal, 20)
            }
        }
        .background(Color.white.edgesIgnoringSafeArea(.all))
        .navigationBarHidden(true)
        // 날짜 선택 모달
        .sheet(isPresented: $showDatePicker) {
            DatePickerSheet(
                selectedDate: $viewModel.birthdate,
                isPresented: $showDatePicker
            )
        }
        // 변경 사항 버리기 경고
        .alert("주의", isPresented: $showDiscardAlert) {
            Button("취소", role: .cancel) { }
            Button("나가기", role: .destructive) {
                dismiss()
            }
        } message: {
            Text("저장하지 않은 내용은 사라집니다.")
        }
        .onAppear {
            viewModel.loadUserData()
        }
    }
}

// 날짜 선택 시트
struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack {
            // 날짜 선택기
            DatePicker(
                "",
                selection: $selectedDate,
                displayedComponents: .date
            )
            .datePickerStyle(WheelDatePickerStyle())
            .labelsHidden()
            
            // 확인 버튼
            Button(action: {
                isPresented = false
            }) {
                Text("확인")
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
        .padding(.top, 20)
    }
}

// 프로필 뷰모델
class ProfileViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var birthdate: Date = Date()
    @Published var selfStory: String = ""
    
    let maxLength = 2000
    private var originalName: String = ""
    private var originalBirthdate: Date = Date()
    private var originalSelfStory: String = ""
    
    var isModified: Bool {
        return name != originalName ||
               !Calendar.current.isDate(birthdate, inSameDayAs: originalBirthdate) ||
               selfStory != originalSelfStory
    }
    
    var formattedBirthdate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: birthdate)
    }
    
    func loadUserData() {
        // 실제 앱에서는 UserDefaults, CoreData, 또는 API에서 데이터를 가져옴
        // 예시 데이터
        name = UserDefaults.standard.string(forKey: "userName") ?? ""
        if let savedDate = UserDefaults.standard.object(forKey: "userBirthdate") as? Date {
            birthdate = savedDate
        }
        selfStory = UserDefaults.standard.string(forKey: "userSelfStory") ?? ""
        
        // 원본 데이터 저장
        originalName = name
        originalBirthdate = birthdate
        originalSelfStory = selfStory
    }
    
    func saveProfile() {
        // 실제 앱에서는 UserDefaults, CoreData, 또는 API에 데이터를 저장
        UserDefaults.standard.set(name, forKey: "userName")
        UserDefaults.standard.set(birthdate, forKey: "userBirthdate")
        UserDefaults.standard.set(selfStory, forKey: "userSelfStory")
        
        // 원본 데이터 업데이트
        originalName = name
        originalBirthdate = birthdate
        originalSelfStory = selfStory
        
        print("프로필이 저장되었습니다.")
    }
    
    func logout() {
        // 로그아웃 로직
        print("로그아웃")
    }
    
    func deleteAccount() {
        // 회원탈퇴 로직
        print("회원탈퇴")
    }
}
