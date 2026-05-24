// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "AudioRouter",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AudioRouter", targets: ["AudioRouter"]),
        .executable(name: "AudioRouterChecks", targets: ["AudioRouterChecks"])
    ],
    targets: [
        .target(
            name: "AudioRouterCore",
            path: "Sources/AudioRouter",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("ServiceManagement")
            ]
        ),
        .executableTarget(
            name: "AudioRouter",
            dependencies: ["AudioRouterCore"],
            path: "Sources/AudioRouterApp"
        ),
        .executableTarget(
            name: "AudioRouterChecks",
            dependencies: ["AudioRouterCore"],
            path: "Tests/AudioRouterChecks"
        )
    ]
)
