import SwiftUI

struct PayView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HeaderView(
                onPress: { dismiss() },
                title: ""
            )
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("무료 플랜")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppTheme.Colors.text)
                    Text("매월 약 1,300원 상당의 무료 통화시간 제공")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.Colors.text)
                    Text("(매월 1일 초기화)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.Colors.text)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .background(Color.white.edgesIgnoringSafeArea(.all))
        .navigationBarHidden(true)
    }
}

struct PayView_Previews: PreviewProvider {
    static var previews: some View {
        PayView()
    }
}
