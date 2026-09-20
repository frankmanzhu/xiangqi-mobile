// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "XiangqiMobile",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "XiangqiCore", targets: ["XiangqiCore"])
    ],
    targets: [
        .target(name: "XiangqiCore", path: "XiangqiMobile/Core"),
        .testTarget(name: "XiangqiCoreTests", dependencies: ["XiangqiCore"], path: "Tests/XiangqiCoreTests")
    ]
)
