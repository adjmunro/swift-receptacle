import SwiftUI
#if canImport(WebKit)
import WebKit
#endif

/// Embedded browser tab for per-contact WebView-based IM (Messenger, etc.)
///
/// Uses a `WKWebView` with the default persistent cookie store so login survives
/// app restarts. One tab per contact thread URL.
/// Preloading is triggered by `SharedWebViewSession.preloadThread(...)`.
struct WebViewTabView: View {
    let serviceId: String
    let threadURLString: String

    var body: some View {
        Group {
#if canImport(WebKit)
            WebViewRepresentable(urlString: threadURLString)
#else
            Text("WebView not available on this platform")
                .foregroundStyle(.secondary)
#endif
        }
    }
}

#if canImport(WebKit)
/// Platform bridge for WKWebView until a SwiftUI-native WebView exists for macOS.
struct WebViewRepresentable: NSViewRepresentable {
    let urlString: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // Use default persistent data store so cookies survive restarts
        config.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: config)
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        guard let url = URL(string: urlString) else { return }
        if nsView.url?.absoluteString != urlString {
            nsView.load(URLRequest(url: url))
        }
    }
}
#endif
