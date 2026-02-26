import Foundation

// MARK: - WikilinkParser

/// Detects and resolves `[[wikilink]]` references in Markdown note content.
///
/// Phase 11 implementation. Uses a simple regex approach; Apple's swift-markdown
/// library can be integrated for full AST parsing if needed.
struct WikilinkParser {

    // Matches [[Any Text Here]] including spaces and special chars
    private static let wikilinkPattern = /\[\[([^\[\]]+)\]\]/

    // MARK: - Detection

    /// Returns all wikilink targets found in the given markdown string.
    func extractLinks(from markdown: String) -> [WikilinkMatch] {
        var matches: [WikilinkMatch] = []
        for match in markdown.matches(of: Self.wikilinkPattern) {
            matches.append(WikilinkMatch(
                target: String(match.output.1),
                range: match.range
            ))
        }
        return matches
    }

    /// Replaces `[[target]]` with a resolved note ID if known, or leaves unchanged.
    ///
    /// - Parameters:
    ///   - markdown: Source markdown string
    ///   - resolver: Closure that takes a link target name and returns the note ID (or nil)
    /// - Returns: Processed markdown with links annotated, and resolved ID mappings
    func resolve(
        markdown: String,
        resolver: (String) -> String?
    ) -> ResolvedWikilinks {
        var resolvedIds: [String: String] = [:]
        var unresolvedTargets: [String] = []

        for match in extractLinks(from: markdown) {
            if let noteId = resolver(match.target) {
                resolvedIds[match.target] = noteId
            } else {
                unresolvedTargets.append(match.target)
            }
        }

        return ResolvedWikilinks(
            resolvedIds: resolvedIds,
            unresolvedTargets: unresolvedTargets
        )
    }
}

// MARK: - Supporting Types

struct WikilinkMatch: Sendable {
    /// The text inside [[…]]
    var target: String
    /// Position in the original string
    var range: Range<String.Index>
}

struct ResolvedWikilinks: Sendable {
    /// target name → note ID for links that resolved successfully
    var resolvedIds: [String: String]
    /// Targets that could not be matched to an existing note
    var unresolvedTargets: [String]
}
