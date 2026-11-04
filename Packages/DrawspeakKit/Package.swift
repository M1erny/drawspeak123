// swift-tools-version: 6.4
import PackageDescription

let mainActorDefault: [SwiftSetting] = [
    .defaultIsolation(MainActor.self),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
]

let package = Package(
    name: "DrawspeakKit",
    defaultLocalization: "en",
    platforms: [.iOS("27.0"), .macOS("27.0")],
    products: [
        .library(name: "DrawspeakCore", targets: ["DrawspeakCore"]),
        .library(name: "T3Kit", targets: ["T3Kit"]),
        .library(name: "VoiceKit", targets: ["VoiceKit"]),
        .library(name: "HTMLKit", targets: ["HTMLKit"]),
        .library(name: "CanvasKit", targets: ["CanvasKit"]),
        .library(name: "FeedbackKit", targets: ["FeedbackKit"]),
        .library(name: "NotesKit", targets: ["NotesKit"]),
    ],
    targets: [
        .target(
            name: "DrawspeakCore",
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
        ),
        .target(name: "T3Kit", dependencies: ["DrawspeakCore"], swiftSettings: mainActorDefault),
        .target(name: "VoiceKit", dependencies: ["DrawspeakCore"], swiftSettings: mainActorDefault),
        .target(
            name: "HTMLKit",
            dependencies: ["DrawspeakCore"],
            resources: [.process("Resources")],
            swiftSettings: mainActorDefault
        ),
        .target(name: "CanvasKit", dependencies: ["DrawspeakCore", "HTMLKit"], swiftSettings: mainActorDefault),
        .target(name: "NotesKit", dependencies: ["DrawspeakCore"], swiftSettings: mainActorDefault),
        .target(name: "FeedbackKit", dependencies: ["DrawspeakCore", "HTMLKit"], swiftSettings: mainActorDefault),
        .testTarget(name: "DrawspeakCoreTests", dependencies: ["DrawspeakCore"]),
        .testTarget(name: "T3KitTests", dependencies: ["T3Kit", "DrawspeakCore"]),
        .testTarget(name: "VoiceKitTests", dependencies: ["VoiceKit", "DrawspeakCore"]),
        .testTarget(name: "CanvasKitTests", dependencies: ["CanvasKit", "HTMLKit", "DrawspeakCore"]),
        .testTarget(name: "HTMLKitTests", dependencies: ["HTMLKit", "DrawspeakCore"]),
    ]
)
