import Foundation

// MARK: - AttachmentSaver

/// Saves email attachments to iCloud Drive or local folder according to `AttachmentAction` rules.
///
/// Phase 7 implementation: unit-tested with fixture emails.
struct AttachmentSaver {

    enum SaveResult {
        case saved(to: URL)
        case skipped(reason: String)
        case failed(Error)
    }

    /// Save a single attachment according to the given action rule.
    ///
    /// - Parameters:
    ///   - data: Raw attachment data
    ///   - filename: Original filename from the email
    ///   - mimeType: MIME type (e.g. "application/pdf")
    ///   - action: The `AttachmentAction` rule specifying destination and filters
    /// - Returns: Whether the file was saved, skipped, or failed
    func save(
        data: Data,
        filename: String,
        mimeType: String,
        action: AttachmentAction
    ) async -> SaveResult {
        // Check MIME type filter
        if !action.mimeTypes.isEmpty,
           !action.mimeTypes.contains(where: { $0.caseInsensitiveCompare(mimeType) == .orderedSame }) {
            return .skipped(reason: "MIME type \(mimeType) not in filter list")
        }

        // Check filename pattern filter
        if let pattern = action.filenamePattern {
            guard filename.range(of: pattern, options: [.caseInsensitive, .regularExpression]) != nil else {
                return .skipped(reason: "Filename \(filename) does not match pattern \(pattern)")
            }
        }

        // Resolve destination URL
        let destinationURL: URL
        switch action.saveDestination {
        case .iCloudDrive(let subfolder):
            guard let container = FileManager.default.url(
                forUbiquityContainerIdentifier: nil
            )?.appending(path: "Documents/\(subfolder)", directoryHint: .isDirectory) else {
                return .failed(AttachmentSaverError.iCloudUnavailable)
            }
            destinationURL = container.appending(path: filename, directoryHint: .notDirectory)

        case .localFolder(let bookmarkData):
            var isStale = false
            guard let folderURL = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) else {
                return .failed(AttachmentSaverError.invalidBookmark)
            }
            destinationURL = folderURL.appending(path: filename, directoryHint: .notDirectory)
        }

        // Write file
        do {
            let dir = destinationURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try data.write(to: destinationURL, options: .atomic)
            return .saved(to: destinationURL)
        } catch {
            return .failed(error)
        }
    }
}

enum AttachmentSaverError: Error, Sendable {
    case iCloudUnavailable
    case invalidBookmark
    case destinationNotWritable(url: URL)
}
