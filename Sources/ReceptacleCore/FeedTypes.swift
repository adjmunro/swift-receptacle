import Foundation

// MARK: - FeedFormat

/// The wire format of an RSS/Atom/JSON Feed.
public enum FeedFormat: String, Codable, CaseIterable, Sendable {
    case rss    // RSS 2.0
    case atom   // Atom 1.0
    case json   // JSON Feed 1.1
}

// MARK: - FeedConfig

/// Configuration for a single RSS/Atom/JSON Feed source.
///
/// Each feed URL maps to a `Contact` (type: .feed) + `Entity` in SwiftData.
/// The same rules, importance, and retention policies apply as for email entities.
public struct FeedConfig: Codable, Sendable {
    public var feedId: String
    public var displayName: String
    public var feedURLString: String
    public var entityId: String

    public init(feedId: String,
                displayName: String,
                feedURLString: String,
                entityId: String) {
        self.feedId = feedId
        self.displayName = displayName
        self.feedURLString = feedURLString
        self.entityId = entityId
    }
}

// MARK: - FeedItemRecord

/// Value-type mirror of the SwiftData `FeedItem` @Model.
///
/// Produced by `FeedSource.fetchItems(since:)` and usable in CLI tests
/// without importing SwiftData. Conforms to the `Item` protocol so it
/// slots into the shared `RuleEngine`, `MockMessageSource`, etc.
public struct FeedItemRecord: Item, Sendable {

    // MARK: Item
    public var id: String        // "<feedId>:<itemGuid>"
    public var entityId: String
    public var sourceId: String
    public var date: Date
    public var summary: String   // First 200 chars of content, plain-text

    // MARK: Feed-specific
    public var title: String
    public var linkURL: String?
    public var contentHTML: String?
    public var format: FeedFormat

    public init(
        id: String,
        entityId: String,
        sourceId: String,
        date: Date = Date(),
        title: String,
        summary: String = "",
        linkURL: String? = nil,
        contentHTML: String? = nil,
        format: FeedFormat = .rss
    ) {
        self.id = id
        self.entityId = entityId
        self.sourceId = sourceId
        self.date = date
        self.title = title
        self.summary = summary.isEmpty ? String(title.prefix(200)) : summary
        self.linkURL = linkURL
        self.contentHTML = contentHTML
        self.format = format
    }
}

// MARK: - FeedFormat helpers

extension FeedFormat {
    /// Human-readable label used in badges and displays.
    public var displayName: String {
        switch self {
        case .rss:  return "RSS"
        case .atom: return "Atom"
        case .json: return "JSON Feed"
        }
    }
}

// MARK: - FeedItemRecord factory helpers

extension FeedItemRecord {

    /// Builds the composite ID from a feed ID and an item GUID.
    public static func makeId(feedId: String, guid: String) -> String {
        "\(feedId):\(guid)"
    }

