import Foundation
import SwiftData

/// A cross-cutting label that can be applied to emails, feed articles, notes,
/// saved links, and todo items alike.
///
/// Tags support hierarchy via `parentTagId` (e.g. "Work" → "Work/Projects").
@Model
final class Tag {
    var id: UUID
    var name: String
    var parentTagId: String?
    /// Hex colour string (e.g. "#FF5733"), or nil for system default
    var colorHex: String?

    init(name: String, parentTagId: String? = nil, colorHex: String? = nil) {
        self.id = UUID()
        self.name = name
        self.parentTagId = parentTagId
        self.colorHex = colorHex
    }

    /// Full hierarchical path, resolved lazily by the caller (e.g. "Work/Projects/Receptacle")
    var displayPath: String { name }
}
