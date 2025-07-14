import SwiftUI
import StoreKit

struct PayView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var coinViewModel: CoinViewModel
    @EnvironmentObject var purchaseViewModel: InAppPurchaseViewModel
    @State private var showPurchaseSuccessAlert = false
    @State private var purchasedCoinAmount = 0
    @State private var showCallRateGuideSheet = false
    @State private var showProductUnavailableAlert = false
    
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
                                AppTheme.Coin.coinIcon
                                    .font(.system(size: 24))
                                
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
                            HStack(alignment: .top) {
                                Text("•")
                                    .foregroundColor(AppTheme.Colors.text)
                                Text("코인을 구매해서 하우와 통화할 수 있어요.")
                                    .font(.system(size: 16))
                                    .foregroundColor(AppTheme.Colors.text)
                            }

                            HStack(alignment: .top) {
                                Text("•")
                                    .foregroundColor(AppTheme.Colors.text)
                                Text("한 번에 최대 20분까지 통화할 수 있어요.")
                                    .font(.system(size: 16))
                                    .foregroundColor(AppTheme.Colors.text)
                            }
                        }

                        VStack(alignment: .trailing, spacing: 8) {
                            Button(action: {
                                // 통화시간당 요금 안내 바텀모달시트 표시
                                showCallRateGuideSheet = true
                            }) {
                                Text("통화시간당 요금 안내")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppTheme.Colors.text)
                                    .underline()
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)

                        
                        
                        
                        // 코인 옵션들 - 실제 상품과 연동
                        if purchaseViewModel.isLoading && purchaseViewModel.products.isEmpty {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                Text("상품 정보를 불러오는 중...")
                                    .font(.system(size: 16))
                                    .foregroundColor(AppTheme.Colors.disabled)
                            }
                            .padding(.vertical, 40)
                        } else if purchaseViewModel.products.isEmpty && !purchaseViewModel.isLoading {
                            // 상품 로드 완료했지만 상품이 없는 경우
                            VStack(spacing: 16) {
                                Image(systemName: "clock")
                                    .font(.system(size: 32))
                                    .foregroundColor(AppTheme.Colors.disabled)
                                Text("인앱구매 준비 중")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(AppTheme.Colors.text)
                                Text("Apple 심사가 진행 중입니다.\n곧 구매하실 수 있습니다.")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppTheme.Colors.disabled)
                                    .multilineTextAlignment(.center)
                                
                                Button("다시 확인") {
                                    Task {
                                        await purchaseViewModel.requestProducts()
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(AppTheme.Colors.secondary)
                                .foregroundColor(.white)
                                .cornerRadius(8)
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
                                        isProductAvailable: displayProduct.storeProduct != nil,
                                        onPurchase: {
                                            print("🎯 PayView: 구매 버튼 클릭됨 - 상품 ID: \(displayProduct.id)")
                                            
                                            if let product = displayProduct.storeProduct {
                                                print("✅ PayView: StoreKit 상품 찾음 - \(product.id)")
                                                Task {
                                                    print("🚀 PayView: 구매 프로세스 시작")
                                                    let success = await purchaseViewModel.purchase(product)
                                                    print("📊 PayView: 구매 결과 - \(success)")
                                                    
                                                    if success {
                                                        // 구매 성공 시 햅틱 피드백
                                                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                                        impactFeedback.impactOccurred()
                                                        
                                                        // 구매 성공 시 코인 수량 저장하고 성공 알림 표시
                                                        purchasedCoinAmount = getCoinAmountForProduct(product.id)
                                                        showPurchaseSuccessAlert = true
                                                        
                                                        // 코인 잔액 새로고침 (UI 네비게이션에 영향 주지 않음)
                                                        await coinViewModel.fetchCoinBalance()
                                                    }
                                                    // 구매 실패나 취소 시에는 별도 처리 없이 현재 화면 유지
                                                }
                                            } else {
                                                print("❌ PayView: StoreKit 상품을 찾을 수 없음 - \(displayProduct.id)")
                                                showProductUnavailableAlert = true
                                            }
                                        }
                                    )
                                }
                            }
                        }
                    }
                    
                    // 유의사항 섹션
                    VStack(alignment: .leading, spacing: 16) {
                        Text("유의사항")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppTheme.Colors.text)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(noticeItems, id: \.self) { item in
                                HStack(alignment: .top) {
                                    Text("•")
                                        .foregroundColor(AppTheme.Colors.text)
                                    Text(item)
                                        .font(.system(size: 16))
                                        .foregroundColor(AppTheme.Colors.text)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

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
        .alert("구매 준비 중", isPresented: $showProductUnavailableAlert, actions: {
            Button("확인") {
                showProductUnavailableAlert = false
            }
        }, message: {
            Text("인앱구매 상품이 Apple 심사 중입니다.\n곧 구매하실 수 있습니다.")
        })
        .background(Color.white.edgesIgnoringSafeArea(.all))
        .navigationBarHidden(true)
        .onAppear {
            Task {
                await coinViewModel.fetchCoinBalance()
                await purchaseViewModel.requestProducts()
            }
        }
        .refreshable {
            await coinViewModel.fetchCoinBalance()
            await purchaseViewModel.requestProducts()
        }
        .sheet(isPresented: $showCallRateGuideSheet) {
            CallRateGuideSheet()
                .presentationDetents([.height(500)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(32)
        }
    }
    
    // 유의사항 목록
    private let noticeItems = [
        "결제 금액에는 VAT가 포함되어 있습니다.",
        "결제 완료 후 즉시 코인이 충전됩니다.",
        "직접 구매한 코인에 대해서만 환불이 가능합니다.",
        "구매 후 미사용 코인에 대해서만 결제일로부터 7일 이내에 환불이 가능합니다.",
        "미성년자의 이용은 제한됩니다.",
        "AI의 품질에 대한 불만족 등 주관적인 기준에 따른 환불은 불가능합니다."
    ]
    
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
    let isProductAvailable: Bool
    let onPurchase: () -> Void
    
    var body: some View {
        Button(action: onPurchase) {
            HStack {
                AppTheme.Coin.coinIcon
                    .font(.system(size: 24))
                    .foregroundColor(isLoading ? AppTheme.Colors.disabled : AppTheme.Colors.coin)
                
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
                    HStack(spacing: 8) {
                        Text("구매 중...")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Colors.disabled)
                    }
                    .frame(width: 80, height: 30)
                } else if !isProductAvailable {
                    Text("사용 불가")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.disabled)
                        .frame(width: 80, height: 30)
                        .background(AppTheme.Colors.secondaryLight)
                        .cornerRadius(5)
                        .fixedSize()
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
            .background(isLoading ? AppTheme.Colors.secondaryLight.opacity(0.5) : Color.clear)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isLoading ? AppTheme.Colors.disabled : AppTheme.Colors.secondary, lineWidth: 1)
            )
        }
        .disabled(!isProductAvailable || isLoading || isAnyPurchasing)
        .opacity((!isProductAvailable || isLoading || isAnyPurchasing) ? 0.6 : 1.0)
    }
}

