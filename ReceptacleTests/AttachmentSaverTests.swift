// ReceptacleTests/AttachmentSaverTests.swift
//
// IMPORTANT: Excluded from Package.swift CLI build (uses `import Foundation`
// + `import Testing` → triggers _Testing_Foundation overlay). Open in Xcode.

import Foundation
import Testing
@testable import Receptacle

@Suite("Phase 7 — AttachmentSaver (FileManager)")
struct AttachmentSaverTests {

    let saver = AttachmentSaver()
    let tmpDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("ReceptacleTests-AttachmentSaver")

    // MARK: iCloud Drive (local temp dir substitution)

    // Note: iCloud Drive tests require a real iCloud account.
    // This test verifies the code path using a temp directory instead.

    @Test("save to local temp dir writes file at correct path")
    func saveToLocalFolderWritesFile() async throws {
        // Set up a temp directory to act as the destination folder
        let dest = tmpDir.appendingPathComponent("LocalFolder")
        try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        // Create a security-scoped bookmark for the temp directory
        let bookmarkData = try dest.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        let action = AttachmentAction(
            filenamePattern: nil,
            mimeTypes: ["application/pdf"],
            saveDestination: .localFolder(bookmarkData: bookmarkData)
        )
        let pdfData = Data("PDF content".utf8)
        let result = await saver.save(data: pdfData,
                                       filename: "invoice.pdf",
                                       mimeType: "application/pdf",
                                       action: action)

        guard case .saved(let url) = result else {
            Issue.record("Expected .saved but got \(result)")
            return
        }
        #expect(url.lastPathComponent == "invoice.pdf")
        #expect(FileManager.default.fileExists(atPath: url.path))
        let readBack = try Data(contentsOf: url)
        #expect(readBack == pdfData)
    }

    // MARK: MIME type filter

    @Test("mimeTypeFilter skips non-matching attachments")
    func mimeTypeFilterSkipsNonMatching() async {
        let action = AttachmentAction(
            mimeTypes: ["application/pdf"],
            saveDestination: .iCloudDrive(subfolder: "Receipts")
        )
        let result = await saver.save(
            data: Data("image data".utf8),
            filename: "photo.jpg",
            mimeType: "image/jpeg",
            action: action
        )
        guard case .skipped(let reason) = result else {
            Issue.record("Expected .skipped but got \(result)")
            return
        }
        #expect(reason.contains("image/jpeg"))
    }

    // MARK: Filename pattern filter

    @Test("filenamePatternFilter skips non-matching files")
    func filenamePatternFilterSkipsNonMatching() async {
        let action = AttachmentAction(
            filenamePattern: "receipt",
            mimeTypes: [],
            saveDestination: .iCloudDrive(subfolder: "Receipts")
        )
        let result = await saver.save(
            data: Data("pdf data".utf8),
            filename: "photo.pdf",
            mimeType: "application/pdf",
            action: action
        )
        guard case .skipped(let reason) = result else {
            Issue.record("Expected .skipped but got \(result)")
            return
        }
        #expect(reason.contains("photo.pdf"))
    }

    // MARK: Batch processing

    @Test("processAttachments handles empty subRules gracefully")
    func processAttachmentsEmptyRules() async {
        let results = await saver.processAttachments(
            [(data: Data(), filename: "file.pdf", mimeType: "application/pdf")],
            subRules: []
        )
        #expect(results.isEmpty)
    }

    @Test("processAttachments skips subRules without attachmentAction")
    func processAttachmentsSkipsRulesWithoutAction() async {
        let subRule = SubRule(
            matchType: .subjectContains,
            pattern: "Order",
            action: .keepAll,
            attachmentAction: nil   // no attachment action
        )
        let results = await saver.processAttachments(
            [(data: Data(), filename: "file.pdf", mimeType: "application/pdf")],
            subRules: [subRule]
        )
        #expect(results.isEmpty)
    }
}
