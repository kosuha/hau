//
//  UserViewModel.swift
//  swift-hau
//
//  Created by Seonho Kim on 4/11/25.
//

import Foundation
import SwiftUI
import Combine
import Supabase

class UserViewModel: ObservableObject {
    @Published var userData: UserModel = UserModel()
    @Published var isModified: Bool = false
    @Published var selectedVoice: String = "Beomsoo"
    
    // 원본 데이터 추적 (프로필 수정 용도)
    private var originalName: String?
    private var originalBirthdate: Date?
    private var originalSelfStory: String?
    private var originalVoice: String = "Beomsoo"
    
    // 사용자 ID 추가
    private var userId: String? = nil
    let maxLength = 2000
    
    // 음성 설정 관련 수정 여부 확인
    var isVoiceModified: Bool {
        return selectedVoice != originalVoice
    }
    
    // 사용자 ID 기반 저장소 키 생성 함수
    private func keyFor(_ baseKey: String) -> String {
        if let id = userId, !id.isEmpty {
            return "\(baseKey)_\(id)"
        }
        return baseKey
    }
    
    // 사용자 ID 설정 (로그인 시 호출)
    func setUserId(_ id: String) {
        userId = id
        loadUserData() // 사용자 ID가 설정되면 해당 사용자의 데이터 로드
        loadVoiceSetting() // 음성 설정도 함께 로드
    }
    
    // 사용자 데이터 로드
    func loadUserData() {
        let defaults = UserDefaults.standard
        
        // 사용자별 키로 데이터 로드
        if let name = defaults.string(forKey: keyFor("userName")) {
            userData.name = name
        }
        
        if let birthdate = defaults.object(forKey: keyFor("userBirthdate")) as? Date {
            userData.birthdate = birthdate
        }
        
        if let selfIntro = defaults.string(forKey: keyFor("userSelfStory")) {
            userData.selfIntro = selfIntro
        }
        
        if let voice = defaults.string(forKey: keyFor("userVoice")) {
            userData.voice = voice
        }
        
        if let callTime = defaults.string(forKey: keyFor("userCallTime")) {
            userData.callTime = callTime
        }
        
        // 원본 데이터 저장
        originalName = userData.name
        originalBirthdate = userData.birthdate
        originalSelfStory = userData.selfIntro
    }
    
    // 음성 설정 불러오기
    func loadVoiceSetting() {
        // UserDefaults에서 저장된 목소리 설정 불러오기
        if let savedVoice = UserDefaults.standard.string(forKey: keyFor("userVoice")) {
            selectedVoice = savedVoice
            originalVoice = savedVoice
            // userData에도 동기화
            userData.voice = savedVoice
        }
    }
    
    // 음성 설정 저장
    func saveVoiceSetting() {
        // UserDefaults에 목소리 설정 저장
        UserDefaults.standard.set(selectedVoice, forKey: keyFor("userVoice"))
        originalVoice = selectedVoice
        // userData에도 동기화
        userData.voice = selectedVoice
    }
    
    // 프로필 수정 시작 (원본 데이터 저장)
    func beginEditing() {
        isModified = false
        originalName = userData.name
        originalBirthdate = userData.birthdate
        originalSelfStory = userData.selfIntro
    }
    
    // 음성 설정 편집 시작
    func beginVoiceEditing() {
        originalVoice = selectedVoice
    }
    
    // 프로필 수정 취소
    func cancelEditing() {
        userData.name = originalName
        userData.birthdate = originalBirthdate
        userData.selfIntro = originalSelfStory
    }
    
    // 음성 설정 수정 취소
    func cancelVoiceEditing() {
        selectedVoice = originalVoice
    }
    
    // 사용자 데이터 업데이트
    func updateUserData(name: String? = nil, birthdate: Date? = nil, selfStory: String? = nil, voice: String? = nil, callTime: String? = nil) {
        let defaults = UserDefaults.standard
        
        if let name = name {
            userData.name = name
            defaults.set(name, forKey: keyFor("userName"))
            isModified = true
        }
        
        if let birthdate = birthdate {
            userData.birthdate = birthdate
            defaults.set(birthdate, forKey: keyFor("userBirthdate"))
            isModified = true
        }
        
        if let selfStory = selfStory {
            userData.selfIntro = selfStory
            defaults.set(selfStory, forKey: keyFor("userSelfStory"))
            isModified = true
        }
        
        if let voice = voice {
            userData.voice = voice
            selectedVoice = voice  // selectedVoice 동기화
            defaults.set(voice, forKey: keyFor("userVoice"))
            isModified = true
        }
        
        if let callTime = callTime {
            userData.callTime = callTime
            defaults.set(callTime, forKey: keyFor("userCallTime"))
            isModified = true
        }
    }
    
    // 프로필 저장
    func saveProfile() {
        // 이미 updateUserData에서 UserDefaults에 저장하므로 따로 저장할 필요 없음
        // 원본 데이터 업데이트
        originalName = userData.name
        originalBirthdate = userData.birthdate
        originalSelfStory = userData.selfIntro
        
        print("프로필이 저장되었습니다.")
    }
    
    // 로그아웃 처리
    func logout(authViewModel: AuthViewModel) {
        // 로그아웃 전에 현재 데이터 저장
        // 실제 로그아웃 처리
        authViewModel.signOut()
        
        // 사용자 ID 초기화
        userId = nil
        // 데이터 초기화
        userData = UserModel()
        isModified = false
    }
    
    // 회원탈퇴 처리
    func deleteAccount(authViewModel: AuthViewModel) {
        // 사용자 데이터 삭제
        if let id = userId {
            let defaults = UserDefaults.standard
            defaults.removeObject(forKey: keyFor("userName"))
            defaults.removeObject(forKey: keyFor("userBirthdate"))
            defaults.removeObject(forKey: keyFor("userSelfStory"))
            defaults.removeObject(forKey: keyFor("userVoice"))
            defaults.removeObject(forKey: keyFor("userCallTime"))
        }
        
        // 계정 삭제 작업 수행 - 서버 API 사용
        Task {
            do {
                // 현재 세션 토큰 가져오기
                let accessToken = try await client.auth.session.accessToken
                
                // API 요청 URL 설정
                let url = URL(string: "\(AppConfig.baseURL)/user/delete")!
                var request = URLRequest(url: url)
                request.httpMethod = "DELETE"
                request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                
                // API 요청 실행
                let (data, response) = try await URLSession.shared.data(for: request)
                
                // HTTP 응답 상태 코드 확인
                if let httpResponse = response as? HTTPURLResponse,
                   (200...299).contains(httpResponse.statusCode) {
                    // 성공적으로 삭제된 경우
                    await MainActor.run {
                        // 로그아웃 처리
                        authViewModel.signOut()
                    }
                    print("회원탈퇴가 성공적으로 처리되었습니다.")
                } else {
                    // 서버 오류 처리
                    let errorMessage = try? JSONDecoder().decode([String: String].self, from: data)["message"] ?? "알 수 없는 오류"
                    print("계정 삭제 서버 오류: \(errorMessage)")
                }
            } catch {
                print("계정 삭제 오류: \(error.localizedDescription)")
                // 오류 발생 시에도 로그아웃 처리
                await MainActor.run {
                    authViewModel.signOut()
                }
            }
        }
        
        print("회원탈퇴 요청이 전송되었습니다.")
    }
    
    var formattedBirthdate: String {
        guard let birthdate = userData.birthdate else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: birthdate)
    }
}
