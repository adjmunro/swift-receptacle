import SwiftUI
import SwiftData
import WebKit
import Receptacle
import Textual

// MARK: - PostCardView

/// A single item rendered as a post-card within PostFeedView.
///
/// - Importance indicator (red/orange icon) for .critical/.important items
/// - Collapsed/expanded toggle (chevron)
/// - Body: plain-text summary until Phase 7 (HTMLBodyView)
/// - Quoted-text toggle placeholder (implemented in Phase 6)
/// - Reply button — opens VoiceReplyView via `onReply` callback
/// - Archive/delete wired to SwiftData model via `modelContext`
struct PostCardView: View {
    let item: PostCardItem
    let entity: Entity
    let feedHeight: CGFloat

    /// Called when the user taps Reply — parent presents VoiceReplyView.
    var onReply: (() -> Void)? = nil

    // 160pt = ~120pt card chrome (header + divider + actionBar + padding) + 40pt breathing room
    private var bodyMaxHeight: CGFloat { max(200, feedHeight - 160) }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL

    @State private var isExpanded: Bool = true
    @State private var showQuoted: Bool = false
    @State private var showDeleteConfirm: Bool = false
    @State private var gradientAngle: Double = 0
    @State private var isYouTubeLoaded = false
    @State private var isWebViewLoaded = false

    // Quoted-range detection — computed once per item.
    private let detector = QuotedRangeDetector()
    private var hasQuotedContent: Bool { detector.hasQuotedContent(in: item.summary) }
    private var collapsedBody: String  { detector.collapsedText(for: item.summary) }

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
                .padding(.horizontal, 14)
                .padding(.top, 12)

            if isExpanded {
                Divider().padding(.vertical, 8)
                bodyContent
                    .padding(.horizontal, 14)
                actionBar
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
            } else {
                Spacer().frame(height: 12)
            }
        }
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(cardBorderGradient, lineWidth: cardBorderWidth)
        )
        .onAppear {
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                gradientAngle = 360
            }
        }
        .confirmationDialog(
            "Delete this item?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                performDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This item is marked \(item.importanceLevel == .critical ? "critical" : "important"). Are you sure?")
        }
#if os(macOS)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willMiniaturizeNotification)) { _ in
            isWebViewLoaded = false
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { _ in
            isWebViewLoaded = false
        }
