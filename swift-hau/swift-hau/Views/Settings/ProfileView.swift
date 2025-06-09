//
//  ProfileView.swift
//  swift-hau
//
//  Created by Seonho Kim on 4/11/25.
//

import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var userViewModel: UserViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var instructionViewModel = InstructionViewModel()
    @Environment(\.presentationMode) var presentationMode
    
    @State private var showDiscardAlert = false
    @State private var showLogoutAlert = false
    @State private var showDeleteAccountAlert = false
    @State private var showSaveCompleteAlert = false
    @State private var showExceedLengthAlert = false
    
    @FocusState private var isNameFocused: Bool
    @FocusState private var isSelfIntroFocused: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            // 헤더
            HeaderView(
                onPress: {
                    // 변경 사항이 있으면 경고 표시
                    if userViewModel.isModified {
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
                        Text("별명")
                            .font(.system(size: 16, weight: .medium))

                        Text("별명은 AI 친구가 당신을 부르는 이름입니다.")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.Colors.secondary)
                        
                        TextField("별명을 입력하세요", text: userViewModel.nameBinding)
                            .focused($isNameFocused)
                            .keyboardType(.default)
                            .padding(.horizontal, 20)
                            .frame(height: 50)
                            .background(Color.white)
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.gray, lineWidth: 1)
                            )
                    }
                    
                    // 나의 이야기 입력
                    VStack(alignment: .leading, spacing: 8) {
                        Text("지시사항")
                            .font(.system(size: 16, weight: .medium))
                        
                        Text("지시사항은 AI 친구의 배경지식, 역할, 행동 방식, 대화 스타일 등을 결정합니다.")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.Colors.secondary)
                        
                        // 추천 지시사항
                        VStack(alignment: .leading, spacing: 8) {                            
                            // 드롭다운 셀렉트 버튼
                            Menu {
                                // 데이터베이스에서 가져온 템플릿들로 메뉴 구성
                                ForEach(instructionViewModel.getTemplateOptions(), id: \.0) { (title, content) in
                                    Button(action: {
                                        userViewModel.selfIntroBinding.wrappedValue = content
                                    }) {
                                        let systemImage = getSystemImageForTemplate(title)
                                        Label(title, systemImage: systemImage)
                                    }
                                }
                            } label: {
                                HStack {
                                    Text("추천 지시사항 선택하기")
                                        .font(.system(size: 15))
                                        .foregroundColor(.black)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 14))
                                        .foregroundColor(AppTheme.Colors.primary)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.white)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                            }
                        }
                        .background(AppTheme.Colors.lightTransparent)
                        .cornerRadius(8)
                        .padding(.bottom, 16)
                        
                        ZStack(alignment: .bottomTrailing) {
                            TextEditor(text: userViewModel.selfIntroBinding)
                                .focused($isSelfIntroFocused)
                                .keyboardType(.default)
                                .padding(20)
                                .frame(height: 300)
                                .background(Color.white)
                                .cornerRadius(14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.gray, lineWidth: 1)
                                )
                                .onChange(of: userViewModel.selfIntroBinding.wrappedValue) { oldValue, newValue in
                                    // 최대 글자 수 초과 시 알림 표시
                                    if newValue.count > userViewModel.maxLength && oldValue.count <= userViewModel.maxLength {
                                        showExceedLengthAlert = true
                                    }
                                }
                            
                            // 글자 수 표시
                            Text("\(userViewModel.selfIntroBinding.wrappedValue.count)/\(userViewModel.maxLength)")
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
                        userViewModel.silentlySaveProfile()
                        showSaveCompleteAlert = true
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
        .onAppear {
            Task {
                // 지시사항 템플릿 데이터 로드
                await instructionViewModel.fetchAllInstructions()
            }
        }
        // 변경 사항 버리기 경고
        .alert("주의", isPresented: $showDiscardAlert) {
            Button("취소", role: .cancel) { }
            Button("나가기", role: .destructive) {
                userViewModel.cancelEditing()
                dismiss()
            }
        } message: {
            Text("저장하지 않은 내용은 사라집니다.")
        }
        
        // 로그아웃 확인 경고
        .alert("로그아웃", isPresented: $showLogoutAlert) {
            Button("취소", role: .cancel) { }
            Button("로그아웃", role: .destructive) {
                userViewModel.logout(authViewModel: authViewModel)
            }
        } message: {
            Text("정말 로그아웃 하시겠습니까?")
        }
        
        // 회원탈퇴 확인 경고
        .alert("회원탈퇴", isPresented: $showDeleteAccountAlert) {
            Button("취소", role: .cancel) { }
            Button("탈퇴하기", role: .destructive) {
                userViewModel.deleteAccount(authViewModel: authViewModel)
            }
        } message: {
            Text("모든 계정 정보가 삭제되며 복구할 수 없습니다. 정말 탈퇴하시겠습니까?")
        }
        
        // 저장 완료 알림
        .alert("저장 완료", isPresented: $showSaveCompleteAlert) {
            Button("확인", role: .cancel) { }
        } message: {
            Text("프로필이 성공적으로 저장되었습니다.")
        }
        
        // 글자 수 초과 알림
        .alert("글자 수 초과", isPresented: $showExceedLengthAlert) {
            Button("확인", role: .cancel) {
                // 알림 확인 후 초과된 부분 자르기
                if userViewModel.selfIntroBinding.wrappedValue.count > userViewModel.maxLength {
                    userViewModel.selfIntroBinding.wrappedValue = String(userViewModel.selfIntroBinding.wrappedValue.prefix(userViewModel.maxLength))
                }
            }
        } message: {
            Text("지시사항이 최대 글자 수(\(userViewModel.maxLength)자)를 초과하여 뒷 부분을 제거합니다.")
        }
        
        .onTapGesture {
            isNameFocused = false
            isSelfIntroFocused = false
        }
    }
    
    // 템플릿 제목에 따른 시스템 아이콘 반환
    private func getSystemImageForTemplate(_ title: String) -> String {
        switch title {
        case "냉소적인 친구":
            return "person.fill.questionmark"
        case "심리학자":
            return "brain.head.profile"
        case "모험가 해적":
            return "sailboat.fill"
        default:
            return "textformat"
        }
    }
}