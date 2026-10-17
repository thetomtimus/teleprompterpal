// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PhoneLibrary",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [.library(name: "PhoneLibrary", targets: ["PhoneLibrary"])],
    dependencies: [.package(path: "../TeleprompterCore")],
    targets: [
        .target(name: "PhoneLibrary", dependencies: [.product(name: "PromptingCore", package: "TeleprompterCore")]),
        .testTarget(name: "PhoneLibraryTests", dependencies: ["PhoneLibrary"]),
    ],
    swiftLanguageModes: [.v6]
)
