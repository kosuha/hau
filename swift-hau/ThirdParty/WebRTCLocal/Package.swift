// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "WebRTCLocal",
    platforms: [.iOS(.v13)],
    products: [
        .library(name: "WebRTC", targets: ["WebRTC"])
    ],
    targets: [
        .binaryTarget(
            name: "WebRTC",
            path: "WebRTC.xcframework"
        )
    ]
)
