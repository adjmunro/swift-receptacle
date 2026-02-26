// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Receptacle",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
    ],
    products: [
        .library(name: "Receptacle", targets: ["Receptacle"]),
    ],
    dependencies: [
        // IMAP/SMTP — pure Swift, actor-based, Swift 6 native
        // No versioned releases yet (March 2025); use main branch
        .package(url: "https://github.com/Cocoanetics/SwiftMail", branch: "main"),
        // Gmail OAuth2
        .package(url: "https://github.com/google/GoogleSignIn-iOS", from: "9.0.0"),
        // Outlook OAuth2
        .package(url: "https://github.com/AzureAD/microsoft-authentication-library-for-objc", from: "2.8.0"),
        // RSS/Atom/JSON Feed
        .package(url: "https://github.com/nmdias/FeedKit", from: "9.0.0"),
        // OpenAI API client
        .package(url: "https://github.com/MacPaw/OpenAI", from: "0.2.0"),
        // Anthropic/Claude API client
        .package(url: "https://github.com/jamesrochabrun/SwiftAnthropic", from: "1.0.0"),
        // On-device speech transcription (WhisperKit, Argmax)
        .package(url: "https://github.com/argmaxinc/WhisperKit", from: "0.9.0"),
        // Markdown rendering in SwiftUI — successor to MarkdownUI
        .package(url: "https://github.com/gonzalezreal/textual", from: "0.3.0"),
        // Markdown AST parser (wikilink detection)
        .package(url: "https://github.com/apple/swift-markdown", from: "0.4.0"),
    ],
    targets: [
        // Shared library — all business logic, models, and views
        // External package products are linked here once adapters are implemented (Phase 3+)
        .target(
            name: "Receptacle",
            dependencies: [
                // Phase 3: .product(name: "SwiftMail", package: "SwiftMail"),
                // Phase 4: .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS"),
                // Phase 4: .product(name: "MSAL", package: "microsoft-authentication-library-for-objc"),
                // Phase 5: .product(name: "FeedKit", package: "FeedKit"),
                // Phase 8: .product(name: "OpenAI", package: "OpenAI"),
                // Phase 8: .product(name: "SwiftAnthropic", package: "SwiftAnthropic"),
                // Phase 8: .product(name: "WhisperKit", package: "WhisperKit"),
                // Phase 11: .product(name: "Textual", package: "textual"),
                // Phase 11: .product(name: "Markdown", package: "swift-markdown"),
            ],
            path: "Shared",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "ReceptacleTests",
            dependencies: ["Receptacle"],
            path: "ReceptacleTests"
        ),
    ]
)
