//
//  InquiryView.swift
//  swift-hau
//
//  Created by Seonho Kim on 4/11/25.
//

import SwiftUI
import MessageUI

struct InquiryView: View {
    @Environment(\.dismiss) var dismiss
    @State private var inquiryType: InquiryType = .general
    @State private var inquiryText: String = ""
    @State private var isShowingMailView = false
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
                    Text("궁금한 점이나 개선사항이 있으신가요?\n아래 양식을 작성해 주시면 빠르게 답변 드리겠습니다.")
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
                            .background(inquiryText.count >= 10 ? AppTheme.Colors.primary : AppTheme.Colors.disabled)
                            .cornerRadius(999)
                    }
                    .disabled(inquiryText.count < 10)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .background(Color.white.edgesIgnoringSafeArea(.all))
        .navigationBarHidden(true)
        .sheet(isPresented: $isShowingMailView) {
            MailView(isShowing: $isShowingMailView, result: handleMailResult)
        }
        .alert(isPresented: $isShowingAlert) {
            Alert(
                title: Text("알림"),
                message: Text(alertMessage),
                dismissButton: .default(Text("확인"))
            )
        }
    }
    
    // 문의 제출 함수
    private func submitInquiry() {
        if inquiryText.count < 10 {
            alertMessage = "문의 내용은 최소 10자 이상 입력해 주세요."
            isShowingAlert = true
            return
        }
        
        if MFMailComposeViewController.canSendMail() {
            isShowingMailView = true
        } else {
            alertMessage = "이메일을 보낼 수 없습니다. 이메일 설정을 확인해 주세요."
            isShowingAlert = true
        }
    }
    
    // 메일 결과 처리
    private func handleMailResult(_ result: Result<MFMailComposeResult, Error>) {
        switch result {
        case .success(let result):
            switch result {
            case .sent:
                alertMessage = "문의가 성공적으로 전송되었습니다."
                isShowingAlert = true
                inquiryText = ""
            case .saved:
                alertMessage = "문의가 임시 저장되었습니다."
                isShowingAlert = true
            case .cancelled:
                break
            case .failed:
                alertMessage = "문의 전송에 실패했습니다. 다시 시도해 주세요."
                isShowingAlert = true
            @unknown default:
                break
            }
        case .failure:
            alertMessage = "문의 전송에 실패했습니다. 다시 시도해 주세요."
            isShowingAlert = true
        }
    }
}

// 메일 컴포저 뷰
struct MailView: UIViewControllerRepresentable {
    @Binding var isShowing: Bool
    var result: (Result<MFMailComposeResult, Error>) -> Void
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setToRecipients(["support@example.com"])
        composer.setSubject("HAU 앱 문의")
        composer.setMessageBody("문의 내용을 입력해 주세요.", isHTML: false)
        return composer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        var parent: MailView
        
        init(_ parent: MailView) {
            self.parent = parent
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            if let error = error {
                parent.result(.failure(error))
            } else {
                parent.result(.success(result))
            }
            parent.isShowing = false
        }
    }
}
