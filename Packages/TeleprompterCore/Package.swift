// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TeleprompterCore",
    platforms: [.macOS(.v14), .iOS(.v18)],
    products: [
        .library(name: "TeleprompterCore", targets: ["TeleprompterCore"]),
        .library(name: "PromptingCore", targets: ["PromptingCore"])
    ],
    targets: [
        .target(name: "PromptingCore"),
        .target(name: "TeleprompterCore", dependencies: ["PromptingCore"]),
        .testTarget(name: "PromptingCoreTests", dependencies: ["PromptingCore", "TeleprompterCore"]),
        .testTarget(
            name: "TeleprompterCoreTests",
            dependencies: ["TeleprompterCore"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
