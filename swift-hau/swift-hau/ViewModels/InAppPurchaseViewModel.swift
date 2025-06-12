import SwiftUI
import StoreKit

// 인앱결제 관련 에러 정의
enum PurchaseError: Error {
    case failedVerification
    case productNotFound
    case purchaseFailed
}

// 코인 상품 모델
struct CoinProduct: Identifiable {
    let id: String
    let coins: Int
    let price: String
    let displayName: String
}

@MainActor
class InAppPurchaseViewModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var purchasedProducts: Set<String> = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var purchasingProductId: String? = nil // 현재 구매 중인 상품 ID
    
    // 사용자 ID를 받기 위한 프로퍼티 추가
    private var userId: String?
    
    // 코인 상품 ID들 (App Store Connect에서 설정한 실제 Product ID)
    private let productIds = [
        "hau_product_22",   // 100코인 (2,200원)
        "hau_product_66",   // 315코인 (6,600원) - 300코인 + 5% 보너스
        "hau_product_154",  // 770코인 (15,400원) - 700코인 + 10% 보너스
        "hau_product_330",  // 1,725코인 (33,000원) - 1500코인 + 15% 보너스
        "hau_product_990"   // 5,400코인 (99,000원) - 4500코인 + 20% 보너스
    ]
    
    private var updateListenerTask: Task<Void, Error>? = nil
    
    init() {
        // 거래 업데이트 리스너 시작
        updateListenerTask = listenForTransactions()
        
        Task {
            await requestProducts()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // 상품 정보 요청
    func requestProducts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let products = try await Product.products(for: productIds)
            self.products = products.sorted { $0.price < $1.price }
        } catch {
            print("상품 정보 요청 실패: \(error)")
            errorMessage = "상품 정보를 불러올 수 없습니다."
        }
        
        isLoading = false
    }
    
    // 상품 구매 - presentation context 개선
    func purchase(_ product: Product) async -> Bool {
        guard purchasingProductId == nil else { 
            print("⚠️ 다른 상품 구매 중이므로 새 구매 요청 차단")
            return false 
        }
        
        purchasingProductId = product.id // 현재 구매 중인 상품 설정
        errorMessage = nil
        
        do {
            // iPad에서 presentation context 문제 해결을 위한 옵션 설정
            let result: Product.PurchaseResult
            
            // iOS 15.0 이상에서 presentation context 설정
            if #available(iOS 15.0, *) {
                // 현재 활성화된 윈도우 씬에서 구매 시트 표시
                if let windowScene = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .first(where: { $0.activationState == .foregroundActive }) {
                    
                    result = try await product.purchase(confirmIn: windowScene)
                } else {
                    // fallback: 기본 구매 방식
                    result = try await product.purchase()
                }
            } else {
                result = try await product.purchase()
            }
            
            switch result {
            case .success(let verification):
                // 거래 검증
                let transaction = try checkVerified(verification)
                
                // 코인 지급 처리
                let success = await processCoinsForProduct(product, transaction: transaction)
                
                // 거래 완료 처리
                await transaction.finish()
                
                if success {
                    purchasedProducts.insert(product.id)
                    purchasingProductId = nil
                    return true
                } else {
                    purchasingProductId = nil
                    return false
                }
                
            case .userCancelled:
                // 구매 취소는 정상적인 사용자 행동이므로 에러 메시지를 표시하지 않음
                print("사용자가 구매를 취소했습니다.")
                purchasingProductId = nil
                return false
                
            case .pending:
                errorMessage = "구매 승인을 기다리고 있습니다."
                purchasingProductId = nil
                return false
                
            @unknown default:
                errorMessage = "구매 처리 중 오류가 발생했습니다."
                purchasingProductId = nil
                return false
            }
            
        } catch {
            print("💥 구매 실패: \(error)")
            
            // 더 구체적인 에러 메시지 제공
            if let storeKitError = error as? StoreKitError {
                switch storeKitError {
                case .userCancelled:
                    // 사용자 취소는 에러 메시지 표시하지 않음
                    break
                case .networkError:
                    errorMessage = "네트워크 연결을 확인해주세요."
                case .systemError:
                    errorMessage = "시스템 오류가 발생했습니다. 잠시 후 다시 시도해주세요."
                default:
                    errorMessage = "구매에 실패했습니다."
                }
            } else {
                errorMessage = "구매에 실패했습니다."
            }
            
            purchasingProductId = nil
            return false
        }
    }
    
    // 거래 검증
    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw PurchaseError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    // 상품별 코인 지급 처리
    private func processCoinsForProduct(_ product: Product, transaction: StoreKit.Transaction) async -> Bool {
        let coinAmount = getCoinAmountForProduct(product.id)
        
        // 영수증 검증을 통한 서버 코인 충전 요청
        return await verifyReceiptAndChargeCoins(
            product: product,
            transaction: transaction,
            coinAmount: coinAmount
        )
    }
    
    // 빌드 환경 감지 메서드 추가
    private func getBuildEnvironment() -> String {
        #if DEBUG
            return "development"
        #else
            if isTestFlight() {
                return "testflight"
            } else {
                return "appstore"
            }
        #endif
    }
    
    // TestFlight 감지 메서드 (복합 방법)
    private func isTestFlight() -> Bool {
        // 방법 1: Bundle Receipt 확인
        if let receiptURL = Bundle.main.appStoreReceiptURL,
           receiptURL.path.contains("sandboxReceipt") {
            return true
        }
        
        // 방법 2: Provisioning Profile 확인
        if Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") == nil {
            return true
        }
        
        return false
    }
    
    // StoreKit 2 Transaction 기반 코인 충전
    private func verifyReceiptAndChargeCoins(product: Product, transaction: StoreKit.Transaction, coinAmount: Int) async -> Bool {
        guard let userId = getCurrentUserId() else {
            errorMessage = "사용자 ID를 확인할 수 없습니다."
            print("사용자 ID를 확인할 수 없습니다.")
            return false
        }
        
        // Fastify 서버의 검증 엔드포인트 호출
        let serverURL = AppConfig.baseURL.replacingOccurrences(of: "/api/v1", with: "")
        guard let url = URL(string: "\(serverURL)/api/v1/coins/verify-and-charge") else {
            errorMessage = "서버 URL이 잘못되었습니다."
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 빌드 환경 감지
        let buildEnvironment = getBuildEnvironment()
        
        // StoreKit 2 Transaction 정보 전송
        let requestBody: [String: Any] = [
            "user_id": userId,
            "product_id": product.id,
            "transaction_id": String(transaction.id),
            "purchase_date": ISO8601DateFormatter().string(from: transaction.purchaseDate),
            "environment": transaction.environment.rawValue,
            "build_environment": buildEnvironment, // 클라이언트 빌드 환경 추가
            "verification_method": "storekit2_transaction" // 검증 방식 명시
        ]
        
        print("🔍 전송할 구매 정보:", requestBody)
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    // 응답 데이터 파싱
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let success = json["success"] as? Bool,
                       success {
                        print("✅ 코인 충전 성공: \(buildEnvironment) 환경")
                        return true
                    }
                }
                
                // 에러 응답 처리
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMsg = json["error"] as? String {
                    print("❌ 서버 오류: \(errorMsg)")
                    errorMessage = errorMsg
                } else {
                    errorMessage = "Transaction 검증을 통한 코인 충전에 실패했습니다."
                }
                
                if let responseData = String(data: data, encoding: .utf8) {
                    print("🔍 서버 응답 내용: \(responseData)")
                }
            }
            
            return false
            
        } catch {
            print("❌ Transaction 검증 서버 요청 실패: \(error)")
            errorMessage = "네트워크 오류로 Transaction 검증에 실패했습니다."
            return false
        }
    }
    
    // 상품 ID에 따른 코인 수량 반환
    private func getCoinAmountForProduct(_ productId: String) -> Int {
        switch productId {
        case "hau_product_22":
            return 100
        case "hau_product_66":
            return 315
        case "hau_product_154":
            return 770
        case "hau_product_330":
            return 1725
        case "hau_product_990":
            return 5400
        default:
            return 0
        }
    }
    
    // 현재 사용자 ID 가져오기
    private func getCurrentUserId() -> String? {
        return self.userId
    }
    
    // 거래 업데이트 리스너
    func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in StoreKit.Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)
                    
                    // 거래 상태에 따른 처리 - MainActor에서 실행
                    await MainActor.run {
                        // UI 네비게이션에 영향을 주지 않도록 백그라운드에서만 상태 업데이트
                        print("📱 백그라운드 거래 업데이트 감지: \(transaction.productID)")
                        // 현재 구매 중이 아닌 경우에만 업데이트 (중복 처리 방지)
                        if self.purchasingProductId == nil {
                            Task {
                                await self.updatePurchasedProducts()
                            }
                        }
                    }
                    
                    await transaction.finish()
                } catch {
                    print("거래 업데이트 처리 실패: \(error)")
                }
            }
        }
    }
    
    // 구매한 상품 목록 업데이트
    func updatePurchasedProducts() async {
        var purchased: Set<String> = []
        
        for await result in StoreKit.Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                purchased.insert(transaction.productID)
            } catch {
                print("구매 내역 확인 실패: \(error)")
            }
        }
        
        self.purchasedProducts = purchased
    }
    
    // 구매 복원
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
        } catch {
            print("구매 복원 실패: \(error)")
            errorMessage = "구매 복원에 실패했습니다."
        }
    }
    
    // 코인 상품 정보 반환
    func getCoinProductInfo(_ product: Product) -> CoinProduct {
        let coins = getCoinAmountForProduct(product.id)
        return CoinProduct(
            id: product.id,
            coins: coins,
            price: product.displayPrice,
            displayName: "\(coins)코인"
        )
    }
    
    // 사용자 ID 설정 메서드 추가
    func setUserId(_ id: String) {
        self.userId = id
    }
    
    // 특정 상품의 구매 중 상태 확인
    func isPurchasing(_ productId: String) -> Bool {
        return purchasingProductId == productId
    }
} 
