// HtmlToMarkdownTests.swift
// CLI-compatible: only `import Testing` (no Foundation).
// Tests for FeedItemRecord.htmlToMarkdown pipeline fixes.

import Testing
@testable import Receptacle

// MARK: - HtmlToMarkdown Tests

@Suite("HtmlToMarkdown — pipeline quality fixes")
struct HtmlToMarkdownTests {

    // MARK: Issue 1: HTML comment stripping

    @Test("Single-line HTML comment is stripped")
    func stripsHTMLComments() {
        let html = "<p>Hello <!-- this is a comment --> World</p>"
        let md = FeedItemRecord.htmlToMarkdown(from: html)
        #expect(!md.contains("<!--"))
        #expect(!md.contains("-->"))
        #expect(md.contains("Hello"))
        #expect(md.contains("World"))
    }

    @Test("Multi-line HTML comment is stripped")
    func stripsMultilineHTMLComments() {
        let html = "<p>Before</p><!--\n  Outlook conditional\n  [if mso]>stuff<![endif]\n--><p>After</p>"
        let md = FeedItemRecord.htmlToMarkdown(from: html)
        #expect(!md.contains("<!--"))
        #expect(!md.contains("-->"))
        #expect(!md.contains("[if mso]"))
        #expect(md.contains("Before"))
        #expect(md.contains("After"))
    }

    @Test("Lone bracket artifact does not appear when comment straddles tag boundary")
    func noLoneBracketFromComment() {
        // Simulates the Kotlin Weekly pattern where a multi-line comment causes
        // the char-by-char scanner to leave stray ">" or "[" in the output.
        let html = "<!--[if !mso]><!-- --><p>Content</p>"
        let md = FeedItemRecord.htmlToMarkdown(from: html)
        #expect(!md.contains("-->"))
        #expect(md.contains("Content"))
    }

    // MARK: Issue 2: No code-block from table indentation

    @Test("Lines with 4+ leading spaces from HTML table structure are not code blocks")
    func noCodeBlockFromTableIndent() {
        // HTML table cells often produce lines indented 4+ spaces after tag stripping.
        // Those lines must not trigger Markdown fenced/indented code-block rendering.
        let html = "<table><tr><td>    Hello from cell</td></tr></table>"
        let md = FeedItemRecord.htmlToMarkdown(from: html)
        // Should not have 4+ leading spaces on a content line
        let lines = md.components(separatedBy: "\n")
        for line in lines where line.contains("Hello from cell") {
            let leading = line.prefix(while: { $0 == " " || $0 == "\t" }).count
            #expect(leading < 4, "Line '\(line)' has \(leading) leading spaces — would render as code block")
        }
    }

    // MARK: Issue 3: img → markdown image

    @Test("<img> with alt converts to ![alt](src)")
    func imgConvertedToMarkdownImage() {
        let html = #"<img src="https://example.com/photo.png" alt="A photo">"#
        let md = FeedItemRecord.htmlToMarkdown(from: html)
        #expect(md == "![A photo](https://example.com/photo.png)")
    }

    @Test("<img> without alt converts to ![](src)")
    func imgWithNoAlt() {
        let html = #"<img src="https://example.com/logo.svg">"#
        let md = FeedItemRecord.htmlToMarkdown(from: html)
        #expect(md == "![](https://example.com/logo.svg)")
    }

    @Test("Tracking pixel (width=1) is skipped")
    func imgTrackingPixelWidthSkipped() {
        let html = #"<p>Hello</p><img src="https://track.example.com/t.gif" width="1" height="1"><p>World</p>"#
        let md = FeedItemRecord.htmlToMarkdown(from: html)
        #expect(!md.contains("t.gif"))
        #expect(md.contains("Hello"))
        #expect(md.contains("World"))
    }

    @Test("Tracking pixel (height=1) is skipped")
    func imgTrackingPixelHeightSkipped() {
        let html = #"Before <img src="https://track.example.com/pixel.gif" height="1"> After"#
        let md = FeedItemRecord.htmlToMarkdown(from: html)
        #expect(!md.contains("pixel.gif"))
        #expect(md.contains("Before"))
        #expect(md.contains("After"))
    }

    // MARK: Issue 4: Single-quoted href links

    @Test("Single-quoted href produces markdown link")
    func singleQuotedHrefLink() {
        let html = "<a href='https://example.com'>Visit Example</a>"
        let md = FeedItemRecord.htmlToMarkdown(from: html)
        #expect(md.contains("[Visit Example](https://example.com)"))
    }

    @Test("Double-quoted href still produces markdown link (regression)")
    func doubleQuotedHrefLink() {
        let html = #"<a href="https://swift.org">Swift</a>"#
        let md = FeedItemRecord.htmlToMarkdown(from: html)
        #expect(md.contains("[Swift](https://swift.org)"))
    }

    // MARK: Combined: linked image

    @Test("<a href='url'><img src='x' alt='y'/></a> → [![y](x)](url)")
    func linkedImageFromAnchorWithImg() {
        let html = "<a href='https://example.com'><img src='https://example.com/icon.png' alt='Icon'/></a>"
        let md = FeedItemRecord.htmlToMarkdown(from: html)
        #expect(md.contains("[![Icon](https://example.com/icon.png)](https://example.com)"))
    }

    @Test("Empty-link artifact is eliminated when anchor wraps an img with no alt")
    func noEmptyLinkArtifact() {
        // Previously: <a href="url"><img src="x"/></a> → [](url) (empty link)
        // Now should produce: [![](x)](url)
        let html = #"<a href="https://example.com"><img src="https://example.com/logo.png"/></a>"#
        let md = FeedItemRecord.htmlToMarkdown(from: html)
        #expect(!md.contains("[](https://example.com)"), "Empty link [](url) artifact must not appear")
        #expect(md.contains("(https://example.com)"))
    }
}
