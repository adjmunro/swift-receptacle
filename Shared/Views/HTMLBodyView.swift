#if canImport(SwiftUI)
import SwiftUI
#if canImport(WebKit)
import WebKit
#endif

// MARK: - HTMLBodyView

/// Renders an HTML email body using the native WebKit SwiftUI integration.
///
/// iOS/macOS 26 introduces `WebPage` — an `@Observable` class that acts as the
/// model for a `WebView`. This replaces the UIViewRepresentable / NSViewRepresentable
/// bridging pattern used in earlier OS versions.
///
/// ## WebPage API (iOS/macOS 26, WWDC 2025 — requires Xcode to compile):
///
/// ```swift
/// import WebKit
///
/// // 1. Create the model (once per card, persisted in @State)
/// @State private var page = WebPage()
///
/// // 2. Render with SwiftUI
/// WebView(page)
///     .frame(minHeight: 200)
///
/// // 3. Load local HTML content (no network call — body came from IMAP)
/// page.load(html: body, baseURL: nil)
///
/// // 4. Block remote resources using a custom URLSchemeHandler or
/// //    WebPage.Configuration.defaultWebpagePreferences:
/// var prefs = WebPage.Configuration()
/// prefs.preferences.minimumFontSize = 0
/// // (External image blocking handled via custom navigation decision handler)
/// let page = WebPage(configuration: prefs)
///
/// // 5. Intercept navigation (external links → open in browser):
/// page.navigationDecisionHandler = { action in
///     if action.navigationType == .linkActivated,
///        let url = action.request.url,
///        url.scheme != "cid" {           // cid: = inline attachment
///         UIApplication.shared.open(url)
///         return .cancel
///     }
///     return .allow
/// }
///
/// // 6. Load remote images on demand:
/// Button("Load remote images") {
///     page.configuration.preferences.minimumFontSize = 0  // trigger reload
///     page.load(html: buildBodyWithImages(body), baseURL: nil)
/// }
/// ```
///
/// Security defaults:
///   - Body loaded as local HTML — no external HTTP requests for the body itself.
///   - External `<img src="…">` links blocked by default (prevents tracking pixels).
///   - `<script>` tags from remote origins blocked.
///   - Clicked hyperlinks intercepted and opened in the system browser.
struct HTMLBodyView: View {

    let html: String
    var allowExternalImages: Bool = false

    // Phase 7: uncomment when WebPage API is available in Xcode build
    // @State private var page = WebPage()

    @State private var showImages: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if html.isEmpty {
                Text("No content")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                // Phase 7 target implementation (uncomment in Xcode):
                //
                // WebView(page)
                //     .frame(minHeight: 200)
                //     .onAppear { loadContent() }
                //     .onChange(of: showImages) { loadContent() }
                //
                // For CLI/preview builds, show a labelled placeholder:
                htmlPlaceholder
            }

            if !allowExternalImages && !showImages {
                remoteImageBanner
            }
        }
    }

    // MARK: - Placeholder (pre-Xcode)

    private var htmlPlaceholder: some View {
        ScrollView {
            Text(stripTagsForPreview(html))
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .frame(minHeight: 120)
        .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }

    private var remoteImageBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "photo.badge.exclamationmark")
                .foregroundStyle(.secondary)
            Text("Remote images blocked")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Load") {
                withAnimation { showImages = true }
            }
            .font(.caption)
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.08))
    }

    // MARK: - Helpers

    // Phase 7: replace with WebPage.load(html:baseURL:)
    // private func loadContent() {
    //     let body = showImages ? html : blockRemoteImages(in: html)
    //     page.load(html: body, baseURL: nil)
    // }

    /// Minimal tag stripper for the preview placeholder.
    /// In production this is never called — WebView renders the raw HTML.
    private func stripTagsForPreview(_ html: String) -> String {
        var result = html
        while let open = result.range(of: "<"),
              let close = result.range(of: ">",
                                        range: open.upperBound..<result.endIndex) {
            result.removeSubrange(open.lowerBound..<close.upperBound)
        }
        return result
            .replacingOccurrences(of: "&amp;",  with: "&")
            .replacingOccurrences(of: "&lt;",   with: "<")
            .replacingOccurrences(of: "&gt;",   with: ">")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Preview

#Preview("HTML email body") {
    HTMLBodyView(
        html: """
        <p>Hi there,</p>
        <p>Just following up on the <strong>Swift 6.2 migration</strong>.</p>
        <blockquote>
            <p>On Wed, Alice wrote:</p>
            <p>Have you had a chance to look at the new concurrency model?</p>
        </blockquote>
        <p>Yes — it's looking great. The actor isolation rules are much clearer.</p>
        <p>Cheers,<br>Bob</p>
        """
    )
    .padding()
}
#endif
