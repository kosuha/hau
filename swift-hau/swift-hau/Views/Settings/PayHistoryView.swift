import SwiftUI

struct PayHistoryView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var coinViewModel: CoinViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HeaderView(
                onPress: { dismiss() },
                title: "충전/이용 내역"
            )
            
            ScrollView {
                Text("최근 3개월까지 내역을 확인할 수 있어요.")
                    .font(.system(size: 16))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                
                if coinViewModel.isLoading {
                    // 로딩 상태
                    ProgressView()
                        .padding(.top, 50)
                } else if coinViewModel.transactions.isEmpty {
                    // 거래 내역이 없는 경우
                    VStack(spacing: 16) {
                        Text("거래 내역이 없습니다")
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.Colors.disabled)
                    }
                    .padding(.top, 50)
                } else {
                    // 거래 내역 표시
                    VStack(spacing: 0) {
                        ForEach(coinViewModel.transactions) { transaction in
                            PayHistoryItemView(
                                date: coinViewModel.formattedDate(transaction.createdAt),
                                type: coinViewModel.localizedTransactionType(transaction.transactionType),
                                amount: coinViewModel.formattedAmount(transaction.amount, type: transaction.transactionType),
                                isPositive: transaction.transactionType == "charge",
                                description: transaction.description
                            )
                        }
                    }
                    .padding(.top, 10)
                }
            }
            .refreshable {
                await coinViewModel.fetchTransactionHistory()
            }
        }
        .background(Color.white.edgesIgnoringSafeArea(.all))
        .navigationBarHidden(true)
        .onAppear {
            Task {
                await coinViewModel.fetchTransactionHistory()
            }
        }
    }
}

// 결제 내역 아이템 컴포넌트
struct PayHistoryItemView: View {
    let date: String
    let type: String
    let amount: String
    let isPositive: Bool
    let description: String

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text(date)
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.disabled)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(type)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(AppTheme.Colors.text)
                        
                        Text(description)
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.Colors.disabled)
                    }
                    Spacer()
                    
                    Text(amount)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(isPositive ? .green : AppTheme.Colors.text)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            
            // 구분선
            Divider()
                .background(AppTheme.Colors.disabled.opacity(0.3))
                .padding(.horizontal, 20)
        }
    }
}

struct PayHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        PayHistoryView()
    }
}