    /// Extracts a plain-text summary from HTML content (strips tags, trims).
    public static func plainSummary(from html: String, maxLength: Int = 200) -> String {
        // Minimal tag stripper — replace tags with spaces, collapse whitespace.
        // Good enough for preview text; full HTML rendering happens in WebView.
        var result = html
        // Replace common block tags with newlines
        for tag in ["</p>", "<br>", "<br/>", "<br />", "</li>", "</h1>",
                    "</h2>", "</h3>", "</h4>"] {
            result = result.replacingOccurrences(of: tag, with: " ")
        }
        // Strip remaining tags
        while let start = result.range(of: "<"),
              let end = result.range(of: ">", range: start.upperBound..<result.endIndex) {
            result.removeSubrange(start.lowerBound..<end.upperBound)
        }
        // Collapse whitespace and decode common entities
        result = result
            .replacingOccurrences(of: "&amp;",  with: "&")
            .replacingOccurrences(of: "&lt;",   with: "<")
            .replacingOccurrences(of: "&gt;",   with: ">")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&quot;", with: "\"")
        // Normalise whitespace
        let words = result.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        let joined = words.joined(separator: " ")
        return joined.count <= maxLength ? joined : String(joined.prefix(maxLength)) + "…"
    }

    /// Converts an HTML string to Markdown using a sequential replacement pipeline.
    ///
    /// Designed for RSS/Atom/JSON feed content. The pipeline order is critical —
    /// comment stripping happens first, then block-level conversions, then inline,
    /// then tag stripping and whitespace cleanup last.
    public static func htmlToMarkdown(from html: String, stripsImages: Bool = false) -> String {
        var result = html

        // 0. Strip HTML comments (handles <!-- single-line -->, <!-- multi-line -->,
        //    and Outlook conditional <!--[if ...]>…<![endif]--> patterns).
        //    Must run before the char-by-char tag scanner (step 13) which can
        //    split multi-line comments and leave lone `[` or `-->` artifacts.
        let commentPattern = "<!--[\\s\\S]*?-->"
        if let re = try? NSRegularExpression(pattern: commentPattern, options: []) {
            result = re.stringByReplacingMatches(in: result,
                range: NSRange(result.startIndex..., in: result), withTemplate: "")
        }

        // 1. Strip <script>…</script> and <style>…</style> blocks with content
        let blockPattern = "<(script|style)[^>]*>[\\s\\S]*?</(script|style)>"
        if let re = try? NSRegularExpression(pattern: blockPattern, options: [.caseInsensitive]) {
            let range = NSRange(result.startIndex..., in: result)
            result = re.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }

        // 2. <pre>…<code> blocks
        let preCodeOpen = "<pre[^>]*>\\s*<code[^>]*>"
        if let re = try? NSRegularExpression(pattern: preCodeOpen, options: [.caseInsensitive]) {
            result = re.stringByReplacingMatches(in: result,
                range: NSRange(result.startIndex..., in: result), withTemplate: "\n```\n")
        }
        let codePreClose = "</code>\\s*</pre>"
        if let re = try? NSRegularExpression(pattern: codePreClose, options: [.caseInsensitive]) {
            result = re.stringByReplacingMatches(in: result,
                range: NSRange(result.startIndex..., in: result), withTemplate: "\n```\n")
        }

        // 3. Standalone <pre> / </pre>
        result = result.replacingOccurrences(of: "<pre>",  with: "\n```\n", options: .caseInsensitive)
        result = result.replacingOccurrences(of: "</pre>", with: "\n```\n", options: .caseInsensitive)

        // 4. Headings
        let headings: [(String, String)] = [
            ("<h1[^>]*>", "\n\n# "), ("<h2[^>]*>", "\n\n## "), ("<h3[^>]*>", "\n\n### "),
            ("<h4[^>]*>", "\n\n#### "), ("<h5[^>]*>", "\n\n##### "), ("<h6[^>]*>", "\n\n###### "),
        ]
        for (pattern, replacement) in headings {
            if let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                result = re.stringByReplacingMatches(in: result,
                    range: NSRange(result.startIndex..., in: result), withTemplate: replacement)
            }
        }
        for close in ["</h1>","</h2>","</h3>","</h4>","</h5>","</h6>"] {
            result = result.replacingOccurrences(of: close, with: "\n\n", options: .caseInsensitive)
        }

        // 5. Links: <a href="URL">text</a> or <a href='URL'>text</a> → [text](URL)
        //    Two alternatives in one pattern: groups (1,2) = double-quoted href+content;
        //    groups (3,4) = single-quoted href+content.
        let linkPattern =
            #"<a[^>]+href="([^"]*)"[^>]*>([\s\S]*?)</a>"# +
            #"|<a[^>]+href='([^']*)'[^>]*>([\s\S]*?)</a>"#
        if let re = try? NSRegularExpression(pattern: linkPattern,
                                              options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            let ns = result as NSString
            var out = ""
            var lastEnd = 0
            let matches = re.matches(in: result, range: NSRange(location: 0, length: ns.length))
            for m in matches {
                out += ns.substring(with: NSRange(location: lastEnd, length: m.range.location - lastEnd))
                let href = firstNonEmpty(ns, m, at: 1, 3)
                let text = firstNonEmpty(ns, m, at: 2, 4)
                out += "[\(text)](\(href))"
                lastEnd = m.range.location + m.range.length
            }
            out += ns.substring(from: lastEnd)
            result = out
        }

        // 6. Bold / italic
        for tag in ["<strong>","</strong>","<b>","</b>"] {
            result = result.replacingOccurrences(of: tag, with: "**", options: .caseInsensitive)
        }
        for tag in ["<em>","</em>","<i>","</i>"] {
            result = result.replacingOccurrences(of: tag, with: "_", options: .caseInsensitive)
        }

        // 7. Inline code
        result = result.replacingOccurrences(of: "<code>",  with: "`", options: .caseInsensitive)
        result = result.replacingOccurrences(of: "</code>", with: "`", options: .caseInsensitive)

        // 8. Blockquote
        result = result.replacingOccurrences(of: "<blockquote>",  with: "\n> ", options: .caseInsensitive)
        result = result.replacingOccurrences(of: "</blockquote>", with: "\n",   options: .caseInsensitive)

        // 9. Lists
        result = result.replacingOccurrences(of: "<li>",  with: "\n- ", options: .caseInsensitive)
        for tag in ["</li>","<ul>","</ul>","<ol>","</ol>"] {
            result = result.replacingOccurrences(of: tag, with: "\n", options: .caseInsensitive)
        }

        // 10. Paragraphs / line breaks
        if let re = try? NSRegularExpression(pattern: "<p[^>]*>", options: [.caseInsensitive]) {
            result = re.stringByReplacingMatches(in: result,
                range: NSRange(result.startIndex..., in: result), withTemplate: "\n\n")
        }
        result = result.replacingOccurrences(of: "</p>",   with: "\n\n", options: .caseInsensitive)
        for br in ["<br />","<br/>","<br>"] {
            result = result.replacingOccurrences(of: br, with: "\n", options: .caseInsensitive)
        }

        // 11. Horizontal rule
        if let re = try? NSRegularExpression(pattern: "<hr[^>]*>", options: [.caseInsensitive]) {
            result = re.stringByReplacingMatches(in: result,
                range: NSRange(result.startIndex..., in: result), withTemplate: "\n\n---\n\n")
        }

        // 12. Convert <img> to markdown inline images; skip tracking pixels (w=1 or h=1).
        //     Images with no alt text use empty alt: ![](src).
        //     This runs after the link step so <a href='u'><img src='x' alt='y'/></a>
        //     first becomes [<img src='x' alt='y'/>](u), then this step converts the img
        //     inside the brackets, producing [![y](x)](u) — a linked image.
        //     When stripsImages is true the entire step is skipped; remaining <img> tags
        //     are removed in step 13 along with all other unrecognised tags.
        if !stripsImages, let imgRe = try? NSRegularExpression(pattern: "<img[^>]*>", options: [.caseInsensitive]) {
            let ns = result as NSString
            var out = ""
            var lastEnd = 0
            let matches = imgRe.matches(in: result, range: NSRange(location: 0, length: ns.length))
            for m in matches {
                let tagStr = ns.substring(with: m.range)
                out += ns.substring(with: NSRange(location: lastEnd, length: m.range.location - lastEnd))
                // Skip tracking pixels: any img with width="1"/'1' or height="1"/'1'
                let pixelPattern = #"\b(?:width|height)=["']1["']"#
                let isTrackingPixel = (try? NSRegularExpression(pattern: pixelPattern, options: [.caseInsensitive]))?
                    .firstMatch(in: tagStr, range: NSRange(tagStr.startIndex..., in: tagStr)) != nil
                if !isTrackingPixel {
                    let src = extractAttr("src", from: tagStr)
                    let alt = extractAttr("alt", from: tagStr) ?? ""
                    if let src = src {
                        out += "![\(alt)](\(src))"
                    }
                }
                lastEnd = m.range.location + m.range.length
            }
            out += ns.substring(from: lastEnd)
            result = out
        }

        // 13. Strip remaining HTML tags
        while let start = result.range(of: "<"),
              let end = result.range(of: ">", range: start.upperBound..<result.endIndex) {
            result.removeSubrange(start.lowerBound..<end.upperBound)
        }

        // 13.5 Strip leading whitespace left by HTML table/cell/div structure.
        //      4+ leading spaces trigger Markdown indented code-block rendering.
        //      Lines inside ``` fences are preserved so code indentation is not lost.
        var inFence = false
        result = result.components(separatedBy: "\n").map { line in
            if line.trimmingCharacters(in: .whitespaces) == "```" { inFence.toggle() }
            guard !inFence else { return line }
            return String(line.drop(while: { $0 == " " || $0 == "\t" }))
        }.joined(separator: "\n")

        // 14. Decode HTML entities
        let entities: [(String, String)] = [
            ("&amp;",   "&"),  ("&lt;",  "<"),  ("&gt;",  ">"),
            ("&nbsp;",  " "),  ("&quot;", "\""), ("&#39;", "'"),
            ("&mdash;", "—"),  ("&ndash;", "–"), ("&hellip;", "…"),
        ]
        for (entity, char) in entities {
            result = result.replacingOccurrences(of: entity, with: char)
        }

        // 15. Collapse 3+ consecutive newlines → double newline
        if let re = try? NSRegularExpression(pattern: "\\n{3,}") {
            result = re.stringByReplacingMatches(in: result,
                range: NSRange(result.startIndex..., in: result), withTemplate: "\n\n")
        }

        // 16. Trim
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Private pipeline helpers

    /// Returns the value from the first capture group (by index) in `m` that was
    /// actually captured (range.location != NSNotFound). Used by the two-alternative
    /// link regex to coalesce double-quoted and single-quoted href/content groups.
    private static func firstNonEmpty(_ ns: NSString, _ m: NSTextCheckingResult, at groups: Int...) -> String {
        for g in groups {
            let r = m.range(at: g)
            if r.location != NSNotFound {
                return ns.substring(with: r)
            }
        }
        return ""
    }

    /// Extracts the value of an HTML attribute from a tag string (e.g. the `src` from
    /// `<img src="x.png" alt="photo">`). Handles both double and single quotes.
    private static func extractAttr(_ attr: String, from tag: String) -> String? {
        let pattern = "\\b" + NSRegularExpression.escapedPattern(for: attr) + #"=["']([^"']+)["']"#
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let m = re.firstMatch(in: tag, range: NSRange(tag.startIndex..., in: tag)),
              m.range(at: 1).location != NSNotFound else { return nil }
        return (tag as NSString).substring(with: m.range(at: 1))
    }

    /// Extracts the main article body from a full HTML page, stripping navigation
    /// chrome. Tries <article>, then <main>, then <body>. Always strips <nav>,
    /// <header>, <footer>, <aside>, <script>, <style> before extraction.
    public static func articleBodyHTML(from pageHTML: String) -> String {
        var html = pageHTML

        // Strip noise blocks with their content
        let noise = "<(script|style|nav|header|footer|aside)[^>]*>[\\s\\S]*?</(script|style|nav|header|footer|aside)>"
        if let re = try? NSRegularExpression(pattern: noise, options: [.caseInsensitive]) {
            html = re.stringByReplacingMatches(in: html,
                range: NSRange(html.startIndex..., in: html), withTemplate: "")
        }

        // Try <article>, then <main>, then <body>
        for tag in ["article", "main", "body"] {
            if let content = extractTagContent(tag, from: html) { return content }
        }
        return html
    }

    private static func extractTagContent(_ tag: String, from html: String) -> String? {
        let pattern = "<\(tag)[^>]*>([\\s\\S]*?)</\(tag)>"
        guard let re = try? NSRegularExpression(pattern: pattern,
                                                 options: [.caseInsensitive, .dotMatchesLineSeparators]),
              let m = re.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              m.range(at: 1).location != NSNotFound else { return nil }
        return (html as NSString).substring(with: m.range(at: 1))
    }

    /// Extracts a YouTube video ID from a `youtube.com/watch?v=` URL, or nil
    /// for any other URL. Centralised here so it can be unit-tested independently
    /// of the view layer.
    public static func youTubeVideoID(from urlString: String) -> String? {
        guard let url = URL(string: urlString),
              let host = url.host,
              host.contains("youtube.com"),
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        else { return nil }
        return items.first(where: { $0.name == "v" })?.value
    }

    /// Builds a minimal HTML page that loads a YouTube video via the IFrame
    /// Player API. Using the API (rather than a bare `<iframe src=...>`) avoids
    /// Error 152-4 / MEDIA_ERR_SRC_NOT_SUPPORTED that occurs in WKWebView when
    /// YouTube detects the embed context via the src attribute alone.
    ///
    /// `overflow: hidden` on both `html` and `body` prevents the inner WebView
    /// from being scrollable (the iOS `scrollView` must also be disabled by the
    /// caller). `baseURL` must be set to `https://www.youtube.com` when loading
    /// this HTML so that YouTube accepts the origin.
    public static func youTubeEmbedHTML(videoID: String, autoplay: Bool = true) -> String {
        let autoplayValue = autoplay ? 1 : 0
        // The watch URL is embedded literally so the WKNavigationDelegate can
        // intercept a linkActivated event and open it in the system browser.
        let watchURL = "https://www.youtube.com/watch?v=\(videoID)"
        return """
        <!DOCTYPE html>
        <html><head>
        <meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=no">
        <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        html, body { width: 100%; height: 100%; background: #000; overflow: hidden; }
        #player { width: 100%; height: 100%; }
        .error { display: flex; height: 100%; align-items: center; justify-content: center; }
        .error-inner { color: #fff; font-family: system-ui; text-align: center; padding: 20px; }
        .error-inner p { margin: 0 0 12px; opacity: 0.7; font-size: 14px; }
        .error-inner a { color: #60aaff; text-decoration: none; font-size: 15px; }
        </style>
        </head><body>
        <div id="player"></div>
        <script>
        var tag = document.createElement('script');
        tag.src = 'https://www.youtube.com/iframe_api';
        document.head.appendChild(tag);
        var player;
        function onYouTubeIframeAPIReady() {
            player = new YT.Player('player', {
                videoId: '\(videoID)',
                playerVars: {
                    'autoplay': \(autoplayValue),
                    'playsinline': 1,
                    'rel': 0,
                    'modestbranding': 1
                },
                events: {
                    'onError': function(e) {
                        document.body.innerHTML = '<div class="error"><div class="error-inner"><p>This video cannot be played here.</p><a href="\(watchURL)">▶ Watch on YouTube</a></div></div>';
                    }
                }
            });
        }
        </script>
        </body></html>
        """
    }
}
