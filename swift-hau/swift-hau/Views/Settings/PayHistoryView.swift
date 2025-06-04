import SwiftUI

struct PayHistoryView: View {
    @Environment(\.dismiss) var dismiss
    
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
                VStack(spacing: 0) {
                    // 충전 내역
                    PayHistoryItemView(
                        date: "2025.06.30",
                        type: "충전",
                        amount: "+315",
                        isPositive: true
                    )
                    
                    // 사용 내역들
                    PayHistoryItemView(
                        date: "2025.06.30", 
                        type: "사용",
                        amount: "-50",
                        isPositive: false
                    )
                    
                    PayHistoryItemView(
                        date: "2025.06.30",
                        type: "사용", 
                        amount: "-50",
                        isPositive: false
                    )
                    
                    PayHistoryItemView(
                        date: "2025.06.30",
                        type: "사용",
                        amount: "-50", 
                        isPositive: false
                    )
                }
                .padding(.top, 10)
            }
        }
        .background(Color.white.edgesIgnoringSafeArea(.all))
        .navigationBarHidden(true)
    }
}

// 결제 내역 아이템 컴포넌트
struct PayHistoryItemView: View {
    let date: String
    let type: String
    let amount: String
    let isPositive: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text(date)
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.Colors.disabled)
                
                HStack {
                    Text(type)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppTheme.Colors.text)
                    
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
