import SwiftUI
#if canImport(WebKit)
import WebKit
#endif

/// Renders an HTML email body using the native WebKit SwiftUI component.
///
/// Uses the new `WebPage` API (iOS/macOS 26, WWDC 2025) — first-class SwiftUI
/// component with `Observable` state sync. No UIViewRepresentable bridging needed.
///
/// Security defaults:
///   - External images blocked (loaded only on explicit user tap)
///   - JavaScript from remote origins blocked
///   - Redirects intercepted (clicked links open in default browser)
///
/// Phase 7 full implementation.
struct HTMLBodyView: View {
    let html: String
    var allowExternalImages: Bool = false

    @State private var isLoaded = false

    var body: some View {
        Group {
            if html.isEmpty {
                Text("No content")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                // Phase 7: WebPage API usage
                // @State private var page = WebPage()
                //
                // WebView(page)
                //     .onAppear {
                //         page.load(HTMLContent(html, baseURL: nil))
                //     }
                //
                // For now, fallback text view:
                Text("HTML preview (Phase 7)")
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
    }
}
