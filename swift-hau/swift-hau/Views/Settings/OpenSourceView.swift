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
            version: "iOS 13.0+",
            license: "Apple SDK License Agreement",
            description: "Apple의 선언적 UI 프레임워크로, iOS 앱의 사용자 인터페이스를 구축하는 데 사용됩니다."
        ),
        LibraryInfo(
            name: "Alamofire",
            version: "5.6.4",
            license: "MIT License",
            description: "Swift 기반 HTTP 네트워킹 라이브러리로, 네트워크 요청을 쉽게 처리할 수 있게 해줍니다."
        ),
        LibraryInfo(
            name: "Kingfisher",
            version: "7.6.2",
            license: "MIT License",
            description: "이미지 다운로드 및 캐싱 라이브러리로, 웹에서 이미지를 가져와 표시하는 데 사용됩니다."
        ),
        LibraryInfo(
            name: "SwiftyJSON",
            version: "5.0.1",
            license: "MIT License",
            description: "Swift에서 JSON 데이터를 쉽게 처리할 수 있게 해주는 라이브러리입니다."
        ),
        LibraryInfo(
            name: "SnapKit",
            version: "5.6.0",
            license: "MIT License",
            description: "Swift용 Auto Layout DSL로, 코드로 제약 조건을 쉽게 정의할 수 있게 해줍니다."
        ),
        LibraryInfo(
            name: "Lottie",
            version: "4.2.0",
            license: "Apache License 2.0",
            description: "Adobe After Effects 애니메이션을 iOS 앱에서 렌더링할 수 있게 해주는 라이브러리입니다."
        ),
        LibraryInfo(
            name: "Firebase",
            version: "10.7.0",
            license: "Apache License 2.0",
            description: "Google의 모바일 및 웹 애플리케이션 개발 플랫폼으로, 다양한 백엔드 서비스를 제공합니다."
        ),
        LibraryInfo(
            name: "Realm",
            version: "10.38.0",
            license: "Apache License 2.0",
            description: "모바일 데이터베이스 라이브러리로, 로컬 데이터를 저장하고 관리하는 데 사용됩니다."
        )
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HeaderView(
                onPress: { dismiss() },
                title: "오픈소스 라이브러리"
            )
            
            // 라이브러리 목록
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(libraries) { library in
                        LibraryCard(library: library)
                    }
                }
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
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 라이브러리 이름 및 버전
            HStack {
                Text(library.name)
                    .font(.system(size: 18, weight: .bold))
                
                Spacer()
                
                Text(library.version)
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.secondary)
            }
            
            // 라이센스 정보
            Text(library.license)
                .font(.system(size: 14))
                .foregroundColor(AppTheme.Colors.secondary)
            
            // 설명 (접었다 펼칠 수 있음)
            if isExpanded {
                Text(library.description)
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.text)
                    .padding(.top, 4)
            }
            
            // 더보기/접기 버튼
            Button(action: {
                withAnimation {
                    isExpanded.toggle()
                }
            }) {
                Text(isExpanded ? "접기" : "더보기")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.primary)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(AppTheme.Colors.secondaryLight)
        .cornerRadius(12)
    }
}

// 미리보기
struct OpenSourceView_Previews: PreviewProvider {
    static var previews: some View {
        OpenSourceView()
    }
}
