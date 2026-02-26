// ReceptacleTests/AttachmentMatcherTests.swift
//
// No `import Foundation` — only `import Testing` + `@testable import Receptacle`.
// Fully CLI-compatible (avoids the _Testing_Foundation overlay).

import Testing
@testable import Receptacle

@Suite("Phase 7 — AttachmentMatcher")
struct AttachmentMatcherTests {

    let matcher = AttachmentMatcher()

    // MARK: MIME type filter

    @Test("empty mimeTypes list passes all MIME types")
    func emptyMIMEListPassesAll() {
        let action = AttachmentAction(
            mimeTypes: [],
            saveDestination: .iCloudDrive(subfolder: "Test")
        )
        #expect(matcher.matchesMIMEType("application/pdf", action: action))
        #expect(matcher.matchesMIMEType("image/png", action: action))
        #expect(matcher.matchesMIMEType("text/plain", action: action))
    }

    @Test("matching MIME type passes filter")
    func matchingMIMETypePasses() {
        let action = AttachmentAction(
            mimeTypes: ["application/pdf"],
            saveDestination: .iCloudDrive(subfolder: "Receipts")
        )
        #expect(matcher.matchesMIMEType("application/pdf", action: action))
    }

    @Test("non-matching MIME type skips")
    func nonMatchingMIMETypeSkips() {
        let action = AttachmentAction(
            mimeTypes: ["application/pdf"],
            saveDestination: .iCloudDrive(subfolder: "Receipts")
        )
        #expect(!matcher.matchesMIMEType("image/jpeg", action: action))
        #expect(!matcher.matchesMIMEType("text/plain", action: action))
    }

    @Test("MIME type matching is case-insensitive")
    func mimeTypeCaseInsensitive() {
        let action = AttachmentAction(
            mimeTypes: ["application/PDF"],
            saveDestination: .iCloudDrive(subfolder: "Receipts")
        )
        #expect(matcher.matchesMIMEType("application/pdf", action: action))
        #expect(matcher.matchesMIMEType("APPLICATION/PDF", action: action))
    }

    @Test("multiple MIME types: any match passes")
    func multipleMIMETypesAnyMatch() {
        let action = AttachmentAction(
            mimeTypes: ["application/pdf", "image/png"],
            saveDestination: .iCloudDrive(subfolder: "Docs")
        )
        #expect(matcher.matchesMIMEType("application/pdf", action: action))
        #expect(matcher.matchesMIMEType("image/png", action: action))
        #expect(!matcher.matchesMIMEType("audio/mp3", action: action))
    }

    // MARK: Filename pattern filter

    @Test("nil filenamePattern passes all filenames")
    func nilPatternPassesAll() {
        let action = AttachmentAction(
            filenamePattern: nil,
            mimeTypes: [],
            saveDestination: .iCloudDrive(subfolder: "Test")
        )
        #expect(matcher.matchesFilename("receipt.pdf", action: action))
        #expect(matcher.matchesFilename("photo.jpg", action: action))
    }

    @Test("matching filename pattern passes")
    func matchingPatternPasses() {
        let action = AttachmentAction(
            filenamePattern: "receipt",
            mimeTypes: [],
            saveDestination: .iCloudDrive(subfolder: "Receipts")
        )
        #expect(matcher.matchesFilename("amazon-receipt-2026.pdf", action: action))
        #expect(matcher.matchesFilename("RECEIPT_001.pdf", action: action))
    }

    @Test("non-matching filename pattern skips")
    func nonMatchingPatternSkips() {
        let action = AttachmentAction(
            filenamePattern: "invoice",
            mimeTypes: [],
            saveDestination: .iCloudDrive(subfolder: "Invoices")
        )
        #expect(!matcher.matchesFilename("receipt.pdf", action: action))
        #expect(!matcher.matchesFilename("photo.jpg", action: action))
    }

    @Test("filename pattern matching is case-insensitive")
    func patternMatchingCaseInsensitive() {
        let action = AttachmentAction(
            filenamePattern: "Invoice",
            mimeTypes: [],
            saveDestination: .iCloudDrive(subfolder: "Invoices")
        )
        #expect(matcher.matchesFilename("invoice_2026.pdf", action: action))
        #expect(matcher.matchesFilename("INVOICE_2026.PDF", action: action))
    }

    // MARK: Combined filter

    @Test("both filters must pass for matches() to return true")
    func combinedFilterBothMustPass() {
        let action = AttachmentAction(
            filenamePattern: "receipt",
            mimeTypes: ["application/pdf"],
            saveDestination: .iCloudDrive(subfolder: "Receipts")
        )
        // Both pass
        #expect(matcher.matches(filename: "amazon-receipt.pdf",
                                mimeType: "application/pdf", action: action))
        // MIME fails
        #expect(!matcher.matches(filename: "amazon-receipt.pdf",
                                 mimeType: "image/jpeg", action: action))
        // Filename fails
        #expect(!matcher.matches(filename: "photo.pdf",
                                 mimeType: "application/pdf", action: action))
        // Both fail
        #expect(!matcher.matches(filename: "photo.jpg",
                                 mimeType: "image/jpeg", action: action))
    }

    // MARK: skipReason

    @Test("skipReason returns nil when attachment matches")
    func skipReasonNilWhenMatches() {
        let action = AttachmentAction(
            mimeTypes: ["application/pdf"],
            saveDestination: .iCloudDrive(subfolder: "Docs")
        )
        let reason = matcher.skipReason(filename: "doc.pdf",
                                         mimeType: "application/pdf",
                                         action: action)
        #expect(reason == nil)
    }

    @Test("skipReason returns message when MIME doesn't match")
    func skipReasonForMIMEMismatch() {
        let action = AttachmentAction(
            mimeTypes: ["application/pdf"],
            saveDestination: .iCloudDrive(subfolder: "Docs")
        )
        let reason = matcher.skipReason(filename: "photo.jpg",
                                         mimeType: "image/jpeg",
                                         action: action)
        #expect(reason != nil)
        #expect(reason?.contains("image/jpeg") == true)
    }
}
