// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "AudioRouter",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AudioRouter", targets: ["AudioRouterApp"]),
        .executable(name: "AudioRouterChecks", targets: ["AudioRouterChecks"])
    ],
    targets: [
        .target(
            name: "AudioRouter",
            path: "Sources/AudioRouter",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("AudioToolbox")
            ]
        ),
        .executableTarget(
            name: "AudioRouterApp",
            dependencies: ["AudioRouter"],
            path: "Sources/AudioRouterApp"
        ),
        .executableTarget(
            name: "AudioRouterChecks",
            dependencies: ["AudioRouter"],
            path: "Tests/AudioRouterChecks"
        )
    ]
)
