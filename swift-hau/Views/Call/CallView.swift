import SwiftUI

struct CallView: View {
    @StateObject private var callManager = CallManager()

    var body: some View {
        Text("Call View Content")
            .onChange(of: callManager.shouldShowCallScreen) { oldValue, newValue in
                // shouldShowCallScreen이 false가 되면 화면을 닫음
                if !newValue {
                    print("CallView: shouldShowCallScreen이 false로 변경되어 화면을 닫습니다.")
                    // 약간의 지연을 두어 상태 변경이 완료되도록 함
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        dismiss()
                    }
                }
            }
    }

    private func dismiss() {
        // Implementation of dismiss function
    }
}

struct CallView_Previews: PreviewProvider {
    static var previews: some View {
        CallView()
    }
} 