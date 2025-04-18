//
//  Theme.swift
//  swift-hau
//
//  Created by Seonho Kim on 4/11/25.
//

import SwiftUI

struct AppTheme {
    struct Colors {
        static let primary = Color(hex: "#2C3930")
        static let secondary = Color(hex: "#3F4F44")
        static let tertiary = Color(hex: "#A27B5C")
        static let quaternary = Color(hex: "#DCD7C9")
        static let accent = Color(hex: "#26BF00")
        static let background = Color.white
        static let text = Color(hex: "#191F28")
        static let disabled = Color(hex: "#8B95A1")
        static let placeholder = Color(hex: "#B0B8C1")
        static let light = Color.white
        static let dark = Color(hex: "#191F28")
        static let lightTransparent = Color.white.opacity(0.6)
        static let secondaryLight = Color(hex: "#95BAA1").opacity(0.24)
        static let error = Color(hex: "#FF4500")
        static let warning = Color(hex: "#FFA500")
    }
    
    struct Gradients {
        static let primary = LinearGradient(
            gradient: Gradient(colors: [Colors.secondary, Colors.primary]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