#endif
    }

    // MARK: Subviews

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            // Importance icon
            importanceIcon

            // Title / subject
            VStack(alignment: .leading, spacing: 2) {
                if let title = item.title {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                }
                Text(item.date.formatted(.relative(presentation: .named, unitsStyle: .abbreviated)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Unread dot
            if !item.isRead {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 8, height: 8)
            }

            // Source badge
            Text(item.sourceLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.12), in: Capsule())

            // Expand/collapse indicator
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isExpanded { isWebViewLoaded = false }
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
    }

    @ViewBuilder
    private var importanceIcon: some View {
        switch item.importanceLevel {
        case .critical:
            Image(systemName: "exclamationmark.2")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.red)
        case .important:
            Image(systemName: "exclamationmark")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.orange)
        case .normal:
            EmptyView()
        }
    }

    @ViewBuilder
    private var bodyContent: some View {
        // YouTube: inline player — 16:9 aspect ratio keeps height below cap in practice,
        // but goes through CardBody to keep all paths symmetric.
        if let linkStr = item.linkURLString,
           let videoID = FeedItemRecord.youTubeVideoID(from: linkStr) {
            CardBody(content: YouTubePlayerView(videoID: videoID, isLoaded: $isYouTubeLoaded),
                     maxHeight: bodyMaxHeight)
        }
        // Feed item with HTML: markdown default, Looking Glass on demand
        else if let html = item.contentHTML {
            if isWebViewLoaded, let urlStr = item.linkURLString {
                // LookingGlass: fixed height so both card borders stay visible.
                LookingGlassWebView(urlString: urlStr)
                    .frame(height: bodyMaxHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                let baseURL = item.linkURLString.flatMap { URL(string: $0) }
                CardBody(
                    content: StructuredText(
                        markdown: FeedItemRecord.htmlToMarkdown(from: html),
                        baseURL: baseURL
                    )
                    // Comfortable reading width — prevents wall-to-wall lines
                    .frame(maxWidth: 700)
                    // Tighter paragraph spacing for newsletter-style HTML content
                    .textual.blockSpacing(StructuredText.BlockSpacing(top: 2, bottom: 6))
                    // Line height: 1.45× the body font size
                    .textual.lineSpacing(.fontScaled(0.45))
                    // Load inline images from feed article URLs
                    .textual.imageAttachmentLoader(.image(relativeTo: baseURL)),
                    maxHeight: bodyMaxHeight
                )
            }
        }
        // Email / no-HTML: plain text + quoted toggle — now height-capped too.
        else {
            CardBody(
                content: VStack(alignment: .leading, spacing: 8) {
                    Text(showQuoted ? item.summary : collapsedBody)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .animation(.easeInOut(duration: 0.15), value: showQuoted)
                    if hasQuotedContent {
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) { showQuoted.toggle() }
                        } label: {
                            Label(showQuoted ? "Hide quoted text" : "Show quoted text",
                                  systemImage: showQuoted ? "quote.bubble" : "quote.bubble.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                },
                maxHeight: bodyMaxHeight
            )
        }
    }


    private var actionBar: some View {
        HStack(spacing: 16) {
            Spacer()

            // Looking Glass — toggles inline WebView vs markdown for feed articles
            if item.contentHTML != nil, item.linkURLString != nil {
                Button { isWebViewLoaded.toggle() } label: {
                    Label(
                        isWebViewLoaded ? "Markdown" : "Looking Glass",
                        systemImage: isWebViewLoaded ? "doc.richtext" : "globe"
                    )
                    .font(.caption)
                }
                .buttonStyle(.borderless)
            }

            // Open link — only for feed items with a URL
            if let linkStr = item.linkURLString, let url = URL(string: linkStr) {
                Button {
                    openURL(url)
                } label: {
                    Label("Open", systemImage: "arrow.up.right.square")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("Open article in browser")
            }

            // Reply — only for items with a reply-to address (email)
            if let replyTo = item.replyToAddress {
                Button {
                    onReply?()
                } label: {
                    Label("Reply", systemImage: "arrowshape.turn.up.left")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("Reply to \(replyTo)")
            }

            // Archive — not for protected entities
            if entity.protectionLevel != .protected {
                Button {
                    performArchive()
                } label: {
                    Label("Archive", systemImage: "archivebox")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .tint(.orange)
            }

            // Delete — gated by protection level + importance
            if entity.protectionLevel != .protected {
                Button(role: .destructive) {
                    if item.importanceLevel > .normal {
                        showDeleteConfirm = true
                    } else {
                        performDelete()
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Actions

    /// Mark the item as archived in SwiftData.
    /// EmailItem: sets isArchived = true.
    /// FeedItem: sets isSaved = true (RSS "save" = archive equivalent).
    ///
    /// Sets isYouTubeLoaded = false first so the WKWebView is removed from the
    /// hierarchy and dismantleNSView fires while the card is still in the tree.
    /// The actual archive is deferred by one frame to let that happen before
    /// SwiftData removes the card from the query.
    private func performArchive() {
        isYouTubeLoaded = false
        isWebViewLoaded = false
        let itemId = item.id
        let ctx = modelContext
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let emailPred = #Predicate<EmailItem> { $0.id == itemId }
            if let email = try? ctx.fetch(FetchDescriptor(predicate: emailPred)).first {
                email.isArchived = true
                return
            }
            let feedPred = #Predicate<FeedItem> { $0.id == itemId }
            if let feed = try? ctx.fetch(FetchDescriptor(predicate: feedPred)).first {
                feed.isSaved = true
            }
        }
    }

    /// Mark the item as deleted in SwiftData.
    /// EmailItem: sets isDeleted = true (soft delete, filtered out of queries).
    /// FeedItem: hard-deleted from the store (no isDeleted flag).
    ///
    /// Sets isYouTubeLoaded = false first so the WKWebView is removed from the
    /// hierarchy and dismantleNSView fires while the card is still in the tree.
    /// The actual delete is deferred by one frame to let that happen before
    /// SwiftData removes the card from the query.
    private func performDelete() {
        isYouTubeLoaded = false
        isWebViewLoaded = false
        let itemId = item.id
        let ctx = modelContext
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let emailPred = #Predicate<EmailItem> { $0.id == itemId }
            if let email = try? ctx.fetch(FetchDescriptor(predicate: emailPred)).first {
                email.isDeleted = true
                return
            }
            let feedPred = #Predicate<FeedItem> { $0.id == itemId }
            if let feed = try? ctx.fetch(FetchDescriptor(predicate: feedPred)).first {
                ctx.delete(feed)
            }
        }
    }

    // MARK: Appearance helpers

    private var cardBackground: Color {
#if os(macOS)
        return Color(nsColor: .windowBackgroundColor)
#else
        return Color(uiColor: .secondarySystemBackground)
#endif
    }

    private var cardBorderGradient: AngularGradient {
        let colors: [Color]
        switch item.importanceLevel {
        case .critical:
            colors = [.red, .orange, .pink, .red, .orange, .pink, .red]
        case .important:
            colors = [.orange, .yellow, .red, .orange, .yellow, .orange]
        case .normal:
            colors = [.indigo, .purple, .blue, .cyan, .teal, .mint, .indigo]
        }
        return AngularGradient(
            colors: colors,
            center: .center,
            startAngle: .degrees(gradientAngle),
            endAngle: .degrees(gradientAngle + 360)
        )
    }

    private var cardBorderWidth: CGFloat {
        switch item.importanceLevel {
        case .critical:  return 2.0
        case .important: return 1.75
        case .normal:    return 1.5
        }
    }
}

// MARK: - ContentHeightKey

private struct ContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - CardBodyScrollView (macOS)

#if os(macOS)
private struct CardBodyScrollView<Content: View>: NSViewRepresentable {
    let content: Content
    let maxHeight: CGFloat
    @Binding var contentHeight: CGFloat

    func makeNSView(context: Context) -> NestedCardScrollView {
        let sv = NestedCardScrollView()
        sv.hasVerticalScroller    = true
        sv.autohidesScrollers     = true
        sv.hasHorizontalScroller  = false
        sv.verticalScrollElasticity = .none
        sv.drawsBackground        = false

        let hv = NSHostingView(rootView: content)
        hv.translatesAutoresizingMaskIntoConstraints = false
        sv.documentView = hv

        NSLayoutConstraint.activate([
            hv.widthAnchor.constraint(equalTo: sv.contentView.widthAnchor)
        ])
        return sv
    }

    func updateNSView(_ sv: NestedCardScrollView, context: Context) {
        guard let hv = sv.documentView as? NSHostingView<Content> else { return }
        hv.rootView = content
        DispatchQueue.main.async {
            let h = hv.fittingSize.height
            if contentHeight != h { contentHeight = h }
        }
    }

    func makeCoordinator() {}
}
#endif

// MARK: - CardBody

private struct CardBody<Content: View>: View {
    let content: Content
    let maxHeight: CGFloat
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        let clampedHeight = min(max(contentHeight, 40), maxHeight)
#if os(macOS)
        CardBodyScrollView(content: content,
                           maxHeight: maxHeight,
                           contentHeight: $contentHeight)
            .frame(height: clampedHeight)
#else
        ScrollView {
            content
                .background(GeometryReader { geo in
                    Color.clear.preference(key: ContentHeightKey.self,
                                           value: geo.size.height)
                })
        }
        .frame(maxHeight: maxHeight)
        .onPreferenceChange(ContentHeightKey.self) { contentHeight = $0 }
#endif
    }
}

// MARK: - YouTubePlayerView

/// Shows a thumbnail with a play button. Tapping replaces it with an embedded
/// WKWebView player. This avoids loading multiple WKWebViews simultaneously
/// while scrolling, which was causing significant list performance issues.
private struct YouTubePlayerView: View {
    let videoID: String
    @Binding var isLoaded: Bool
    @State private var isPaused = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if isLoaded {
                YouTubeWebView(videoID: videoID, isPaused: isPaused)
            } else {
                Button { isLoaded = true } label: {
                    ZStack {
                        AsyncImage(
                            url: URL(string: "https://img.youtube.com/vi/\(videoID)/hqdefault.jpg")
                        ) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Rectangle().fill(Color.secondary.opacity(0.15))
                        }
                        .clipped()

                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.5), radius: 6)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        // iOS: stop when the app is backgrounded (e.g. swipe up in app switcher).
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { isLoaded = false }
        }
#if os(macOS)
        // macOS: pause when minimised, stop when closed.
        // scenePhase does NOT reliably reach .background for either of these
        // events — the app process keeps running and the scene stays active.
        // Minimise only pauses (keeps the WKWebView alive) so the user can
        // restore the window and resume from the same timestamp.
        .onReceive(NotificationCenter.default.publisher(
            for: NSWindow.willMiniaturizeNotification)
        ) { _ in isPaused = true }
        .onReceive(NotificationCenter.default.publisher(
            for: NSWindow.didDeminiaturizeNotification)
        ) { _ in isPaused = false }
        .onReceive(NotificationCenter.default.publisher(
            for: NSWindow.willCloseNotification)
        ) { _ in isLoaded = false }
#endif
    }
}

// MARK: - YouTubeWebCoordinator

/// WKNavigationDelegate shared by both platform YouTubeWebView implementations.
///
/// When the YouTube IFrame Player fires `onError` (e.g. embedding disabled /
/// Error 152), the HTML replaces the body with a "Watch on YouTube" anchor.
/// Tapping that anchor triggers a `.linkActivated` navigation here, which we
/// intercept and open in the system browser rather than inside the WKWebView.
private final class YouTubeWebCoordinator: NSObject, WKNavigationDelegate {
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // Only intercept explicit user link-taps (not resource/iframe loads).
        guard navigationAction.navigationType == .linkActivated,
              let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
#if os(macOS)
        NSWorkspace.shared.open(url)
#else
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
#endif
        decisionHandler(.cancel)
    }
}

#if os(macOS)

// MARK: - NestedCardScrollView

/// NSScrollView subclass that routes scroll events based on card visibility.
///
/// - Card partially off-screen → forwards to the outer feed scroll.
/// - Card fully on-screen + inner content not at edge → scrolls inner content.
/// - Inner content at top edge + scrolling up → forwards to outer.
/// - Inner content at bottom edge + scrolling down → forwards to outer.
private class NestedCardScrollView: NSScrollView {

    private var isFullyVisibleInWindow: Bool {
        guard let window else { return false }
        let frameInWindow = convert(bounds, to: nil)
        return window.contentLayoutRect.contains(frameInWindow)
    }

    override func scrollWheel(with event: NSEvent) {
        guard isFullyVisibleInWindow else {
            enclosingScrollView?.scrollWheel(with: event)
            return
        }

        let visRect  = documentVisibleRect
        let docH     = documentView?.frame.height ?? 0
        let atTop    = visRect.minY <= 1.0
        let atBottom = visRect.maxY >= docH - 1.0
        let goingUp  = event.scrollingDeltaY > 0

        if (goingUp && atTop) || (!goingUp && atBottom) {
            enclosingScrollView?.scrollWheel(with: event)
        } else {
            super.scrollWheel(with: event)
        }
    }
}

// MARK: - PassthroughScrollWKWebView

/// WKWebView subclass that forwards scroll events to the enclosing NSScrollView
/// (SwiftUI's ScrollView backing) so the post feed can scroll while the cursor
/// is positioned over the embedded player.
///
/// `nextResponder` alone doesn't reliably reach SwiftUI's scroll infrastructure;
/// `enclosingScrollView` walks the superview chain and finds the real NSScrollView.
private class PassthroughScrollWKWebView: WKWebView {
    override func scrollWheel(with event: NSEvent) {
        // WKWebView's own internal scroll view is a *subview*, not a superview,
        // so enclosingScrollView correctly finds SwiftUI's backing NSScrollView.
        if let sv = enclosingScrollView {
            sv.scrollWheel(with: event)
        } else {
            nextResponder?.scrollWheel(with: event)
        }
    }
}

private struct YouTubeWebView: NSViewRepresentable {
    let videoID: String
    let isPaused: Bool

    func makeCoordinator() -> YouTubeWebCoordinator { YouTubeWebCoordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.mediaTypesRequiringUserActionForPlayback = []
        let view = PassthroughScrollWKWebView(frame: .zero, configuration: config)
        view.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Safari/605.1.15"
        view.navigationDelegate = context.coordinator
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        if view.url == nil {
            view.loadHTMLString(FeedItemRecord.youTubeEmbedHTML(videoID: videoID, autoplay: true),
                                baseURL: URL(string: "https://www.youtube.com"))
            return
        }
        if isPaused {
            view.evaluateJavaScript("try{player.pauseVideo();}catch(_){}")
        }
    }

    /// Called when SwiftUI removes this view from the hierarchy (card deleted /
    /// archived, source switched, or isLoaded set to false by the window /
    /// scene-phase observers above).
    ///
    /// We stop audio via two synchronous calls (no callbacks):
    ///   1. evaluateJavaScript — tells the IFrame Player API to stop immediately.
    ///   2. loadHTMLString("") — cancels the current page in WebContent, stopping
    ///      all media regardless of whether the JS API was ready.
    ///
    /// We then hold a strong reference to the WKWebView for 1 s via
    /// asyncAfter so the IPC channel to the WebContent process stays alive long
    /// enough for the navigation to commit. Without this, ARC can free the
    /// WKWebView object before WebContent processes the navigation, leaving an
    /// orphaned renderer that keeps playing audio.
    ///
    /// `pauseAllMediaPlayback(completionHandler:)` was removed: its async
    /// callback fires after dismantleNSView returns, by which point SwiftUI may
    /// have released the view. The callback closure only keeps the WKWebView
    /// alive until the closure body finishes — not until the subsequent
    /// navigation commits — so audio continued in the orphaned renderer.
    static func dismantleNSView(_ nsView: WKWebView, coordinator: YouTubeWebCoordinator) {
        nsView.evaluateJavaScript("try{player.stopVideo();}catch(_){}")
        nsView.loadHTMLString("", baseURL: nil)
        let wv = nsView
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { _ = wv }
    }
}
#else
private struct YouTubeWebView: UIViewRepresentable {
    let videoID: String
    let isPaused: Bool

    func makeCoordinator() -> YouTubeWebCoordinator { YouTubeWebCoordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let view = WKWebView(frame: .zero, configuration: config)
        view.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        view.scrollView.isScrollEnabled = false
        view.scrollView.bounces = false
        view.navigationDelegate = context.coordinator
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        if view.url == nil {
            view.loadHTMLString(FeedItemRecord.youTubeEmbedHTML(videoID: videoID, autoplay: true),
                                baseURL: URL(string: "https://www.youtube.com"))
            return
        }
        if isPaused {
            view.evaluateJavaScript("try{player.pauseVideo();}catch(_){}")
        }
    }

    /// See dismantleNSView for rationale — same fix applies on iOS.
    static func dismantleUIView(_ uiView: WKWebView, coordinator: YouTubeWebCoordinator) {
        uiView.evaluateJavaScript("try{player.stopVideo();}catch(_){}")
        uiView.loadHTMLString("", baseURL: nil)
        let wv = uiView
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { _ = wv }
    }
}
#endif

// youTubeEmbedHTML is defined as FeedItemRecord.youTubeEmbedHTML(videoID:autoplay:)
// in the Receptacle package (FeedTypes.swift) so it can be unit-tested.

// MARK: - LookingGlassWKWebView / LookingGlassWebView

#if os(macOS)
/// WKWebView subclass for LookingGlass that scrolls web content internally
/// when the card is fully visible, and forwards to the outer feed scroll otherwise.
private class LookingGlassWKWebView: WKWebView {
    override func scrollWheel(with event: NSEvent) {
        if isFullyVisibleInWindow {
            // WKWebView propagates remaining delta up the responder chain when
            // the page hits its edge, so the outer feed scroll still works.
            super.scrollWheel(with: event)
        } else {
            if let sv = enclosingScrollView {
                sv.scrollWheel(with: event)
            } else {
                nextResponder?.scrollWheel(with: event)
            }
        }
    }

    private var isFullyVisibleInWindow: Bool {
        guard let window else { return false }
        return window.contentLayoutRect.contains(convert(bounds, to: nil))
    }
}
#endif

/// Inline WKWebView that loads the article's URL directly.
/// Uses LookingGlassWKWebView on macOS for visibility-aware scroll routing.
/// Mirrors the YouTube dismantle pattern: stop loading, blank the page, hold a
/// strong reference for 1 s so the WebContent process can commit the navigation.
#if os(macOS)
private struct LookingGlassWebView: NSViewRepresentable {
    let urlString: String

    func makeNSView(context: Context) -> LookingGlassWKWebView {
        let wv = LookingGlassWKWebView()
        if let url = URL(string: urlString) { wv.load(URLRequest(url: url)) }
        return wv
    }

    func updateNSView(_ view: LookingGlassWKWebView, context: Context) {}

    static func dismantleNSView(_ nsView: LookingGlassWKWebView, coordinator: Void) {
        nsView.stopLoading()
        nsView.loadHTMLString("", baseURL: nil)
        let wv = nsView
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { _ = wv }
    }

    func makeCoordinator() {}
}
#else
private struct LookingGlassWebView: UIViewRepresentable {
    let urlString: String

    func makeUIView(context: Context) -> WKWebView {
        let wv = WKWebView()
        if let url = URL(string: urlString) { wv.load(URLRequest(url: url)) }
        return wv
    }

    func updateUIView(_ view: WKWebView, context: Context) {}

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Void) {
        uiView.stopLoading()
        uiView.loadHTMLString("", baseURL: nil)
        let wv = uiView
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { _ = wv }
    }

    func makeCoordinator() {}
}
#endif

// MARK: - Preview

#Preview("Email card — important") {
    let item = PostCardItem(
        id: "p1",
        date: Date().addingTimeInterval(-3_600),
        summary: "Your ISA rate has changed from 4.5% to 4.2% effective 1 March 2026.",
        title: "Your savings rates have changed",
        importanceLevel: .critical,
        sourceType: .email,
        sourceLabel: "Email",
        isRead: false,
        entityId: "e1",
        replyToAddress: "alerts@bank.example",
        linkURLString: nil,
        contentHTML: nil
    )
    let entity = Entity(
        displayName: "Bank Alerts",
        protectionLevel: .protected,
        retentionPolicy: .keepAll
    )
    PostCardView(item: item, entity: entity, feedHeight: 600)
        .padding()
        .modelContainer(for: Entity.self, inMemory: true)
}

#Preview("Feed card — normal") {
    let item = PostCardItem(
        id: "p2",
        date: Date().addingTimeInterval(-43_200),
        summary: "The Swift team is pleased to announce Swift 6.2, featuring improved macros and new standard library additions.",
        title: "Swift 6.2 Released",
        importanceLevel: .normal,
        sourceType: .rss,
        sourceLabel: "Atom",
        isRead: true,
        entityId: "e2",
        replyToAddress: nil,
        linkURLString: "https://swift.org/blog/swift-6-2-released",
        contentHTML: "<p>The Swift team is pleased to announce <strong>Swift 6.2</strong>, featuring improved macros and new standard library additions.</p>"
    )
    let entity = Entity(
        displayName: "Swift.org Blog",
        protectionLevel: .normal,
        retentionPolicy: .keepLatest(20)
    )
    PostCardView(item: item, entity: entity, feedHeight: 600)
        .padding()
        .modelContainer(for: Entity.self, inMemory: true)
}
