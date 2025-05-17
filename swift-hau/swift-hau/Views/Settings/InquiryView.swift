//
//  InquiryView.swift
//  swift-hau
//
//  Created by Seonho Kim on 4/11/25.
//

import SwiftUI

struct InquiryView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var userViewModel: UserViewModel
    @State private var inquiryType: InquiryType = .general
    @State private var inquiryText: String = ""
    @State private var emailText: String = ""
    @State private var isShowingAlert = false
    @State private var alertMessage = ""
    
    // 문의 유형
    enum InquiryType: String, CaseIterable, Identifiable {
        case general = "일반 문의"
        case bug = "버그 신고"
        case feature = "기능 제안"
        case other = "기타"
        
        var id: String { self.rawValue }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // 헤더
            HeaderView(
                onPress: { dismiss() },
                title: "문의하기"
            )
            
            ScrollView {
                VStack(spacing: 24) {
                    // 안내 텍스트
                    Text("궁금한 점이나 개선사항이 있으신가요?\n아래 양식을 작성해 주시면 빠르게 답변 드리겠습니다.\n개발자에게 직접 문의하고 싶으시다면 okeydokekim@gmail.com으로 이메일을 보내셔도 좋습니다.")
                        .font(.system(size: 16))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                    
                    // 문의 유형 선택
                    VStack(alignment: .leading, spacing: 12) {
                        Text("문의 유형")
                            .font(.system(size: 16, weight: .bold))
                        
                        Picker("문의 유형", selection: $inquiryType) {
                            ForEach(InquiryType.allCases) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    .padding(.horizontal, 20)
                    
                    // 이메일 입력
                    VStack(alignment: .leading, spacing: 12) {
                        Text("답변 받을 이메일")
                            .font(.system(size: 16, weight: .bold))
                        
                        TextField("이메일 주소를 입력해 주세요", text: $emailText)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .padding(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(AppTheme.Colors.placeholder, lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 20)
                    
                    // 문의 내용 입력
                    VStack(alignment: .leading, spacing: 12) {
                        Text("문의 내용")
                            .font(.system(size: 16, weight: .bold))
                        
                        TextEditor(text: $inquiryText)
                            .frame(minHeight: 200)
                            .padding(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(AppTheme.Colors.placeholder, lineWidth: 1)
                            )
                            .overlay(
                                Group {
                                    if inquiryText.isEmpty {
                                        Text("문의 내용을 입력해 주세요. (최소 10자 이상)")
                                            .foregroundColor(AppTheme.Colors.placeholder)
                                            .padding(.horizontal, 15)
                                            .padding(.vertical, 15)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                            .allowsHitTesting(false)
                                    }
                                }
                            )
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 40)
                    
                    // 제출 버튼
                    Button(action: {
                        submitInquiry()
                    }) {
                        Text("제출하기")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(isValidInput() ? AppTheme.Colors.primary : AppTheme.Colors.disabled)
                            .cornerRadius(999)
                    }
                    .disabled(!isValidInput())
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .background(Color.white.edgesIgnoringSafeArea(.all))
        .navigationBarHidden(true)
        .alert(isPresented: $isShowingAlert) {
            Alert(
                title: Text("알림"),
                message: Text(alertMessage),
                dismissButton: .default(Text("확인"))
            )
        }
    }
    
    // 입력 유효성 검사 함수
    private func isValidInput() -> Bool {
        return inquiryText.count >= 10 && isValidEmail(emailText)
    }
    
    // 이메일 유효성 검사 (간단한 형식)
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
    
    // 문의 제출 함수
    private func submitInquiry() {
        if !isValidEmail(emailText) {
            alertMessage = "유효한 이메일 주소를 입력해 주세요."
            isShowingAlert = true
            return
        }
        
        if inquiryText.count < 10 {
            alertMessage = "문의 내용은 최소 10자 이상 입력해 주세요."
            isShowingAlert = true
            return
        }
        
        // Supabase에 문의 저장
        saveInquiryToSupabase(type: inquiryType, email: emailText, content: inquiryText)
    }
    
    // Supabase에 문의 저장
    private func saveInquiryToSupabase(type: InquiryType, email: String, content: String) {
        // Supabase에 전송할 데이터 모델 정의
        struct InquiryData: Encodable {
            let type: String
            let email: String
            let content: String
            let user_id: String?
        }

        // 현재 로그인한 사용자의 ID 가져오기 (UserModel의 authId 사용)
        let currentUserId = userViewModel.userData.authId

        let inquiryData = InquiryData(type: type.rawValue, email: email, content: content, user_id: currentUserId)

        Task {
            do {
                try await client.database
                    .from("inquiries")
                    .insert(inquiryData)
                    .execute()

                await MainActor.run {
                    alertMessage = "문의가 성공적으로 제출되었습니다."
                    isShowingAlert = true
                    inquiryText = ""
                    emailText = ""
                }

            } catch {
                await MainActor.run {
                    alertMessage = "문의 제출에 실패했습니다: \(error.localizedDescription)"
                    isShowingAlert = true
                }
                print("Supabase에 문의 저장 실패: \(error)")
            }
        }
    }
}
