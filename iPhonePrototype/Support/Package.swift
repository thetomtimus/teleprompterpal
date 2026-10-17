// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PrototypeSupport",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [.library(name: "PrototypeSupport", targets: ["PrototypeSupport"])],
    targets: [
        .target(name: "PrototypeSupport"),
        .testTarget(name: "PrototypeSupportTests", dependencies: ["PrototypeSupport"]),
    ],
    swiftLanguageModes: [.v6]
)
