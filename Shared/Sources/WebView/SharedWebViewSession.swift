import Foundation

// MARK: - SharedWebViewSession

/// Manages a single persistent WKWebView session per IM service.
///
/// Keeping one WKWebView warm per service preserves login cookies and avoids
/// re-authentication. The cookie store uses the default persistent data store
/// so sessions survive app restarts.
///
/// Tab ordering (computed once on first entity tap, not during active viewing):
///   - If any source has unreads → sort by unread count descending
///   - If no unreads → sort by SourceUsage.viewCount descending
///
/// Note: WKWebView is a UI component; this manager runs on @MainActor.
/// The actual WKWebView instance is created lazily in the View layer.
@MainActor
final class SharedWebViewSession: Sendable {
    static let shared = SharedWebViewSession()

    /// Maps serviceId → thread URL string currently loaded per entity
    private var loadedThreads: [String: String] = [:]

    private init() {}

    /// Preloads the thread URL for a given entity in the background session.
    /// Called when an entity is tapped, before the user switches to that tab.
    func preloadThread(serviceId: String, threadURLString: String) {
        loadedThreads[serviceId] = threadURLString
        // TODO: Notify the WKWebView for this service to navigate to threadURLString
    }

    /// Returns the URL that should be loaded for a given service session.
    func currentThreadURL(for serviceId: String) -> String? {
        loadedThreads[serviceId]
    }

    /// JavaScript to inject for unread count detection (service-specific).
    /// Returns JS expression whose result is the unread count as an Int.
    func unreadCountJS(for serviceId: String) -> String? {
        switch serviceId {
        case "messenger":
            // Inspect DOM badge count — fragile, updated per Facebook DOM changes
            return """
            (() => {
              const badge = document.querySelector('[aria-label*="unread"]');
              if (!badge) return 0;
              return parseInt(badge.textContent) || 0;
            })()
            """
        default:
            return nil
        }
    }
}
