// MARK: - AttachmentMatcher

/// Pure-Swift predicate that decides whether a given attachment should be
/// processed by an `AttachmentAction` rule.
///
/// Two independent filters are applied; both must pass for the attachment to match:
///
/// 1. **MIME type filter** — if `action.mimeTypes` is non-empty, the attachment's
///    `mimeType` must appear in the list (case-insensitive). An empty list means
///    "accept all MIME types."
///
/// 2. **Filename pattern filter** — if `action.filenamePattern` is set, the
///    attachment `filename` must contain the pattern as a case-insensitive
///    substring. A nil pattern means "accept all filenames."
///
/// These filters map directly to the tests required by Phase 7:
/// - `test_mimeTypeFilter_skipsNonMatchingAttachments` → `matchesMIMEType`
/// - `test_filenamePatternFilter_skipsNonMatchingFiles` → `matchesFilename`
///
/// The actual file I/O lives in `AttachmentSaver` (Shared/, requires Foundation).
/// Keeping the matching logic here lets it be unit-tested without any framework.
public struct AttachmentMatcher: Sendable {

    public init() {}

    // MARK: - Top-level predicate

    /// Returns `true` if the attachment passes both the MIME type and filename
    /// filters defined in `action`.
    public func matches(filename: String, mimeType: String, action: AttachmentAction) -> Bool {
        matchesMIMEType(mimeType, action: action) && matchesFilename(filename, action: action)
    }

    // MARK: - Individual filter predicates

    /// `true` when the MIME filter passes.
    ///
    /// An empty `action.mimeTypes` list is treated as "accept all".
    public func matchesMIMEType(_ mimeType: String, action: AttachmentAction) -> Bool {
        guard !action.mimeTypes.isEmpty else { return true }   // no filter → accept all
        return action.mimeTypes.contains {
            $0.lowercased() == mimeType.lowercased()
        }
    }

    /// `true` when the filename pattern filter passes.
    ///
    /// A nil `action.filenamePattern` is treated as "accept all".
    /// Matching is case-insensitive substring search — simple and dependency-free.
    /// `AttachmentSaver` (Shared/) additionally supports full regex via Foundation.
    public func matchesFilename(_ filename: String, action: AttachmentAction) -> Bool {
        guard let pattern = action.filenamePattern, !pattern.isEmpty else { return true }
        return filename.lowercased().contains(pattern.lowercased())
    }

    // MARK: - Reason strings (for logging / UI)

    /// Human-readable explanation of why an attachment was skipped.
    /// Returns `nil` if the attachment matches (not skipped).
    public func skipReason(filename: String,
                           mimeType: String,
                           action: AttachmentAction) -> String? {
        if !matchesMIMEType(mimeType, action: action) {
            return "MIME type '\(mimeType)' not in filter \(action.mimeTypes)"
        }
        if !matchesFilename(filename, action: action) {
            return "Filename '\(filename)' does not contain pattern '\(action.filenamePattern ?? "")'"
        }
        return nil
    }
}
