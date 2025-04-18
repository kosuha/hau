//
//  HeaderView.swift
//  swift-hau
//
//  Created by Seonho Kim on 4/11/25.
//

import SwiftUI

struct HeaderView: View {
    var onPress: (() -> Void)?
    var title: String?
    var isClose: Bool = false
    var isRightButton: Bool = false
    var rightButtonImage: String = "ellipsis"
    var rightButtonAction: (() -> Void)?
    
    var body: some View {
        ZStack {
            // 중앙 제목
            if let title = title {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            
            // 양쪽 버튼 배치
            HStack {
                // 왼쪽 버튼
                if let onPress = onPress {
                    Button(action: onPress) {
                        Image(systemName: isClose ? "xmark" : "chevron.left")
                            .font(.system(size: 24))
                            .foregroundColor(.black)
                    }
                } else {
                    // 왼쪽 버튼이 없을 때 공간 유지
                    Spacer().frame(width: 24)
                }
                
                Spacer()
                
                // 오른쪽 버튼
                if isRightButton {
                    Button(action: rightButtonAction ?? {}) {
                        Image(systemName: rightButtonImage)
                            .font(.system(size: 24))
                            .foregroundColor(.black)
                    }
                } else {
                    // 오른쪽 버튼이 없을 때 공간 유지
                    Spacer().frame(width: 24)
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 60)
        .frame(maxWidth: .infinity)
    }
}

// 미리보기
struct HeaderView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // 뒤로가기 버튼이 있는 헤더
            HeaderView(
                onPress: {},
                title: "헤더 제목"
            )
            .previewLayout(.sizeThatFits)
            .padding()
            .previewDisplayName("뒤로가기 버튼이 있는 헤더")
            
            // 닫기 버튼이 있는 헤더
            HeaderView(
                onPress: {},
                title: "헤더 제목",
                isClose: true
            )
            .previewLayout(.sizeThatFits)
            .padding()
            .previewDisplayName("닫기 버튼이 있는 헤더")
            
            // 제목만 있는 헤더
            HeaderView(
                title: "제목만 있는 헤더"
            )
            .previewLayout(.sizeThatFits)
            .padding()
            .previewDisplayName("제목만 있는 헤더")
            
            // 버튼만 있는 헤더
            HeaderView(
                onPress: {}
            )
            .previewLayout(.sizeThatFits)
            .padding()
            .previewDisplayName("버튼만 있는 헤더")
        }
    }
}
