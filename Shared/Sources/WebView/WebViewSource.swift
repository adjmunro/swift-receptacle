import Foundation

// MARK: - WebViewSource

/// MessageSource adapter for WebView-based IM services (Facebook Messenger, etc.)
///
/// WebView sources are display/interact ONLY — messages are NOT extracted into the
/// unified item store. They appear as embedded browser tabs, not as searchable items.
/// JS injection detects unread counts from the DOM and updates `SourceUsage`.
///
/// Phase roadmap: Facebook Messenger integration.
actor WebViewSource: MessageSource {
    let serviceId: String
    let serviceName: String
    let baseURLString: String
    let contactThreadURLString: String
    let entityId: String

    var id: String { "\(serviceId):\(contactThreadURLString)" }
    var sourceId: String { id }
    var displayName: String { serviceName }
    var sourceType: SourceType { .webView }

    init(
        serviceId: String,
        serviceName: String,
        baseURLString: String,
        contactThreadURLString: String,
        entityId: String
    ) {
        self.serviceId = serviceId
        self.serviceName = serviceName
        self.baseURLString = baseURLString
        self.contactThreadURLString = contactThreadURLString
        self.entityId = entityId
    }

    func fetchItems(since: Date?) async throws -> [any Item] {
        // WebView sources do not extract items into the unified store
        return []
    }

    func send(_ reply: Reply) async throws {
        // Replies are handled via JS injection into the embedded WebView
        throw MessageSourceError.unsupportedOperation
    }

    func archive(_ item: any Item) async throws {
        throw MessageSourceError.unsupportedOperation
    }

    func delete(_ item: any Item) async throws {
        throw MessageSourceError.unsupportedOperation
    }

    func markRead(_ item: any Item, read: Bool) async throws {
        throw MessageSourceError.unsupportedOperation
    }
}
