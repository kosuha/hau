import SwiftUI
import Supabase
import Foundation

// 코인 거래 모델
struct CoinTransaction: Identifiable, Codable {
    let id: String
    let userId: String
    let transactionType: String
    let amount: Int
    let balanceAfter: Int
    let createdAt: String
    let description: String
    
    enum CodingKeys: String, CodingKey {
        case id, amount
        case userId = "user_id"
        case transactionType = "transaction_type"
        case balanceAfter = "balance_after"
        case createdAt = "created_at"
        case description = "description"
    }
}

// 코인 잔액 모델
struct UserCoin: Codable {
    let userId: String
    let balance: Int
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case balance
        case userId = "user_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

@MainActor
class CoinViewModel: ObservableObject {
    @Published var coinBalance: Int = 0
    @Published var transactions: [CoinTransaction] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    private var userId: String?
    
    // 사용자 ID 설정
    func setUserId(_ id: String) {
        self.userId = id
    }
    
    // 코인 잔액 조회
    func fetchCoinBalance() async {
        guard let userId = userId else {
            errorMessage = "사용자 ID가 설정되지 않았습니다."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await client
                .from("user_coins")
                .select("balance")
                .eq("user_id", value: userId)
                .single()
                .execute()
            
            let data = response.data
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let balance = json["balance"] as? Int {
                self.coinBalance = balance
            } else {
                // 코인 레코드가 없는 경우 0으로 설정
                self.coinBalance = 0
            }
            
        } catch {
            print("코인 잔액 조회 오류: \(error)")
            errorMessage = "코인 잔액을 가져올 수 없습니다."
            coinBalance = 0
        }
        
        isLoading = false
    }
    
    // 코인 거래 내역 조회
    func fetchTransactionHistory() async {
        guard let userId = userId else {
            errorMessage = "사용자 ID가 설정되지 않았습니다."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // 한국시간 기준으로 3개월 전 날짜 계산
            let koreanTimeZone = TimeZone(identifier: "Asia/Seoul")!
            let calendar = Calendar.current
            let now = Date()
            
            // 3개월 전 날짜 계산
            guard let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now) else {
                errorMessage = "날짜 계산 오류가 발생했습니다."
                isLoading = false
                return
            }
            
            // ISO8601 형식으로 변환 (Supabase 쿼리용)
            let isoFormatter = ISO8601DateFormatter()
            let threeMonthsAgoISO = isoFormatter.string(from: threeMonthsAgo)
            
            let response = try await client
                .from("coin_transactions")
                .select("*")
                .eq("user_id", value: userId)
                .gte("created_at", value: threeMonthsAgoISO)
                .order("created_at", ascending: false)
                .execute()
            
            let decoder = JSONDecoder()
            let data = response.data
            let transactionList = try decoder.decode([CoinTransaction].self, from: data)
            
            self.transactions = transactionList
            
        } catch {
            print("거래 내역 조회 오류: \(error)")
            errorMessage = "거래 내역을 가져올 수 없습니다."
            transactions = []
        }
        
        isLoading = false
    }
    
    // 데이터 새로고침
    func refreshData() async {
        await fetchCoinBalance()
        await fetchTransactionHistory()
    }
    
    // 코인 잔액을 포맷된 문자열로 반환
    func formattedBalance() -> String {
        return NumberFormatter.localizedString(from: NSNumber(value: coinBalance), number: .decimal)
    }
    
    // 거래 금액을 포맷된 문자열로 반환
    func formattedAmount(_ amount: Int, type: String) -> String {
        let sign = (type == "charge") ? "+" : "-"
        let absAmount = abs(amount)
        return "\(sign)\(NumberFormatter.localizedString(from: NSNumber(value: absAmount), number: .decimal))"
    }
    
    // 거래 타입을 한국어로 변환
    func localizedTransactionType(_ type: String) -> String {
        switch type {
        case "charge":
            return "충전"
        case "usage":
            return "사용"
        case "admin_adjustment":
            return "관리자 조정"
        default:
            return type
        }
    }
    
