import SwiftUI
import StoreKit

struct PayView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var coinViewModel: CoinViewModel
    @StateObject private var purchaseViewModel = InAppPurchaseViewModel()
    @State private var showPurchaseSuccessAlert = false
    @State private var purchasedCoinAmount = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HeaderView(
                onPress: { dismiss() },
                title: "나의 코인"
            )
            
            ScrollView {
                VStack(spacing: 32) {
                    // 보유 코인 섹션
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("보유 코인")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(AppTheme.Colors.text)
                            
                            Spacer()
                            
                            NavigationLink(destination: PayHistoryView().environmentObject(coinViewModel)) {
                                Text("충전/이용 내역")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppTheme.Colors.text)
                                    .underline()
                            }
                        }
                        
                        NavigationLink(destination: PayHistoryView().environmentObject(coinViewModel)) {
                            HStack {
                                Image(systemName: "diamond.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(AppTheme.Colors.text)
                                
                                Spacer()
                                
                                Text(coinViewModel.formattedBalance())
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(AppTheme.Colors.text)
                            }
                            .padding(.horizontal, 20)
                            .frame(height: 78)
                            .background(AppTheme.Colors.secondaryLight)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(AppTheme.Colors.secondary, lineWidth: 1)
                            )
                        }
                    }
                    
                    // 코인 구매하기 섹션
                    VStack(alignment: .leading, spacing: 16) {
                        Text("코인 구매하기")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppTheme.Colors.text)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("•")
                                    .foregroundColor(AppTheme.Colors.text)
                                Text("코인을 구매해서 하우와 통화할 수 있어요.")
                                    .font(.system(size: 16))
                                    .foregroundColor(AppTheme.Colors.text)
                            }
                            
                            HStack {
                                Text("•")
                                    .foregroundColor(AppTheme.Colors.text)
                                Text("코인은 통화시간에 따라 소모돼요.")
                                    .font(.system(size: 16))
                                    .foregroundColor(AppTheme.Colors.text)
                            }
                            
                            HStack {
                                Text("•")
                                    .foregroundColor(AppTheme.Colors.text)
                                Text("통화시간 10분미만은 1분에 10코인, 이후 10분마다 1분에 2코인씩 추가로 소모돼요. (10+2n코인/분)")
                                    .font(.system(size: 16))
                                    .foregroundColor(AppTheme.Colors.text)
                            }
                        }
                        
                        // 코인 옵션들 - 실제 상품과 연동
                        if purchaseViewModel.isLoading && purchaseViewModel.products.isEmpty {
                            VStack(spacing: 16) {
                                ProgressView()
                                Text("상품 정보를 불러오는 중...")
                                    .font(.system(size: 16))
                                    .foregroundColor(AppTheme.Colors.disabled)
                            }
                            .padding(.vertical, 40)
                        } else {
                        VStack(spacing: 12) {
                                // App Store Connect 상품과 UI 매칭
                                ForEach(getDisplayProducts(), id: \.id) { displayProduct in
                                    CoinOptionView(
                                        coins: displayProduct.baseCoins,
                                        bonus: displayProduct.bonusInfo,
                                        price: displayProduct.price,
                                        isLoading: purchaseViewModel.isPurchasing(displayProduct.id),
                                        isAnyPurchasing: purchaseViewModel.purchasingProductId != nil,
                                        onPurchase: {
                                            if let product = displayProduct.storeProduct {
                                                Task {
                                                    let success = await purchaseViewModel.purchase(product)
                                                    if success {
                                                        // 구매 성공 시 코인 수량 저장하고 성공 알림 표시
                                                        purchasedCoinAmount = getCoinAmountForProduct(product.id)
                                                        showPurchaseSuccessAlert = true
                                                        
                                                        // 코인 잔액 새로고침 (UI 네비게이션에 영향 주지 않음)
                                                        await coinViewModel.fetchCoinBalance()
                                                    }
                                                    // 구매 실패나 취소 시에는 별도 처리 없이 현재 화면 유지
                                                }
                                            }
                                        }
                                    )
                                }
                            }
                        }
                    }
                    
                    // 유의사항 섹션
                    VStack(alignment: .leading, spacing: 12) {
                        Text("유의사항")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(AppTheme.Colors.text)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .center) {
                                Text("•")
                                    .foregroundColor(AppTheme.Colors.text)
                                Text("결제 금액에는 VAT가 포함되어 있습니다.")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppTheme.Colors.text)
                            }
                            HStack(alignment: .center) {
                                Text("•")
                                    .foregroundColor(AppTheme.Colors.text)
                                Text("결제 완료 후 즉시 코인이 충전됩니다.")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppTheme.Colors.text)
                            }
                            HStack(alignment: .center) {
                                Text("•")
                                    .foregroundColor(AppTheme.Colors.text)
                                Text("직접 구매한 코인에 대해서만 환불이 가능합니다.")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppTheme.Colors.text)
                            }
                            HStack(alignment: .center) {
                                Text("•")
                                    .foregroundColor(AppTheme.Colors.text)
                                Text("코인 사용 시 환불이 불가능합니다.")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppTheme.Colors.text)
                            }
                            HStack(alignment: .center) {
                                Text("•")
                                    .foregroundColor(AppTheme.Colors.text)
                                Text("구매한 상품은 결제일로부터 1년이내에만 사용할 수 있습니다.")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppTheme.Colors.text)
                            }
                            HStack(alignment: .center) {
                                Text("•")
                                    .foregroundColor(AppTheme.Colors.text)
                                Text("미성년자의 이용은 제한됩니다.")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppTheme.Colors.text)
                            }
                            HStack(alignment: .center) {
                                Text("•")
                                    .foregroundColor(AppTheme.Colors.text)
                                Text("AI의 품질에 대한 불만족 등 주관적인 기준에 따른 환불은 불가능합니다.")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppTheme.Colors.text)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 16)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
        }
        .alert("오류", isPresented: .constant(purchaseViewModel.errorMessage != nil), actions: {
            Button("확인") {
                purchaseViewModel.errorMessage = nil
            }
        }, message: {
            Text(purchaseViewModel.errorMessage ?? "")
        })
        .alert("구매 완료", isPresented: $showPurchaseSuccessAlert, actions: {
            Button("확인") {
                showPurchaseSuccessAlert = false
            }
        }, message: {
            Text("\(purchasedCoinAmount)코인이 충전되었습니다!")
        })
        .background(Color.white.edgesIgnoringSafeArea(.all))
        .navigationBarHidden(true)
        .onAppear {
            Task {
                // 사용자 ID를 InAppPurchaseViewModel에 설정
                if let userId = coinViewModel.userId {
                    purchaseViewModel.setUserId(userId)
                }
                
                await coinViewModel.fetchCoinBalance()
                await purchaseViewModel.requestProducts()
            }
        }
        .refreshable {
            await coinViewModel.fetchCoinBalance()
            await purchaseViewModel.requestProducts()
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
    
    // 표시용 상품 정보
    private func getDisplayProducts() -> [DisplayProduct] {
        let staticProducts = [
            DisplayProduct(id: "hau_product_22", baseCoins: 100, bonusInfo: nil, price: "2,200원", storeProduct: nil),
            DisplayProduct(id: "hau_product_66", baseCoins: 300, bonusInfo: (15, "5% Bonus"), price: "6,600원", storeProduct: nil),
            DisplayProduct(id: "hau_product_154", baseCoins: 700, bonusInfo: (70, "10% Bonus"), price: "15,400원", storeProduct: nil),
            DisplayProduct(id: "hau_product_330", baseCoins: 1500, bonusInfo: (225, "15% Bonus"), price: "33,000원", storeProduct: nil),
            DisplayProduct(id: "hau_product_990", baseCoins: 4500, bonusInfo: (900, "20% Bonus"), price: "99,000원", storeProduct: nil)
        ]
        
        // Store 상품과 매칭
        return staticProducts.map { displayProduct in
            let storeProduct = purchaseViewModel.products.first { $0.id == displayProduct.id }
            return DisplayProduct(
                id: displayProduct.id,
                baseCoins: displayProduct.baseCoins,
                bonusInfo: displayProduct.bonusInfo,
                price: storeProduct?.displayPrice ?? displayProduct.price,
                storeProduct: storeProduct
            )
        }
    }
}

