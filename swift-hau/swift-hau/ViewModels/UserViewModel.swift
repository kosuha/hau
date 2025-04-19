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
    @Published var selectedVoice: String = "Beomsoo"
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var isOnboardingCompleted: Bool = false
    
    // 원본 데이터 추적 (프로필 수정 용도)
    private var originalName: String?
    private var originalBirthdate: Date?
    private var originalSelfStory: String?
    private var originalVoice: String = "Beomsoo"
    
    // 사용자 ID 추가
    private var userId: String? = nil
    let maxLength = 2000
    
    // 프로필 수정 여부 계산 속성
    var isModified: Bool {
        // userData의 현재 값과 original 값을 비교
        // 옵셔널 값 비교 시 nil 처리 주의
        let nameChanged = userData.name != originalName
        let birthdateChanged = userData.birthdate != originalBirthdate
        // selfIntro가 nil일 경우 빈 문자열로 간주하여 비교
        let selfStoryChanged = (userData.selfIntro ?? "") != (originalSelfStory ?? "")

        return nameChanged || birthdateChanged || selfStoryChanged
    }
    
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
    
    // 사용자 ID 설정 (로그인 후 호출)
    func setUserId(_ id: String) {
        userId = id
        fetchUserData() // 사용자 ID가 설정되면 데이터 가져오기
    }
    
    // 서버에서 사용자 데이터 가져오기
    func fetchUserData() {
        isLoading = true

        guard let userId = userId else {
            print("사용자 ID가 없습니다.")
            isLoading = false
            return
        }

        Task {
            do {
                print("사용자 데이터 조회 시도: auth_id=\(userId)")
                let response = try await client.from("users")
                    .select()
                    .eq("auth_id", value: userId.lowercased()) // Supabase는 UUID를 소문자로 저장하는 경우가 많으므로 소문자 변환 추가
                    .limit(1)
                    .execute()

                // 응답 데이터 확인 (디버깅용)
                if let jsonString = String(data: response.data, encoding: .utf8) {
                    print("응답 JSON 문자열: \(jsonString)")
                }

                // Supabase는 결과를 배열로 반환합니다.
                let decoder = JSONDecoder()
                let dateFormatter = DateFormatter()
                // 밀리초(.SSS) 부분을 제거하여 좀 더 일반적인 ISO 8601 형식 처리
                dateFormatter.dateFormat = "yyyy-MM-dd"
                // 타임존 설정 (필요한 경우)
                // dateFormatter.timeZone = TimeZone(secondsFromGMT: 0) // UTC
                dateFormatter.locale = Locale(identifier: "en_US_POSIX") // ISO 8601 파싱에는 고정 로케일 사용 권장
                decoder.dateDecodingStrategy = .formatted(dateFormatter)

                // 1. 디코딩 시도
                do {
                    let profiles = try decoder.decode([UserModel].self, from: response.data)

                    // 2. 프로필 존재 여부 확인
                    if let profile = profiles.first {
                        // 프로필 데이터가 성공적으로 디코딩되고 존재하는 경우
                        await MainActor.run {
                            self.userData = profile
                            self.selectedVoice = profile.voice ?? "Beomsoo"

                            // 원본 데이터 저장 (fetch 성공 시점에 원본 데이터 업데이트)
                            self.originalName = profile.name
                            self.originalBirthdate = profile.birthdate
                            self.originalSelfStory = profile.selfIntro
                            self.originalVoice = profile.voice ?? "Beomsoo"

                            // 이름이 비어있지 않으면 온보딩 완료로 간주
                            if let name = profile.name, !name.isEmpty {
                                self.isOnboardingCompleted = true
                                print("온보딩 완료: \(name)")
                            } else {
                                self.isOnboardingCompleted = false // 이름이 없으면 온보딩 미완료
                            }

                            self.isLoading = false
                        }
                    } else {
                        // 3. 프로필 데이터가 없는 경우 (배열이 비어 있음)
                        print("사용자 프로필을 찾을 수 없습니다. 새 프로필을 생성합니다.")
                        await createAndSaveNewProfile(userId: userId)
                    }
                } catch let decodingError {
                    // 4. 디코딩 오류 발생
                    print("디코딩 오류: \(decodingError.localizedDescription)")
                    // 디코딩 오류에 대한 상세 정보 출력
                    if let decodingError = decodingError as? DecodingError {
                        switch decodingError {
                        case .typeMismatch(let type, let context):
                            print("Type mismatch: \(type), Context: \(context.codingPath) - \(context.debugDescription)")
                        case .valueNotFound(let type, let context):
                            print("Value not found: \(type), Context: \(context.codingPath) - \(context.debugDescription)")
                        case .keyNotFound(let key, let context):
                            print("Key not found: \(key), Context: \(context.codingPath) - \(context.debugDescription)")
                        case .dataCorrupted(let context):
                            print("Data corrupted: Context: \(context.codingPath) - \(context.debugDescription)")
                        @unknown default:
                            print("Unknown decoding error")
                        }
                    }

                    // --- 대체 날짜 형식 시도 (선택 사항) ---
                    // 만약 위 형식으로도 실패하면, 다른 형식을 시도해볼 수 있습니다.
                    // 예를 들어 'yyyy-MM-dd' 형식만 오는 경우:
                    print("기본 날짜 형식 디코딩 실패. 'yyyy-MM-dd' 형식 시도...")
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                    decoder.dateDecodingStrategy = .formatted(dateFormatter)
                    do {
                        let profiles = try decoder.decode([UserModel].self, from: response.data)
                        if let profile = profiles.first {
                            print("'yyyy-MM-dd' 형식으로 디코딩 성공.")
                            // ... 성공 시 프로필 데이터 처리 (위와 동일 로직) ...
                            await MainActor.run {
                                self.userData = profile
                                self.selectedVoice = profile.voice ?? "Beomsoo"
                                // ... 원본 데이터 저장 ...
                                // ... 온보딩 상태 확인 ...
                                self.isLoading = false
                            }
                            // 성공했으므로 함수 종료
                            return
                        } else {
                            // 'yyyy-MM-dd' 형식으로 디코딩은 성공했으나 데이터가 없는 경우
                            print("대체 형식 디코딩 후 프로필 없음. 새 프로필 생성.")
                            await createAndSaveNewProfile(userId: userId)
                            return // 함수 종료
                        }
                    } catch let secondDecodingError {
                        print("대체 날짜 형식 ('yyyy-MM-dd') 디코딩 오류: \(secondDecodingError.localizedDescription)")
                        // 최종 실패 처리
                        await MainActor.run {
                            self.errorMessage = "사용자 데이터를 처리하는 중 오류가 발생했습니다. (날짜 형식 오류)"
                            self.isLoading = false
                        }
                    }
                    // --- 대체 날짜 형식 시도 끝 ---

                    // 만약 대체 형식 시도를 하지 않는다면, 아래 코드는 유지합니다.
                    // await MainActor.run {
                    //     self.errorMessage = "사용자 데이터를 처리하는 중 오류가 발생했습니다. (형식 오류)"
                    //     self.isLoading = false
                    // }
                }
            } catch {
                // 5. 네트워크 오류 또는 기타 Supabase 관련 오류
                print("Supabase 데이터 조회 오류: \(error.localizedDescription)")
                await MainActor.run {
                    self.errorMessage = "데이터를 가져오는 중 오류가 발생했습니다."
                    self.isLoading = false
                }
            }
        }
    }

    // 새 프로필 생성 및 저장 (Helper 함수)
    private func createAndSaveNewProfile(userId: String) async {
        // 기본 사용자 프로필 생성
        let newProfile = UserModel(
            birthdate: nil,
            name: "",
            selfIntro: "",
            voice: "Beomsoo",
            callTime: "",
            plan: "free",
            authId: userId
        )

        // 새 프로필을 데이터베이스에 저장
        print("새 프로필 저장 시도: auth_id=\(userId)")
        do {
            let insertResponse = try await client.from("users")
                .insert(newProfile)
                .execute()

            print("새 프로필 저장 성공: \(insertResponse)")
            print("응답 상태 코드: \(insertResponse.status)")

            // 기본 프로필로 로컬 데이터 설정
            await MainActor.run {
                self.userData = newProfile
                self.selectedVoice = "Beomsoo"

                // 원본 데이터 저장 (새 프로필 생성 시점에도 원본 데이터 업데이트)
                self.originalName = ""
                self.originalBirthdate = nil
                self.originalSelfStory = ""
                self.originalVoice = "Beomsoo"

                self.isOnboardingCompleted = false // 새 프로필은 온보딩 미완료 상태
                self.isLoading = false
            }
        } catch {
            print("새 프로필 저장 오류: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = "새 프로필을 저장하는 중 오류가 발생했습니다."
                self.isLoading = false
            }
        }
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
    
    // 음성 설정 조용히 저장 (화면 이탈 방지)
    func silentlySaveVoiceSetting() {
        // UserDefaults에 목소리 설정 저장
        UserDefaults.standard.set(selectedVoice, forKey: keyFor("userVoice"))
        originalVoice = selectedVoice
        // userData에도 동기화
        userData.voice = selectedVoice
    }
    
    // 음성 설정 저장
    func saveVoiceSetting() {
        // UserDefaults에 목소리 설정 저장
        UserDefaults.standard.set(selectedVoice, forKey: keyFor("userVoice"))
        originalVoice = selectedVoice
        // userData에도 동기화
        userData.voice = selectedVoice
    }
    
    // 음성 설정 편집 시작
    func beginVoiceEditing() {
        originalVoice = selectedVoice
    }
    
    // 프로필 수정 취소
    func cancelEditing() {
        // userData를 원본 데이터로 복원
        userData.name = originalName
        userData.birthdate = originalBirthdate
        userData.selfIntro = originalSelfStory
        // isModified는 자동으로 false가 됨 (computed property)
    }
    
    // 음성 설정 수정 취소
    func cancelVoiceEditing() {
        selectedVoice = originalVoice
    }
    
    // 프로필 저장 (서버로 전송)
    func saveProfile() {
        isLoading = true
        
        // 더미 저장 동작 - 로컬 상태만 즉시 업데이트
        // 원본 데이터 업데이트
        // self.originalName = self.userData.name
        // self.originalBirthdate = self.userData.birthdate
        // self.originalSelfStory = self.userData.selfIntro
        // self.originalVoice = self.userData.voice ?? "Beomsoo"
        
        // self.isModified = false
        // self.isLoading = false
        
        // TODO: 서버 연동 코드 - 테스트 후 주석 해제
        
        guard let userId = userId else {
            print("사용자 ID가 없습니다.")
            isLoading = false
            return
        }
        
        Task {
            do {
                // 서버로 전송할 데이터 준비
                // Supabase에 데이터 업데이트
                print("프로필 저장 시도: auth_id=\(userId)")
                let response = try await client.from("users")
                    .update(userData)
                    .eq("auth_id", value: userId)
                    .execute()

                print("프로필 저장 성공: \(response)")
                print("응답 상태 코드: \(response.status)")
                
                await MainActor.run {
                    // 원본 데이터 업데이트 (저장 성공 시점에 원본 데이터 업데이트)
                    self.originalName = self.userData.name
                    self.originalBirthdate = self.userData.birthdate
                    self.originalSelfStory = self.userData.selfIntro
                    self.originalVoice = self.userData.voice ?? "Beomsoo"
                    
                    self.isLoading = false

                    // 이름이 비어있지 않으면 온보딩 완료로 간주 (nil 또는 빈 문자열 확인)
                    if let name = self.userData.name, !name.isEmpty {
                        self.isOnboardingCompleted = true
                    }
                }
            } catch {
                print("프로필 저장 오류: \(error.localizedDescription)")
                await MainActor.run {
                    self.errorMessage = "프로필을 저장하는 중 오류가 발생했습니다."
                    self.isLoading = false
                }
            }
        }
        
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
        guard let birthdate = userData.birthdate else { return "생년월일을 선택하세요" } // Placeholder 추가
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 M월 d일" // 원하는 형식으로 변경
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: birthdate)
    }

    // ProfileView의 TextEditor 바인딩을 위한 헬퍼
    // userData.selfIntro가 String? 이므로, Non-optional String 바인딩 제공
    var selfIntroBinding: Binding<String> {
        Binding<String>(
            get: { self.userData.selfIntro ?? "" },
            set: { self.userData.selfIntro = $0 }
        )
    }

    // ProfileView의 TextField 바인딩을 위한 헬퍼
    // userData.name이 String? 이므로, Non-optional String 바인딩 제공
    var nameBinding: Binding<String> {
        Binding<String>(
            get: { self.userData.name ?? "" },
            set: { self.userData.name = $0 }
        )
    }

    // ProfileView의 DatePickerSheet 바인딩을 위한 헬퍼
    // userData.birthdate가 Date? 이므로, Non-optional Date 바인딩 제공 (기본값 설정)
    var birthdateBinding: Binding<Date> {
        Binding<Date>(
            get: { self.userData.birthdate ?? Date() }, // 기본값으로 현재 날짜 사용 또는 다른 적절한 기본값 설정
            set: { self.userData.birthdate = $0 }
        )
    }

    // 프로필만 조용히 저장 (화면 이탈 방지)
    func silentlySaveProfile() {
        // 서버에 조용히 저장
        guard let userId = userId else {
            print("사용자 ID가 없습니다.")
            return
        }
        
        Task {
            do {
                // Supabase에 데이터 업데이트
                print("프로필 저장 시도: auth_id=\(userId)")
                let response = try await client.from("users")
                    .update(userData)
                    .eq("auth_id", value: userId)
                    .execute()

                print("프로필 저장 성공: \(response.status)")
                
                // 원본 데이터 업데이트 (저장 성공 시점에 원본 데이터 업데이트)
                await MainActor.run {
                    self.originalName = self.userData.name
                    self.originalBirthdate = self.userData.birthdate
                    self.originalSelfStory = self.userData.selfIntro
                    self.originalVoice = self.userData.voice ?? "Beomsoo"
                }
            } catch {
                print("프로필 저장 오류: \(error.localizedDescription)")
            }
        }
    }

    // 통화 시간만 조용히 저장 (화면 이탈 방지)
    func silentlySaveCallTime(_ callTimeJson: String) {
        // userData만 업데이트
        userData.callTime = callTimeJson
        
        // 원본 데이터도 동기화
        
        // 서버에 조용히 저장
        guard let userId = userId else {
            print("사용자 ID가 없습니다.")
            return
        }
        
        Task {
            do {
                // 서버로 전송할 최소 데이터 준비
                let updateData = ["call_time": callTimeJson]
                
                // Supabase에 데이터 업데이트
                print("통화 시간 저장 시도: auth_id=\(userId)")
                let response = try await client.from("users")
                    .update(updateData)
                    .eq("auth_id", value: userId)
                    .execute()

                print("통화 시간 저장 성공: \(response.status)")
            } catch {
                print("통화 시간 저장 오류: \(error.localizedDescription)")
            }
        }
    }

    // 다음 통화 일정을 가져오는 함수
    func getNextCallSchedule() -> (day: String, time: String, isDayLabel: Bool)? {
        guard let callTimeJson = userData.callTime,
              !callTimeJson.isEmpty,
              let jsonData = callTimeJson.data(using: .utf8) else {
            return nil
        }
        
        do {
            // JSON 문자열 디코딩
            let schedules = try JSONDecoder().decode([[String: String]].self, from: jsonData)
            if schedules.isEmpty {
                return nil
            }
            
            // 현재 요일과 시간 가져오기
            let calendar = Calendar.current
            let now = Date()
            let currentWeekday = calendar.component(.weekday, from: now) // 1(일)~7(토)
            let currentHour = calendar.component(.hour, from: now)
            let currentMinute = calendar.component(.minute, from: now)
            
            // 요일 매핑 (1(일)~7(토) -> "일", "월", ...)
            let weekdayMapping = [1: "일", 2: "월", 3: "화", 4: "수", 5: "목", 6: "금", 7: "토"]
            let koreanWeekdayIndex = weekdayMapping[currentWeekday] ?? ""
            
            // 요일 순서 (월~일)
            let weekdayOrder = ["월": 0, "화": 1, "수": 2, "목": 3, "금": 4, "토": 5, "일": 6]
            
            // 현재 요일의 인덱스
            let currentDayIndex = weekdayOrder[koreanWeekdayIndex] ?? 0
            
            // 현재 시간 (분 단위)
            let currentTimeInMinutes = currentHour * 60 + currentMinute
            
            // 오늘 중에 남은 일정 찾기
            var todayLaterSchedules = schedules.filter { schedule in
                guard let day = schedule["day"], let time = schedule["time"] else { return false }
                if day != koreanWeekdayIndex { return false }
                
                // 시간 파싱
                let components = time.split(separator: ":")
                if components.count != 2 { return false }
                guard let hour = Int(components[0]), let minute = Int(components[1]) else { return false }
                
                let scheduleTimeInMinutes = hour * 60 + minute
                return scheduleTimeInMinutes > currentTimeInMinutes
            }
            
            // 오늘 중에 남은 일정이 있다면, 그 중 가장 빠른 시간 선택
            if !todayLaterSchedules.isEmpty {
                todayLaterSchedules.sort { schedule1, schedule2 in
                    let time1 = schedule1["time"] ?? ""
                    let time2 = schedule2["time"] ?? ""
                    return time1 < time2
                }
                // 오늘이므로 day를 "오늘"로 설정하고 isDayLabel = true
                return ("오늘", todayLaterSchedules[0]["time"] ?? "", true)
            }
            
            // 내일 요일 찾기
            let tomorrowDayIndex = (currentDayIndex + 1) % 7
            let tomorrowDay = weekdayOrder.first(where: { $0.value == tomorrowDayIndex })?.key ?? ""
            
            // 내일 일정 찾기
            var tomorrowSchedules = schedules.filter { $0["day"] == tomorrowDay }
            if !tomorrowSchedules.isEmpty {
                // 내일 중 가장 빠른 시간 선택
                tomorrowSchedules.sort { schedule1, schedule2 in
                    let time1 = schedule1["time"] ?? ""
                    let time2 = schedule2["time"] ?? ""
                    return time1 < time2
                }
                // 내일이므로 day를 "내일"로 설정하고 isDayLabel = true
                return ("내일", tomorrowSchedules[0]["time"] ?? "", true)
            }
            
            // 모레 이후 요일 순회하며 가장 빠른 일정 찾기
            for dayOffset in 2...7 {
                let nextDayIndex = (currentDayIndex + dayOffset) % 7
                let nextDay = weekdayOrder.first(where: { $0.value == nextDayIndex })?.key ?? ""
                
                var nextDaySchedules = schedules.filter { $0["day"] == nextDay }
                if !nextDaySchedules.isEmpty {
                    // 해당 요일의 가장 빠른 시간 선택
                    nextDaySchedules.sort { schedule1, schedule2 in
                        let time1 = schedule1["time"] ?? ""
                        let time2 = schedule2["time"] ?? ""
                        return time1 < time2
                    }
                    // 요일로 반환하고 isDayLabel = false
                    return (nextDaySchedules[0]["day"] ?? "", nextDaySchedules[0]["time"] ?? "", false)
                }
            }
            
            // 결국 다음 일정이 발견되지 않았다면, 그냥 첫 번째 일정 반환
            let sortedSchedules = schedules.sorted { schedule1, schedule2 in
                let day1 = schedule1["day"] ?? ""
                let day2 = schedule2["day"] ?? ""
                let dayIndex1 = weekdayOrder[day1] ?? 0
                let dayIndex2 = weekdayOrder[day2] ?? 0
                
                if dayIndex1 == dayIndex2 {
                    let time1 = schedule1["time"] ?? ""
                    let time2 = schedule2["time"] ?? ""
                    return time1 < time2
                }
                
                return dayIndex1 < dayIndex2
            }
            
            // 일반 요일로 반환하고 isDayLabel = false
            return (sortedSchedules[0]["day"] ?? "", sortedSchedules[0]["time"] ?? "", false)
            
        } catch {
            print("통화 일정 파싱 오류: \(error.localizedDescription)")
            return nil
        }
    }
    
    // 다음 통화 일정의 사용자 친화적인 문자열 반환
    func getNextCallScheduleText() -> String {
        if let nextSchedule = getNextCallSchedule() {
            let dayText = nextSchedule.isDayLabel ? nextSchedule.day : "\(nextSchedule.day)요일"
            return "\(dayText) \(nextSchedule.time)"
        } else {
            return "설정된 통화 일정이 없습니다"
        }
    }
}
