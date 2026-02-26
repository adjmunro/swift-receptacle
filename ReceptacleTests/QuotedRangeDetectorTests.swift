// ReceptacleTests/QuotedRangeDetectorTests.swift
//
// No `import Foundation` — only `import Testing` + `@testable import Receptacle`.
// This keeps the file buildable by CLI tools (avoids the _Testing_Foundation overlay).
// Open in Xcode or include in `swift test` target.

import Testing
@testable import Receptacle

@Suite("Phase 6 — QuotedRangeDetector")
struct QuotedRangeDetectorTests {

    let detector = QuotedRangeDetector()

    // MARK: Blockquote

    @Test("detectsBlockquote: <blockquote> element detected")
    func detectsBlockquote() {
        let html = "Hello <blockquote>On Wed, you wrote:\nSome reply text</blockquote> Cheers"
        let ranges = detector.detect(in: html)
        #expect(ranges.contains { $0.kind == .blockquote },
                "HTML blockquote must be detected")
    }

    @Test("detectsBlockquote: range covers tag content")
    func blockquoteRangeCoverContent() {
        let html = "Before <blockquote>Quoted body</blockquote> After"
        let ranges = detector.detect(in: html)
        let bq = ranges.first(where: { $0.kind == .blockquote })
        #expect(bq != nil)
        if let bq {
            #expect(html[bq.range].contains("Quoted body"))
        }
    }

    @Test("detectsBlockquote: multiple blockquotes")
    func detectsMultipleBlockquotes() {
        let html = "<blockquote>First</blockquote> middle <blockquote>Second</blockquote>"
        let ranges = detector.detect(in: html)
        let blockquotes = ranges.filter { $0.kind == .blockquote }
        #expect(blockquotes.count == 2, "two blockquotes must be detected")
    }

    @Test("detectsBlockquote: case insensitive")
    func blockquoteCaseInsensitive() {
        let html = "Text <BLOCKQUOTE>Quoted</BLOCKQUOTE> more"
        let ranges = detector.detect(in: html)
        #expect(ranges.contains { $0.kind == .blockquote })
    }

    // MARK: GT-prefix

    @Test("detectsGtPrefix: single > line detected")
    func detectsGtPrefix() {
        let text = "My reply.\n> Original message line\nEnd."
        let ranges = detector.detect(in: text)
        #expect(ranges.contains { $0.kind == .gtPrefix },
                "> prefixed line must be detected")
    }

    @Test("detectsGtPrefix: consecutive > lines merged into one range")
    func gtPrefixMergesConsecutiveLines() {
        let text = "Reply.\n> Line one\n> Line two\n> Line three\nEnd."
        let ranges = detector.detect(in: text)
        let gtRanges = ranges.filter { $0.kind == .gtPrefix }
        #expect(gtRanges.count == 1, "consecutive > lines should be one range")
    }

    @Test("detectsGtPrefix: separated > blocks produce separate ranges")
    func gtPrefixSeparatedBlocks() {
        let text = "> First block\nPlain line\n> Second block"
        let ranges = detector.detect(in: text)
        let gtRanges = ranges.filter { $0.kind == .gtPrefix }
        #expect(gtRanges.count == 2, "separated > blocks should be two ranges")
    }

    // MARK: Signature

    @Test("detectsSignatureSeparator: -- separator detected")
    func detectsSignatureSeparator() {
        let text = "Hi there.\n-- \nJohn Smith\njohn@example.com"
        let ranges = detector.detect(in: text)
        #expect(ranges.contains { $0.kind == .signature },
                "email signature separator must be detected")
    }

    @Test("detectsSignatureSeparator: signature range extends to end")
    func signatureRangeExtendsToEnd() {
        let text = "Body text.\n-- \nSig line 1\nSig line 2"
        let ranges = detector.detect(in: text)
        let sig = ranges.first(where: { $0.kind == .signature })
        #expect(sig != nil)
        if let sig {
            #expect(sig.range.upperBound == text.endIndex,
                    "signature range must extend to end of string")
        }
    }

    // MARK: Plain message

    @Test("returnsEmptyForPlainMessage")
    func returnsEmptyForPlainMessage() {
        let text = "Hi, just checking in. Hope you're well!"
        let ranges = detector.detect(in: text)
        #expect(ranges.isEmpty, "plain text must produce no quoted ranges")
    }

    @Test("returnsEmptyForEmptyString")
    func returnsEmptyForEmptyString() {
        let ranges = detector.detect(in: "")
        #expect(ranges.isEmpty)
    }

    // MARK: Convenience helpers

    @Test("collapsedText returns text before first quoted range")
    func collapsedTextReturnsPreQuotedText() {
        let text = "My reply here.\n> You wrote this.\n> And this.\nCheers."
        let collapsed = detector.collapsedText(for: text)
        #expect(collapsed == "My reply here.\n")
    }

    @Test("collapsedText returns full text when no quoted ranges")
    func collapsedTextReturnsFullWhenNoQuotes() {
        let text = "Plain message with no quotes."
        let collapsed = detector.collapsedText(for: text)
        #expect(collapsed == text)
    }

    @Test("hasQuotedContent returns true for blockquote")
    func hasQuotedContentTrue() {
        let html = "<blockquote>Quoted</blockquote>"
        #expect(detector.hasQuotedContent(in: html))
    }

    @Test("hasQuotedContent returns false for plain text")
    func hasQuotedContentFalse() {
        #expect(!detector.hasQuotedContent(in: "No quotes here."))
    }
}
