//
//  CallTimeSettingScreen.swift
//  swift-hau
//
//  Created by Seonho Kim on 4/11/25.
//

import SwiftUI

struct CallTimeSettingView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var userViewModel: UserViewModel
    @State private var isScheduleModalPresented: Bool = false
    @State private var isEditMode: Bool = false
    @State private var editingItemIndex: Int? = nil
    @State private var editingDay: String = ""
    @State private var editingTime: String = ""
    @State private var showTimeConflictAlert: Bool = false
    @State private var conflictAlertMessage: String = ""
    @State private var unsortedTimes: [[String: String]] = [
        // [
        //     "day": "월",
        //     "time": "10:00"
        // ],
    ]
    
    // 정렬된 일정 아이템 배열 계산
    var predefinedTimes: [[String: String]] {
        unsortedTimes.sorted { item1, item2 in
            // 요일 순서 가져오기
            let weekdayOrder = ["월": 0, "화": 1, "수": 2, "목": 3, "금": 4, "토": 5, "일": 6]
            let day1 = item1["day"] ?? ""
            let day2 = item2["day"] ?? ""
            let dayOrder1 = weekdayOrder[day1] ?? 0
            let dayOrder2 = weekdayOrder[day2] ?? 0
            
            // 요일이 같으면 시간 순으로 정렬
            if dayOrder1 == dayOrder2 {
                let time1 = item1["time"] ?? ""
                let time2 = item2["time"] ?? ""
                return time1 < time2
            }
            
            // 요일 순으로 정렬
            return dayOrder1 < dayOrder2
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // 헤더
            HeaderView(
                onPress: { dismiss() },
                title: "통화 시간 설정",
                isRightButton: true,
                rightButtonImage: "plus",
                rightButtonAction: {
                    // 추가 버튼 눌렀을 때 통화 시간 설정 모달
                    isEditMode = false
                    isScheduleModalPresented = true
                }
            )
            
            ScrollView {
                VStack(spacing: 24) {
                    // 설명 텍스트
                    Text("매주 설정한 시간에 전화할게요.")
                        .font(.system(size: 16))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                    
                    // 시간 옵션 목록
                    VStack(spacing: 12) {
                        ForEach(predefinedTimes.indices, id: \.self) { index in
                            let timeOption = predefinedTimes[index]
                            ScheduleItem(
                                day: timeOption["day"] ?? "",
                                time: timeOption["time"] ?? "",
                                onTap: {
                                    // 아이템 클릭 시 수정 모드로 전환
                                    if let originalIndex = unsortedTimes.firstIndex(where: { $0["day"] == timeOption["day"] && $0["time"] == timeOption["time"] }) {
                                        editingDay = timeOption["day"] ?? ""
                                        editingTime = timeOption["time"] ?? ""
                                        editingItemIndex = originalIndex
                                        isEditMode = true
                                        isScheduleModalPresented = true
                                    }
                                },
                                onDelete: {
                                    if let originalIndex = unsortedTimes.firstIndex(where: { $0["day"] == timeOption["day"] && $0["time"] == timeOption["time"] }) {
                                        unsortedTimes.remove(at: originalIndex)
                                        saveToUserViewModel()
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
            }
        }
        .background(Color.white.edgesIgnoringSafeArea(.all))
        .navigationBarHidden(true)
        .sheet(isPresented: $isScheduleModalPresented) {
            if isEditMode {
                ScheduleSettingModal(
                    initialDay: editingDay,
                    initialTime: editingTime,
                    onSave: { day, time in
                        if let index = editingItemIndex {
                            // 기존 아이템 제외하고 시간 겹침 확인
                            let tempTimes = unsortedTimes.enumerated().filter { $0.offset != index }.map { $0.element }
                            if !isTimeConflict(day: day, time: time, existingTimes: tempTimes) {
                                unsortedTimes[index] = [
                                    "day": day,
                                    "time": time
                                ]
                                saveToUserViewModel()
                                isScheduleModalPresented = false
                            } else {
                                // 시간 겹침 알림 표시
                                showTimeConflictAlert = true
                            }
                        }
                    },
                    isTimeConflict: { day, time in
                        if let index = editingItemIndex {
                            // 기존 아이템 제외하고 시간 겹침 확인
                            let tempTimes = unsortedTimes.enumerated().filter { $0.offset != index }.map { $0.element }
                            return isTimeConflict(day: day, time: time, existingTimes: tempTimes)
                        }
                        return false
                    }
                )
                .presentationDetents([.fraction(0.85)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(32)
                .alert("시간 간격 확인", isPresented: $showTimeConflictAlert) {
                    Button("확인", role: .cancel) { }
                } message: {
                    Text("같은 날의 다른 통화 일정과 최소 60분 이상 차이가 나야 합니다.")
                }
            } else {
                ScheduleSettingModal(
                    onSave: { day, time in
                        if !isTimeConflict(day: day, time: time, existingTimes: unsortedTimes) {
                            unsortedTimes.append([
                                "day": day,
                                "time": time
                            ])
                            saveToUserViewModel()
                            isScheduleModalPresented = false
                        } else {
                            // 시간 겹침 알림 표시
                            showTimeConflictAlert = true
                        }
                    },
                    isTimeConflict: { day, time in
                        return isTimeConflict(day: day, time: time, existingTimes: unsortedTimes)
                    }
                )
                .presentationDetents([.fraction(0.85)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(32)
                .alert("시간 간격 확인", isPresented: $showTimeConflictAlert) {
                    Button("확인", role: .cancel) { }
                } message: {
                    Text("같은 날의 다른 통화 일정과 최소 60분 이상 차이가 나야 합니다.")
                }
            }
        }
        .onAppear {
            loadFromUserViewModel()
        }
    }
    
    // 시간 간격이 60분 이내인지 확인
    private func isTimeConflict(day: String, time: String, existingTimes: [[String: String]]) -> Bool {
        // 시간 문자열을 분으로 변환
        let newTimeMinutes = timeStringToMinutes(time)
        
        // 같은 요일의 시간들만 필터링
        let sameDayTimes = existingTimes.filter { $0["day"] == day }
        
        // 60분 이내에 다른 일정이 있는지 확인
        for existingTime in sameDayTimes {
            if let timeStr = existingTime["time"] {
                let existingTimeMinutes = timeStringToMinutes(timeStr)
                let diff = abs(existingTimeMinutes - newTimeMinutes)
                
                if diff < 60 {
                    return true // 60분 이내에 다른 일정이 있음
                }
            }
        }
        
        return false // 충돌 없음
    }
    
    // 시간 문자열(HH:MM)을 분 단위로 변환
    private func timeStringToMinutes(_ timeStr: String) -> Int {
        let components = timeStr.split(separator: ":")
        if components.count == 2,
           let hour = Int(components[0]),
           let minute = Int(components[1]) {
            return hour * 60 + minute
        }
        return 0
    }
    
    // UserViewModel에 저장
    private func saveToUserViewModel() {
        do {
            let jsonData = try JSONEncoder().encode(unsortedTimes)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                userViewModel.userData.callTime = jsonString
                
                // 즉시 UserDefaults에도 저장 (비동기 저장 중 오류로 인한 화면 이탈 방지)
                UserDefaults.standard.set(jsonString, forKey: "userCallSchedule")
                
                // 비동기로 처리하여 UI 스레드 차단 방지
                Task {
                    await MainActor.run {
                        // 화면 이탈 방지를 위해 saveProfile 직접 호출 대신 userData만 업데이트
                        // userViewModel.saveProfile() 직접 호출 대신 userData만 업데이트
                        userViewModel.silentlySaveCallTime(jsonString)
                    }
                }
            }
        } catch {
            print("통화 시간 저장 오류: \(error.localizedDescription)")
        }
    }
    
    // UserViewModel에서 로드
    private func loadFromUserViewModel() {
        if let jsonString = userViewModel.userData.callTime,
           let jsonData = jsonString.data(using: .utf8) {
            do {
                let times = try JSONDecoder().decode([[String: String]].self, from: jsonData)
                unsortedTimes = times
            } catch {
                print("통화 시간 로드 오류: \(error.localizedDescription)")
                unsortedTimes = []
            }
        } else {
            unsortedTimes = []
        }
    }
}

// 일정 아이템 컴포넌트
struct ScheduleItem: View {
    var day: String
    var time: String
    var onTap: () -> Void
    var onDelete: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onTap) {
                // 요일 표시
                Text("\(day)요일")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppTheme.Colors.text)
                    .padding(10)
                
                // 시간 표시
                Text(time)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppTheme.Colors.text)
                
                Spacer()
            }
            
            // 삭제 버튼
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(AppTheme.Colors.placeholder)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppTheme.Colors.placeholder, lineWidth: 1)
        )
    }
}

// 통화 일정 설정 모달 뷰
struct ScheduleSettingModal: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedDay: String
    @State private var selectedTime: Date
    @State private var showTimeConflictError: Bool = false
    
    let weekdays = ["월", "화", "수", "목", "금", "토", "일"]
    
    var onSave: (String, String) -> Void
    var isTimeConflict: (String, String) -> Bool
    
    // 새 일정 추가 시 초기화
    init(onSave: @escaping (String, String) -> Void, isTimeConflict: @escaping (String, String) -> Bool = { _, _ in false }) {
        self.onSave = onSave
        self.isTimeConflict = isTimeConflict
        
        // 현재 요일 가져오기
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        // weekday는 1(일요일)~7(토요일)이지만 한국 요일 배열은 월~일 순서
        // 1(일) -> 6, 2(월) -> 0, 3(화) -> 1, ...
        let koreanWeekdayIndex = (weekday + 5) % 7
        let initialDay = ["월", "화", "수", "목", "금", "토", "일"][koreanWeekdayIndex]
        
        // _State 사용해 초기값 설정
        _selectedDay = State(initialValue: initialDay)
        _selectedTime = State(initialValue: Date())
    }
    
    // 기존 일정 수정 시 초기화
    init(initialDay: String, initialTime: String, onSave: @escaping (String, String) -> Void, isTimeConflict: @escaping (String, String) -> Bool = { _, _ in false }) {
        self.onSave = onSave
        self.isTimeConflict = isTimeConflict
        
        // 시간 문자열을 Date로 변환
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let date = formatter.date(from: initialTime) ?? Date()
        
        // _State 사용해 초기값 설정
        _selectedDay = State(initialValue: initialDay)
        _selectedTime = State(initialValue: date)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // 모달 헤더
            HStack {
                Text("시간 설정")
                    .font(.system(size: 20, weight: .bold))
                Spacer()
            }
            .padding(.horizontal, 20)
            
            // 요일 선택
            VStack(alignment: .leading, spacing: 10) {
                Text("요일 선택")
                    .font(.system(size: 16, weight: .bold))
                
                GeometryReader { geometry in
                    HStack(spacing: 8) {
                        ForEach(weekdays, id: \.self) { day in
                            Button(action: {
                                selectedDay = day
                                // 요일 변경 시 시간 충돌 검사
                                checkTimeConflict()
                            }) {
                                Text(day)
                                    .font(.system(size: 14, weight: .medium))
                                    .frame(width: (geometry.size.width - 48) / 7, height: (geometry.size.width - 48) / 7)
                                    .background(
                                        Circle()
                                            .fill(selectedDay == day ? AppTheme.Colors.primary : Color.white)
                                    )
                                    .foregroundColor(selectedDay == day ? .white : AppTheme.Colors.text)
                                    .overlay(
                                        Circle()
                                            .stroke(selectedDay == day ? AppTheme.Colors.primary : AppTheme.Colors.placeholder, lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .frame(height: 50)
            }
            .padding(.horizontal, 20)
            
            // 시간 선택
            VStack(alignment: .leading, spacing: 10) {
                Text("시간 선택")
                    .font(.system(size: 16, weight: .bold))
                
                DatePicker("", selection: $selectedTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(WheelDatePickerStyle())
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .onChange(of: selectedTime) { _ in
                        // 시간 변경 시 충돌 검사
                        checkTimeConflict()
                    }
            }
            .padding(.horizontal, 20)
            
            // 시간 충돌 경고 메시지
            if showTimeConflictError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(AppTheme.Colors.warning)
                    Text("다른 통화 일정과 최소 60분 이상 차이가 나야 합니다.")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.Colors.warning)
                }
                .padding(.horizontal, 20)
                .frame(height: 20)
            } else {
                VStack {
                    Spacer()
                }
                .frame(height: 20)
            }

            Spacer()
            
            // 저장 버튼
            Button(action: {
                saveSchedule()
            }) {
                Text("저장")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(showTimeConflictError ? AppTheme.Colors.disabled : AppTheme.Colors.primary)
                    .cornerRadius(999)
            }
            .disabled(showTimeConflictError)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .background(Color.white)
        .padding(.bottom, 70)
        .padding(.top, 48)
        .edgesIgnoringSafeArea(.bottom)
        .onAppear {
            // 모달이 처음 열릴 때 유효성 검사 실행
            checkTimeConflict()
        }
    }
    
    // 시간 충돌 확인
    private func checkTimeConflict() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let timeString = formatter.string(from: selectedTime)
        
        showTimeConflictError = isTimeConflict(selectedDay, timeString)
    }
    
    private func saveSchedule() {
        // 시간 형식 (10:00)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let timeString = formatter.string(from: selectedTime)
        
        // 충돌 확인 후 저장
        if !isTimeConflict(selectedDay, timeString) {
            onSave(selectedDay, timeString)
        }
    }
}

// 특정 코너만 둥글게 하기 위한 extension
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
