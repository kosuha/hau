//
//  ResetHistoryView.swift
//  swift-hau
//
//  Created by Seonho Kim on 4/11/25.
//

import SwiftUI
import AVFoundation
import Supabase

struct ResetHistoryView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var callManager = CallManager.shared
    @State private var showConfirmAlert = false
    @State private var showCompleteAlert = false
    @State private var isResetting = false
    @State private var resetError: String? = nil
    
    // 대화 내역 초기화 함수
    private func resetChatHistory() async -> Bool {
        do {
            // 현재 사용자 ID 가져오기
            let session = try await client.auth.session
            let authId = session.user.id.uuidString.lowercased()
            
            // 먼저 데이터가 존재하는지 확인
            let checkResponse = try await client
                .from("history")
                .select("id")
                .eq("auth_id", value: authId)
                .execute()
                
            
            // history 테이블에서 해당 사용자의 모든 대화 내역 삭제
            let deleteResponse = try await client
                .from("history")
                .delete()
                .eq("auth_id", value: authId)
                .execute()
                

            return true
        } catch {
            print("대화 내역 초기화 오류: \(error.localizedDescription)")
            return false
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HeaderView(
                onPress: {
                    dismiss()
                },
                title: "대화 내역 초기화",
                isRightButton: false
            )
            
            // 콘텐츠
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 30) {
                        // 설명 텍스트
                        Text("대화 내역을 초기화하면 AI 친구와의 모든 대화 기록이 삭제됩니다. 이 작업은 되돌릴 수 없습니다.")
                            .font(.system(size: 16, weight: .medium))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                        
                        // 주의사항
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(AppTheme.Colors.error)
                                Text("주의사항")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(AppTheme.Colors.dark)
                            }
                            
                            Text("• 초기화된 대화 내역은 복구할 수 없습니다.")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.Colors.dark)
                            
                            Text("• AI 친구는 삭제된 대화 내역을 기억하지 못합니다.")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.Colors.dark)
                                
                            Text("• 프로필 정보 및 기타 설정은 변경되지 않습니다.")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.Colors.dark)
                        }
                        .padding(20)
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(16)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }

                // 초기화 버튼
                Button(action: {
                    showConfirmAlert = true
                }) {
                    Text("대화 내역 초기화")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(AppTheme.Colors.error)
                        .cornerRadius(999)
                }
                .padding(.bottom, 37)
                .padding(.horizontal, 20)
            }
            .padding(.top, 16)
        }
        .background(Color.white.edgesIgnoringSafeArea(.all))
        .navigationBarHidden(true)
        .alert("대화 내역 초기화", isPresented: $showConfirmAlert) {
            Button("취소", role: .cancel) {}
            Button("초기화", role: .destructive) {
                // 대화 내역 초기화 로직 구현
                isResetting = true
                
                Task {
                    let success = await resetChatHistory()
                    
                    // UI 업데이트는 메인 스레드에서 처리
                    await MainActor.run {
                        isResetting = false
                        
                        if success {
                            showCompleteAlert = true
                        } else {
                            resetError = "대화 내역 초기화 중 오류가 발생했습니다."
                        }
                    }
                }
            }
        } message: {
            Text("모든 대화 내역이 삭제됩니다. 이 작업은 되돌릴 수 없습니다.")
        }
        .alert("초기화 완료", isPresented: $showCompleteAlert) {
            Button("확인", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("모든 대화 내역이 성공적으로 초기화되었습니다.")
        }
        .alert("오류", isPresented: Binding<Bool>(
            get: { resetError != nil },
            set: { if !$0 { resetError = nil } }
        )) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(resetError ?? "알 수 없는 오류가 발생했습니다.")
        }
        .overlay {
            if isResetting {
                ZStack {
                    Color.black.opacity(0.4)
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        
                        Text("대화 내역을 초기화하는 중...")
                            .foregroundColor(.white)
                            .padding(.top, 16)
                    }
                }
                .edgesIgnoringSafeArea(.all)
            }
        }
    }
}

// 프리뷰
struct ResetHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        ResetHistoryView()
    }
}