// 표시용 상품 모델
struct DisplayProduct {
    let id: String
    let baseCoins: Int
    let bonusInfo: (Int, String)?
    let price: String
    let storeProduct: Product?
}

// 코인 옵션 컴포넌트
struct CoinOptionView: View {
    let coins: Int
    let bonus: (Int, String)?
    let price: String
    let isLoading: Bool
    let isAnyPurchasing: Bool
    let onPurchase: () -> Void
    
    var body: some View {
        Button(action: onPurchase) {
            HStack {
                Image(systemName: "diamond.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(isLoading ? AppTheme.Colors.disabled : AppTheme.Colors.text)
                
                Text("\(coins)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(isLoading ? AppTheme.Colors.disabled : AppTheme.Colors.text)
                
                if let bonus = bonus {
                    VStack(alignment: .center, spacing: 4) {
                        Text("+\(bonus.0) 보너스")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(isLoading ? AppTheme.Colors.disabled : Color(hex: "FF7700"))
                    }
                }
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 80, height: 30)
                } else {
                Text(price)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 80, height: 30)
                    .background(AppTheme.Colors.secondary)
                    .cornerRadius(5)
                    .fixedSize()
                }
            }
            .padding(.horizontal, 20)
            .frame(height: 70)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isLoading ? AppTheme.Colors.disabled : AppTheme.Colors.secondary, lineWidth: 1)
            )
        }
        .disabled(isLoading || isAnyPurchasing)
    }
}

struct PayView_Previews: PreviewProvider {
    static var previews: some View {
        PayView()
    }
}
