// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TokenStepSwift",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "TokenStepSwift", targets: ["TokenStepSwift"])
    ],
    targets: [
        // The main app auto-includes every file under Sources/TokenStepSwift.
        // The TokenStepHelper binary is built separately by
        // script/build_swiftui_and_run.sh via swiftc (it cherry-picks shared
        // source files, which SwiftPM cannot do without duplicating file
        // ownership), so it is intentionally not a SwiftPM target here.
        .executableTarget(name: "TokenStepSwift"),
        .testTarget(
            name: "TokenStepSwiftTests",
            dependencies: ["TokenStepSwift"]
        )
    ]
)
