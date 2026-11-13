// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BatteryWarn",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "BatteryWarn",
            path: "BatteryWarn",
            exclude: ["Info.plist", "BatteryWarn.entitlements"],
            resources: [
                .process("Assets.xcassets")
            ]
        ),
        .testTarget(
            name: "BatteryWarnTests",
            dependencies: ["BatteryWarn"],
            path: "Tests/BatteryWarnTests"
        )
    ]
)
