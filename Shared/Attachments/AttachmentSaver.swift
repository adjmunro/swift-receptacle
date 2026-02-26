import Foundation
import Receptacle   // AttachmentAction, AttachmentSaveDestination, AttachmentMatcher

// MARK: - AttachmentSaver

/// Saves email attachments to iCloud Drive or a local folder according to
/// `AttachmentAction` rules defined on an `Entity`.
///
/// Uses `AttachmentMatcher` (ReceptacleCore) for the pure-logic MIME-type and
/// filename filters, then performs the actual file I/O here.
///
/// ## Typical call site (in the app-layer RuleEngine evaluation loop):
/// ```swift
/// for subRule in entity.subRules {
///     guard let attachmentAction = subRule.attachmentAction else { continue }
///     for attachment in emailItem.attachments {
///         let result = await saver.save(
///             data: attachment.data,
///             filename: attachment.filename,
///             mimeType: attachment.mimeType,
///             action: attachmentAction
///         )
///         switch result {
///         case .saved(let url):   logger.info("Saved to \(url)")
///         case .skipped(let why): logger.debug("Skipped: \(why)")
///         case .failed(let err):  logger.error("Save failed: \(err)")
///         }
///     }
/// }
/// ```
public struct AttachmentSaver: Sendable {

    private let matcher = AttachmentMatcher()

    public init() {}

    // MARK: - Save result

    public enum SaveResult: Sendable {
        case saved(to: URL)
        case skipped(reason: String)
        case failed(Error)
    }

    // MARK: - Main entry point

    /// Saves a single attachment according to the given `AttachmentAction` rule.
    ///
    /// - Parameters:
    ///   - data:     Raw attachment bytes.
    ///   - filename: Original filename from the email (e.g. `"receipt.pdf"`).
    ///   - mimeType: MIME type (e.g. `"application/pdf"`).
    ///   - action:   The rule specifying destination and optional filters.
    /// - Returns:    `.saved`, `.skipped`, or `.failed`.
    public func save(
        data: Data,
        filename: String,
        mimeType: String,
        action: AttachmentAction
    ) async -> SaveResult {

        // 1. Filter check (pure logic — no I/O)
        if let reason = matcher.skipReason(filename: filename,
                                            mimeType: mimeType,
                                            action: action) {
            return .skipped(reason: reason)
        }

        // 2. Resolve destination URL
        let destinationURL: URL
        switch action.saveDestination {

        case .iCloudDrive(let subfolder):
            guard let base = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
                return .failed(AttachmentSaverError.iCloudUnavailable)
            }
            // ~/Library/Mobile Documents/<container>/Documents/<subfolder>/<filename>
            let dir = base
                .appendingPathComponent("Documents", isDirectory: true)
                .appendingPathComponent(subfolder, isDirectory: true)
            destinationURL = dir.appendingPathComponent(filename)

        case .localFolder(let bookmarkData):
            var isStale = false
            let folderURL: URL
            do {
                folderURL = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
            } catch {
                return .failed(AttachmentSaverError.invalidBookmark)
            }
            destinationURL = folderURL.appendingPathComponent(filename)
        }

        // 3. Write file
        do {
            let dir = destinationURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir,
                                                     withIntermediateDirectories: true)
            try data.write(to: destinationURL, options: .atomic)
            return .saved(to: destinationURL)
        } catch {
            return .failed(error)
        }
    }

    // MARK: - Batch variant

    /// Processes all attachments for a given email against all sub-rules that
    /// have an `attachmentAction`. Useful in the sync pipeline.
    public func processAttachments(
        _ attachments: [(data: Data, filename: String, mimeType: String)],
        subRules: [SubRule]
    ) async -> [SaveResult] {
        var results: [SaveResult] = []
        for subRule in subRules {
            guard let action = subRule.attachmentAction else { continue }
            for attachment in attachments {
                let result = await save(
                    data: attachment.data,
                    filename: attachment.filename,
                    mimeType: attachment.mimeType,
                    action: action
                )
                results.append(result)
            }
        }
        return results
    }
}

// MARK: - AttachmentSaverError

public enum AttachmentSaverError: Error, Sendable {
    case iCloudUnavailable
    case invalidBookmark
    case destinationNotWritable(url: URL)
}
