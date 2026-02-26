// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Receptacle",
    platforms: [
        // SPM minimum — kept low for GitHub Actions runner compatibility (macos-15, Swift 6.0).
        // The Xcode app targets define their own deployment targets (macOS 26 / iOS 26).
        .macOS(.v14),
        .iOS(.v17),
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
        // ReceptacleCore — pure Swift, no SwiftData macros, no SwiftUI.
        // Compiles with swift CLI tools (no Xcode required). Used by tests.
        // All SPM dependency products are commented out here; they are wired
        // in Xcode targets directly as the phases progress.
        //
        // External package products commented out — uncomment as each phase lands:
        //   Phase 3:  SwiftMail (wired in Xcode target directly — IMAPSource lives in Shared/,
        //             not in Sources/ReceptacleCore, so no SPM target linkage needed)
        //   Phase 4:  GoogleSignIn, MSAL
        //   Phase 5:  FeedKit
        //   Phase 8:  OpenAI, SwiftAnthropic, WhisperKit
        //   Phase 11: Textual, swift-markdown
        .target(
            name: "Receptacle",
            dependencies: [],
            path: "Sources/ReceptacleCore",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
        // ReceptacleVerify — standalone executable for swift run verification (no Xcode required).
        // Mirrors the Phase 0 test suite; provides a runnable green baseline while CLI tools
        // cannot execute .xctest bundles.
        .executableTarget(
            name: "ReceptacleVerify",
            dependencies: ["Receptacle"],
            path: "Sources/ReceptacleVerify",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "ReceptacleTests",
            dependencies: ["Receptacle"],
            path: "ReceptacleTests",
            // These files use `import Foundation` + `import Testing` together, which
            // triggers the _Testing_Foundation cross-import overlay. That overlay's
            // .swiftmodule is binary-only in CLI tools (no Swift interface — build error).
            // Excluded here; open in Xcode to run those tests.
            exclude: ["RuleEngineTests.swift", "IMAPSourceTests.swift", "FeedSourceTests.swift",
                      "AttachmentSaverTests.swift", "Fixtures"],
            // Testing.framework lives in the CLI tools Frameworks dir, not the default search path.
            // These flags are only needed when building with CLI tools; Xcode finds it automatically.
            swiftSettings: [
                .unsafeFlags([
                    "-F",
                    "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                ]),
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-F",
                    "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-framework", "Testing",
                    "-Xlinker", "-rpath",
                    "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                ]),
            ]
        ),
    ]
)
