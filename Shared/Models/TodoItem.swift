import Foundation
import SwiftData

// MARK: - Project

/// A kanban board. Items can be linked to emails, RSS posts, or notes.
@Model
final class Project {
    var id: UUID
    var name: String
    var colorHex: String?
    /// Ordered columns; sort by `KanbanColumn.ordinal`
    var columnIds: [String]

    init(name: String, colorHex: String? = nil) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.columnIds = []
    }
}

// MARK: - KanbanColumn

@Model
final class KanbanColumn {
    var id: UUID
    var title: String
    var ordinal: Int
    var projectId: String

    init(title: String, ordinal: Int, projectId: String) {
        self.id = UUID()
        self.title = title
        self.ordinal = ordinal
        self.projectId = projectId
    }
}

// MARK: - TodoItem

@Model
final class TodoItem {
    var id: UUID
    var title: String
    var itemDescription: String
    var dueDate: Date?
    var tagIds: [String]
    /// IDs of emails, notes, or RSS items linked to this task
    var linkedItemIds: [String]
    var projectId: String
    var columnId: String
    var ordinal: Int
    var isCompleted: Bool

    init(
        title: String,
        description: String = "",
        projectId: String,
        columnId: String,
        ordinal: Int = 0
    ) {
        self.id = UUID()
        self.title = title
        self.itemDescription = description
        self.projectId = projectId
        self.columnId = columnId
        self.ordinal = ordinal
        self.tagIds = []
        self.linkedItemIds = []
        self.isCompleted = false
    }
}