// 통화시간당 요금 안내 바텀 모달 시트
struct CallRateGuideSheet: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // 드래그 인디케이터 공간
            Rectangle()
                .fill(Color.clear)
                .frame(width: 100, height: 8)
            
            // 제목
            VStack(alignment: .leading, spacing: 8) {
                Text("통화시간당 요금 안내")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.text)
                    .padding(.top, 32)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 설명 텍스트
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top) {
                            Text("•")
                                .foregroundColor(AppTheme.Colors.text)
                            Text("HAU의 코인은 통화시간에 따라 차감되며, 통화시간이 길어질수록 코인이 더 많이 사용돼요.")
                                .font(.system(size: 16))
                                .foregroundColor(AppTheme.Colors.text)
                        }
                        
                        HStack(alignment: .top) {
                            Text("•")
                                .foregroundColor(AppTheme.Colors.text)
                            Text("통화는 10분까지는 1분당 10코인이 사용되며, 20분까지는 1분당 12코인이 사용돼요.")
                                .font(.system(size: 16))
                                .foregroundColor(AppTheme.Colors.text)
                        }
                    }
                    
                    // 요금 표
                    VStack(spacing: 0) {
                        // 테이블 헤더
                        HStack(spacing: 0) {
                            Text("통화시간")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(AppTheme.Colors.text)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 8)
                                .overlay(
                                    Rectangle()
                                        .fill(Color(hex: "E0E0E0"))
                                        .frame(width: 1),
                                    alignment: .trailing
                                )
                            
                            Text("코인")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(AppTheme.Colors.text)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 8)
                                .overlay(
                                    Rectangle()
                                        .fill(Color(hex: "E0E0E0"))
                                        .frame(width: 1),
                                    alignment: .trailing
                                )
                            
                            Text("분당 요금")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(AppTheme.Colors.text)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 8)
                        }
                        .background(AppTheme.Colors.secondaryLight)
                        
                        // 테이블 행들 - 진짜 셀 병합
                        VStack(spacing: 0) {
                            // 첫 번째 그룹 (1분당 10코인) - 실제 셀 병합
                            HStack(spacing: 0) {
                                // 통화시간 열
                                VStack(spacing: 0) {
                                    Text("5분")
                                        .font(.system(size: 14))
                                        .foregroundColor(AppTheme.Colors.text)
                                        .frame(height: 32)
                                        .frame(maxWidth: .infinity)
                                        .overlay(
                                            Rectangle()
                                                .fill(Color(hex: "E0E0E0"))
                                                .frame(height: 1),
                                            alignment: .bottom
                                        )
                                    
                                    Text("10분")
                                        .font(.system(size: 14))
                                        .foregroundColor(AppTheme.Colors.text)
                                        .frame(height: 32)
                                        .frame(maxWidth: .infinity)
                                        .overlay(
                                            Rectangle()
                                                .fill(Color(hex: "E0E0E0"))
                                                .frame(height: 1),
                                            alignment: .bottom
                                        )
                                }
                                .overlay(
                                    Rectangle()
                                        .fill(Color(hex: "E0E0E0"))
                                        .frame(width: 1),
                                    alignment: .trailing
                                )
                                
                                // 코인 열
                                VStack(spacing: 0) {
                                    Text("50코인")
                                        .font(.system(size: 14))
                                        .foregroundColor(AppTheme.Colors.text)
                                        .frame(height: 32)
                                        .frame(maxWidth: .infinity)
                                        .overlay(
                                            Rectangle()
                                                .fill(Color(hex: "E0E0E0"))
                                                .frame(height: 1),
                                            alignment: .bottom
                                        )
                                    
                                    Text("100코인")
                                        .font(.system(size: 14))
                                        .foregroundColor(AppTheme.Colors.text)
                                        .frame(height: 32)
                                        .frame(maxWidth: .infinity)
                                        .overlay(
                                            Rectangle()
                                                .fill(Color(hex: "E0E0E0"))
                                                .frame(height: 1),
                                            alignment: .bottom
                                        )
                                }
                                .overlay(
                                    Rectangle()
                                        .fill(Color(hex: "E0E0E0"))
                                        .frame(width: 1),
                                    alignment: .trailing
                                )
                                
                                // 병합된 분당 요금 열 (두 행 높이)
                                Text("1분당 10코인")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppTheme.Colors.text)
                                    .frame(height: 64) // 32 + 32
                                    .frame(maxWidth: .infinity)
                                    .overlay(
                                        Rectangle()
                                            .fill(Color(hex: "E0E0E0"))
                                            .frame(height: 1),
                                        alignment: .bottom
                                    )
                            }
                            
                            // 두 번째 그룹 (1분당 12코인) - 실제 셀 병합
                            HStack(spacing: 0) {
                                // 통화시간 열
                                VStack(spacing: 0) {
                                    Text("15분")
                                        .font(.system(size: 14))
                                        .foregroundColor(AppTheme.Colors.text)
                                        .frame(height: 32)
                                        .frame(maxWidth: .infinity)
                                        .overlay(
                                            Rectangle()
                                                .fill(Color(hex: "E0E0E0"))
                                                .frame(height: 1),
                                            alignment: .bottom
                                        )
                                    
                                    Text("20분")
                                        .font(.system(size: 14))
                                        .foregroundColor(AppTheme.Colors.text)
                                        .frame(height: 32)
                                        .frame(maxWidth: .infinity)
                                }
                                .overlay(
                                    Rectangle()
                                        .fill(Color(hex: "E0E0E0"))
                                        .frame(width: 1),
                                    alignment: .trailing
                                )
                                
                                // 코인 열
                                VStack(spacing: 0) {
                                    Text("160코인")
                                        .font(.system(size: 14))
                                        .foregroundColor(AppTheme.Colors.text)
                                        .frame(height: 32)
                                        .frame(maxWidth: .infinity)
                                        .overlay(
                                            Rectangle()
                                                .fill(Color(hex: "E0E0E0"))
                                                .frame(height: 1),
                                            alignment: .bottom
                                        )
                                    
                                    Text("220코인")
                                        .font(.system(size: 14))
                                        .foregroundColor(AppTheme.Colors.text)
                                        .frame(height: 32)
                                        .frame(maxWidth: .infinity)
                                }
                                .overlay(
                                    Rectangle()
                                        .fill(Color(hex: "E0E0E0"))
                                        .frame(width: 1),
                                    alignment: .trailing
                                )
                                
                                // 병합된 분당 요금 열 (두 행 높이)
                                Text("1분당 12코인")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppTheme.Colors.text)
                                    .frame(height: 64) // 32 + 32
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(hex: "E0E0E0"), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }
            
            // 확인 버튼
            Button(action: {
                dismiss()
            }) {
                Text("확인")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.light)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(AppTheme.Colors.secondary)
                    .cornerRadius(99)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color.white)
    }
}

struct PayView_Previews: PreviewProvider {
    static var previews: some View {
        PayView()
            .environmentObject(InAppPurchaseViewModel())
            .environmentObject(CoinViewModel())
    }
}
