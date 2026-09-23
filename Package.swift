// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "XiangqiMobile",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "XiangqiCore", targets: ["XiangqiCore"]),
        .executable(name: "ccpd-import", targets: ["CCPDImporter"]),
        .executable(name: "iccs-validate", targets: ["ICCSValidator"]),
        .executable(name: "ccpd-merge", targets: ["CCPDMerger"])
    ],
    targets: [
        .target(
            name: "XiangqiCore",
            path: "XiangqiMobile/Core",
            linkerSettings: [.linkedLibrary("sqlite3"), .linkedLibrary("z")]
        ),
        .executableTarget(
            name: "CCPDImporter",
            dependencies: ["XiangqiCore"],
            path: "Tools/CCPDImporter",
            linkerSettings: [.linkedLibrary("sqlite3"), .linkedLibrary("z")]
        ),
        .executableTarget(
            name: "ICCSValidator",
            dependencies: ["XiangqiCore"],
            path: "Tools/ICCSValidator"
        ),
        .executableTarget(
            name: "CCPDMerger",
            dependencies: ["XiangqiCore"],
            path: "Tools/CCPDMerger",
            linkerSettings: [.linkedLibrary("sqlite3"), .linkedLibrary("z")]
        ),
        .testTarget(name: "XiangqiCoreTests", dependencies: ["XiangqiCore"], path: "Tests/XiangqiCoreTests")
    ]
)
