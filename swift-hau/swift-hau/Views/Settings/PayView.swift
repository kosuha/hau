import SwiftUI

struct PayView: View {
    @Environment(\.dismiss) var dismiss
    
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
                            
                            NavigationLink(destination: PayHistoryView()) {
                                Text("충전/이용 내역")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppTheme.Colors.text)
                                    .underline()
                            }
                        }
                        
                        NavigationLink(destination: PayHistoryView()) {
                            HStack {
                                Image(systemName: "diamond.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(AppTheme.Colors.text)
                                
                                Spacer()
                                
                                Text("1,500")
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
                                Text("통화시간 1분에 10코인이 필요해요.")
                                    .font(.system(size: 16))
                                    .foregroundColor(AppTheme.Colors.text)
                            }
                        }
                        
                        // 코인 옵션들
                        VStack(spacing: 12) {
                            CoinOptionView(coins: 100, bonus: nil, price: "2,200원")
                            CoinOptionView(coins: 300, bonus: (15, "5% Bonus"), price: "6,600원")
                            CoinOptionView(coins: 700, bonus: (70, "10% Bonus"), price: "15,400원")
                            CoinOptionView(coins: 1500, bonus: (225, "15% Bonus"), price: "33,000원")
                            CoinOptionView(coins: 4500, bonus: (900, "20% Bonus"), price: "99,000원")
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
        .background(Color.white.edgesIgnoringSafeArea(.all))
        .navigationBarHidden(true)
    }
}

// 코인 옵션 컴포넌트
struct CoinOptionView: View {
    let coins: Int
    let bonus: (Int, String)?
    let price: String
    
    var body: some View {
        Button(action: {
            // 구매 액션
        }) {
            HStack {
                Image(systemName: "diamond.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(AppTheme.Colors.text)
                
                Text("\(coins)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppTheme.Colors.text)
                
                if let bonus = bonus {
                    VStack(alignment: .center, spacing: 4) {
                        // Text("\(bonus.1)")
                        //     .font(.system(size: 12, weight: .semibold))
                        //     .foregroundColor(Color(hex: "FF7700"))
                        //     .padding(.horizontal, 8)
                        //     .padding(.vertical, 4)
                        //     .cornerRadius(12)
                        //     .overlay(
                        //         RoundedRectangle(cornerRadius: 12)
                        //             .stroke(Color(hex: "FF7700"), lineWidth: 1)
                        //     )

                        Text("+\(bonus.0) 보너스")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(hex: "FF7700"))
                    }
                }
                
                Spacer()
                
                Text(price)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 80, height: 30)
                    .background(AppTheme.Colors.secondary)
                    .cornerRadius(5)
                    .fixedSize()
            }
            .padding(.horizontal, 20)
            .frame(height: 70)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppTheme.Colors.secondary, lineWidth: 1)
            )
        }
    }
}

struct PayView_Previews: PreviewProvider {
    static var previews: some View {
        PayView()
    }
}
