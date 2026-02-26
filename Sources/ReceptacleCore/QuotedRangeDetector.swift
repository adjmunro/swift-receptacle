import Foundation

// MARK: - QuotedRange

/// A detected region of quoted or signature content within an email body.
public struct QuotedRange: Sendable {

    /// What kind of quoting mechanism was detected.
    public enum Kind: String, Sendable {
        case blockquote   // HTML <blockquote>...</blockquote>
        case gtPrefix     // Plain-text lines beginning with ">"
        case signature    // Email signature following a "-- " separator line
    }

    public var range: Range<String.Index>
    public var kind: Kind

    public init(range: Range<String.Index>, kind: Kind) {
        self.range = range
        self.kind = kind
    }
}

// MARK: - QuotedRangeDetector

/// Detects quoted / signature regions in an email body (HTML or plain text).
///
/// Three detection strategies run in order; results are merged and sorted
/// by their lower bound:
///
/// 1. **Blockquote** — `<blockquote …>…</blockquote>` pairs in HTML.
///    Handles nested blockquotes by scanning sequentially (outermost wins).
///
/// 2. **GT-prefix** — one or more consecutive plain-text lines that begin
///    with `>` (the RFC 2822 quoting convention). Consecutive quoted lines
///    are merged into a single `QuotedRange`.
///
/// 3. **Signature** — a line consisting solely of `"-- "` (two hyphens and
///    a trailing space, per RFC 3676). Everything from that separator line
///    through the end of the message is marked `.signature`.
///
/// Usage:
/// ```swift
/// let detector = QuotedRangeDetector()
/// let ranges = detector.detect(in: emailBody)
/// let hasQuotedContent = !ranges.isEmpty
/// let previewBody = ranges.first.map { String(emailBody[..<$0.range.lowerBound]) }
///                   ?? emailBody
/// ```
public struct QuotedRangeDetector: Sendable {

    public init() {}

    /// Returns detected quoted ranges, sorted by location.
    public func detect(in text: String) -> [QuotedRange] {
        var result: [QuotedRange] = []
        result += detectBlockquotes(in: text)
        result += detectGtPrefix(in: text)
        result += detectSignature(in: text)
        return result.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }

    // MARK: - Strategy 1: HTML blockquotes

    private func detectBlockquotes(in text: String) -> [QuotedRange] {
        var ranges: [QuotedRange] = []
        var searchStart = text.startIndex

        while searchStart < text.endIndex {
            // Find the opening tag (handles attributes like <blockquote type="cite">)
            guard let openTag = text.range(of: "<blockquote",
                                            options: .caseInsensitive,
                                            range: searchStart..<text.endIndex),
                  let openClose = text.range(of: ">",
                                              range: openTag.upperBound..<text.endIndex),
                  let closeTag = text.range(of: "</blockquote>",
                                             options: .caseInsensitive,
                                             range: openClose.upperBound..<text.endIndex)
            else { break }

            let fullRange = openTag.lowerBound..<closeTag.upperBound
            ranges.append(QuotedRange(range: fullRange, kind: .blockquote))
            searchStart = closeTag.upperBound
        }

        return ranges
    }

    // MARK: - Strategy 2: GT-prefix plain-text quoting

    private func detectGtPrefix(in text: String) -> [QuotedRange] {
        var ranges: [QuotedRange] = []
        var groupStart: String.Index? = nil
        var pos = text.startIndex

        // Walk line by line using character search
        while pos < text.endIndex {
            let lineEnd = text[pos...].firstIndex(of: "\n") ?? text.endIndex
            let line = text[pos..<lineEnd]

            if line.hasPrefix(">") {
                // Start or continue a quoted block
                if groupStart == nil { groupStart = pos }
            } else {
                // Non-quoted line — flush any open group
                if let start = groupStart {
                    ranges.append(QuotedRange(range: start..<pos, kind: .gtPrefix))
                    groupStart = nil
                }
            }

            // Advance past the line and its newline character
            pos = lineEnd < text.endIndex ? text.index(after: lineEnd) : text.endIndex
        }

        // Flush a trailing quoted block that runs to end-of-string
        if let start = groupStart {
            ranges.append(QuotedRange(range: start..<text.endIndex, kind: .gtPrefix))
        }

        return ranges
    }

    // MARK: - Strategy 3: Email signature separator

    private func detectSignature(in text: String) -> [QuotedRange] {
        // RFC 3676 §4.3: the signature separator is "-- " on its own line.
        // We look for "\n-- " (newline + "-- ") — the most common encoding.
        // Also handle "\n-- \r\n" (Windows line endings) and start-of-string.
        let candidates = ["\n-- \n", "\n-- \r\n", "\n-- "]
        for separator in candidates {
            if let hit = text.range(of: separator) {
                // The signature begins at the character after the leading newline
                let sigStart = text.index(after: hit.lowerBound)
                return [QuotedRange(range: sigStart..<text.endIndex, kind: .signature)]
            }
        }
        // Check for separator at the very beginning (unusual but valid)
        if text.hasPrefix("-- \n") || text.hasPrefix("-- \r\n") || text.hasPrefix("-- ") {
            return [QuotedRange(range: text.startIndex..<text.endIndex, kind: .signature)]
        }
        return []
    }
}

// MARK: - Convenience extensions

extension QuotedRangeDetector {

    /// Returns the text content that should be visible when quoted sections
    /// are collapsed — everything before the first quoted range.
    ///
    /// Returns the full text if no quoted ranges are detected.
    public func collapsedText(for text: String) -> String {
        let ranges = detect(in: text)
        guard let first = ranges.first else { return text }
        return String(text[..<first.range.lowerBound])
    }

    /// True if the text contains at least one quoted range.
    public func hasQuotedContent(in text: String) -> Bool {
        !detect(in: text).isEmpty
    }
}
