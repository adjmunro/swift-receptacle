import Foundation

// MARK: - WikilinkParser

/// Detects and resolves `[[wikilink]]` references in Markdown note content.
public struct WikilinkParser: Sendable {

    // nonisolated(unsafe): Regex is immutable after init; safe for concurrent reads
    private nonisolated(unsafe) static let wikilinkPattern = /\[\[([^\[\]]+)\]\]/

    public init() {}

    // MARK: - Detection

    /// Returns all wikilink targets found in the given markdown string.
    public func extractLinks(from markdown: String) -> [WikilinkMatch] {
        var matches: [WikilinkMatch] = []
        for match in markdown.matches(of: Self.wikilinkPattern) {
            matches.append(WikilinkMatch(
                target: String(match.output.1),
                range: match.range
            ))
        }
        return matches
    }

    /// Resolves `[[target]]` links to note IDs.
    ///
    /// - Parameters:
    ///   - markdown: Source markdown string
    ///   - resolver: Closure that maps a link target name to a note ID (or nil if unknown)
    public func resolve(
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

public struct WikilinkMatch: Sendable {
    public var target: String
    public var range: Range<String.Index>
}

public struct ResolvedWikilinks: Sendable {
    public var resolvedIds: [String: String]
    public var unresolvedTargets: [String]
}
