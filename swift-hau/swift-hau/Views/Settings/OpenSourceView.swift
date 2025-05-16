//
//  OpenSourceView.swift
//  swift-hau
//
//  Created by Seonho Kim on 4/11/25.
//

import SwiftUI

struct OpenSourceView: View {
    @Environment(\.dismiss) var dismiss
    
    // 오픈소스 라이브러리 목록
    private let libraries: [LibraryInfo] = [
        LibraryInfo(
            name: "SwiftUI",
            version: "",
            license: "",
            description: ""
        ),
        LibraryInfo(
            name: "Supabase",
            version: "",
            license: "",
            description: ""
        ),
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HeaderView(
                onPress: { dismiss() },
                title: "라이선스"
            )
            
            // 라이브러리 목록
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(libraries) { library in
                        LibraryCard(library: library)
                    }
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

// 라이브러리 정보 모델
struct LibraryInfo: Identifiable {
    let id = UUID()
    let name: String
    let version: String
    let license: String
    let description: String
}

// 라이브러리 카드 컴포넌트
struct LibraryCard: View {
    var library: LibraryInfo
    
    var body: some View {
        Text(library.name)
            .font(.system(size: 18, weight: .medium))
            .padding(.vertical, 8) // 이름 위아래 간격 추가
    }
}

// 미리보기
struct OpenSourceView_Previews: PreviewProvider {
    static var previews: some View {
        OpenSourceView()
    }
}
