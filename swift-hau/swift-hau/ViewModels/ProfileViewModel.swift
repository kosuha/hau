import SwiftUI
import Supabase

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
    
    func logout(authViewModel: AuthViewModel) {
        // UserDefaults에서 사용자 데이터 삭제
        UserDefaults.standard.removeObject(forKey: "userName")
        UserDefaults.standard.removeObject(forKey: "userBirthdate")
        UserDefaults.standard.removeObject(forKey: "userSelfStory")
        
        // AuthViewModel을 통해 로그아웃 수행
        authViewModel.signOut()
        
        print("로그아웃되었습니다.")
    }
    
    func deleteAccount(authViewModel: AuthViewModel) {
        // 사용자 데이터 삭제
        UserDefaults.standard.removeObject(forKey: "userName")
        UserDefaults.standard.removeObject(forKey: "userBirthdate")
        UserDefaults.standard.removeObject(forKey: "userSelfStory")
        
        // 계정 삭제 작업 수행 - 서버 API 사용
        Task {
            do {
                // 현재 세션 토큰 가져오기 - if let 대신 직접 사용
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
}
