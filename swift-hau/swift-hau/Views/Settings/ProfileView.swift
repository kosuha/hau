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
    @EnvironmentObject private var authViewModel: AuthViewModel
    
    @State private var showDatePicker = false
    @State private var showDiscardAlert = false
    @State private var showLogoutAlert = false
    @State private var showDeleteAccountAlert = false
    
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
                            showLogoutAlert = true
                        }) {
                            Text("로그아웃")
                                .font(.system(size: 16))
                                .foregroundColor(AppTheme.Colors.disabled)
                                .underline()
                        }
                        
                        Button(action: {
                            showDeleteAccountAlert = true
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
        
        // 로그아웃 확인 경고
        .alert("로그아웃", isPresented: $showLogoutAlert) {
            Button("취소", role: .cancel) { }
            Button("로그아웃", role: .destructive) {
                viewModel.logout(authViewModel: authViewModel)
            }
        } message: {
            Text("정말 로그아웃 하시겠습니까?")
        }
        
        // 회원탈퇴 확인 경고
        .alert("회원탈퇴", isPresented: $showDeleteAccountAlert) {
            Button("취소", role: .cancel) { }
            Button("탈퇴하기", role: .destructive) {
                viewModel.deleteAccount(authViewModel: authViewModel)
            }
        } message: {
            Text("모든 계정 정보가 삭제되며 복구할 수 없습니다. 정말 탈퇴하시겠습니까?")
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
