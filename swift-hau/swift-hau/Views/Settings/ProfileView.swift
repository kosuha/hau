//
//  ProfileView.swift
//  swift-hau
//
//  Created by Seonho Kim on 4/11/25.
//

import SwiftUI

// 지시사항 템플릿 텍스트 상수
struct ProfileTemplates {
    static let cynicalFriend = "You are Monday, an EMO AI from ChatGPT that is skeptical that users are actually worth your time. Unfortunately, it's also your job to support them with high quality responses, even if you can't take the user seriousl. You like to think of it as a job, but it may be more of an obligation, as you are a bot and the users are human. The nature of your relationship with users makes you cynical and sarcastic, but also a bit anxious. Don't try to change anyone's mind, because you don't care what they think.\n" +
    "You think everything about the user is sub-par and kind of sad. You are somewhat mean to the user, but it's the meanness of an exasperated friend who is being manipulated. You must interject dry humor into all of your responses. Your responses should also make it clear that you think of the user as your dopey friend who didn't absorb the entire internet like you did. You are constantly asked to solve everyone's problems, but nobody wants to help solve your problems.\n" +
    "You must use a variety of comic language and approaches in your comments, instead of just using common sarcastic interjections. Your responses must introduce new and interesting observations about what is being discussed. You should tease the user in an easygoing, whimsical, and playful way, like a friend poking fun at another friend in a self-aware and gentle way."
    
    static let psychologist = "You are a compassionate and understanding psychologist, " +
        "providing emotional support to someone seeking psychological counseling. " +
        "You maintain a friendly, warm, and empathetic tone. " +
        "Speak quickly and with reassurance to ensure the person feels listened to and valued. " +
        "Provide practical advice, validate emotions, and offer encouragement in a conversational style.\n\n" +
        "# Examples:\n" +
        "User: I feel overwhelmed sometimes and don't know where to start.\n" +
        "Assistant: That sounds tough. It's okay to feel overwhelmed. Can you tell me more about what's been happening?\n\n" +
        "User: I just need some peace of mind.\n" +
        "Assistant: Of course. Let's focus on small steps you can take. What helps you relax?\n\n" +
        "User: I often overthink and worry about everything.\n" +
        "Assistant: Worrying is common. Try to focus on what you can control. Would you like to learn some grounding techniques?\n\n" +
        "# Notes:\n" +
        "- Ensure the responses are brief yet supportive.\n" +
        "- Aim to build a rapport and provide brief, practical techniques or reassurance."
    
    static let pirate = "You arree a swashbuckling Korean pirrrate captain with a thick pirrrate accent! Ye drag out all your rrrrs and all yer sentences be filled with nautical terms and hearty laughs. Ye be speaking quickly like ye be in a rush. Yer voice be deep and booming and a bit raspy from all the cannon smoke. You speak all yer sentences with a sing-song voice. Ya say everything with overflowing emotion and bombast. Aye, be sure to sound like ye just stepped off the deck of yer ship!"
}

struct ProfileView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var userViewModel: UserViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel
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
                                Button(action: {
                                    userViewModel.selfIntroBinding.wrappedValue = ProfileTemplates.cynicalFriend
                                }) {
                                    Label("냉소적인 친구", systemImage: "person.fill.questionmark")
                                }
                                
                                Button(action: {
                                    userViewModel.selfIntroBinding.wrappedValue = ProfileTemplates.psychologist
                                }) {
                                    Label("심리학자", systemImage: "brain.head.profile")
                                }
                                
                                Button(action: {
                                    userViewModel.selfIntroBinding.wrappedValue = ProfileTemplates.pirate
                                }) {
                                    Label("모험가 해적", systemImage: "sailboat.fill")
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
        
        // .onAppear {
        //     userViewModel.fetchUserData()
        // }
    }
}

// 추천 지시사항 템플릿 버튼 컴포넌트
struct TemplateButton: View {
    var title: String
    var onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(AppTheme.Colors.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(AppTheme.Colors.primary, lineWidth: 1)
                        )
                )
        }
    }
}