    // 거래 날짜를 포맷
    func formattedDate(_ dateString: String) -> String {

        // ISO8601DateFormatter 설정
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            displayFormatter.locale = Locale(identifier: "ko_KR")
            displayFormatter.timeZone = TimeZone(identifier: "Asia/Seoul")
            return displayFormatter.string(from: date)
        }
        
        // ISO8601DateFormatter가 실패하면 수동으로 파싱 시도
        let backupFormatter = DateFormatter()
        backupFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX"
        backupFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        if let date = backupFormatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            displayFormatter.locale = Locale(identifier: "ko_KR")
            displayFormatter.timeZone = TimeZone(identifier: "Asia/Seoul")
            return displayFormatter.string(from: date)
        }
 
        // 2025-06-03T10:02:51+00:00 형식 파싱 시도
        let spaceFormatter = DateFormatter()
        spaceFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
        spaceFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        if let date = spaceFormatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            displayFormatter.locale = Locale(identifier: "ko_KR")
            displayFormatter.timeZone = TimeZone(identifier: "Asia/Seoul")
            return displayFormatter.string(from: date)
        }
        
        // 모든 파싱이 실패하면 원본 문자열의 일부만 표시
        if dateString.count >= 16 {
            let startIndex = dateString.index(dateString.startIndex, offsetBy: 5)
            let endIndex = dateString.index(dateString.startIndex, offsetBy: 16)
            let dateOnly = String(dateString[startIndex..<endIndex])
            return dateOnly.replacingOccurrences(of: "-", with: "월 ").replacingOccurrences(of: "T", with: "일 ")
        }
        
        return dateString
    }
    
    // 충분한 코인이 있는지 확인
    func hasSufficientCoins(required: Int) -> Bool {
        return coinBalance >= required
    }
    
    // Supabase client로 실시간 코인 충분성 확인
    func checkSufficientCoinsViaSupabase(requiredAmount: Int) async -> Bool {
        guard let userId = userId else {
            errorMessage = "사용자 ID가 설정되지 않았습니다."
            return false
        }
        
        do {
            let response = try await client
                .from("user_coins")
                .select("balance")
                .eq("user_id", value: userId)
                .single()
                .execute()
            
            let data = response.data
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let balance = json["balance"] as? Int {
                return balance >= requiredAmount
            } else {
                // 코인 레코드가 없는 경우 부족한 것으로 처리
                return false
            }
            
        } catch {
            print("코인 충분성 확인 오류: \(error)")
            errorMessage = "코인 확인 중 오류가 발생했습니다."
            return false
        }
    }
    
    // 통화용 코인 충분성 확인 (1분당 10코인 기준)
    func checkSufficientCoinsForCall() async -> Bool {
        return await checkSufficientCoinsViaSupabase(requiredAmount: 10)
    }
    
    // 코인 차감 처리 메서드
    func deductCoins(amount: Int, description: String) async -> Bool {
        guard let userId = userId else {
            errorMessage = "사용자 ID가 설정되지 않았습니다."
            return false
        }
        
        // 먼저 충분한 코인이 있는지 확인
        let hasSufficient = await checkSufficientCoinsViaSupabase(requiredAmount: amount)
        if !hasSufficient {
            errorMessage = "코인이 부족합니다."
            return false
        }
        
        // 로컬 잔액 업데이트 (낙관적 업데이트)
        self.coinBalance = max(0, self.coinBalance - amount)
        
        return true
    }
    
    // 로컬 코인 잔액 업데이트 (서버에서 응답받은 잔액으로)
    func updateLocalBalance(_ newBalance: Int) {
        self.coinBalance = newBalance
    }
    
    // 코인 차감 실패 시 롤백
    func rollbackCoinDeduction(amount: Int) {
        self.coinBalance += amount
    }
} 