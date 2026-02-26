import Foundation

// MARK: - ProjectRecord

/// Pure-Swift value type mirroring the SwiftData `Project` @Model.
public struct ProjectRecord: Identifiable, Sendable {
    public var id: String
    public var name: String
    public var colorHex: String?
    /// Ordered column IDs; sorted by `KanbanColumnRecord.ordinal` when retrieved.
    public var columnIds: [String]

    public init(
        id: String = UUID().uuidString,
        name: String,
        colorHex: String? = nil,
        columnIds: [String] = []
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.columnIds = columnIds
    }
}

// MARK: - KanbanColumnRecord

/// Pure-Swift value type mirroring the SwiftData `KanbanColumn` @Model.
public struct KanbanColumnRecord: Identifiable, Sendable {
    public var id: String
    public var title: String
    public var ordinal: Int
    public var projectId: String

    public init(
        id: String = UUID().uuidString,
        title: String,
        ordinal: Int = 0,
        projectId: String
    ) {
        self.id = id
        self.title = title
        self.ordinal = ordinal
        self.projectId = projectId
    }
}

// MARK: - TodoItemRecord

/// Pure-Swift value type mirroring the SwiftData `TodoItem` @Model.
public struct TodoItemRecord: Identifiable, Sendable {
    public var id: String
    public var title: String
    public var itemDescription: String
    public var dueDate: Date?
    public var tagIds: [String]
    /// IDs of emails, notes, or RSS items linked to this task.
    public var linkedItemIds: [String]
    public var projectId: String
    public var columnId: String
    public var ordinal: Int
    public var isCompleted: Bool

    public init(
        id: String = UUID().uuidString,
        title: String,
        itemDescription: String = "",
        dueDate: Date? = nil,
        tagIds: [String] = [],
        linkedItemIds: [String] = [],
        projectId: String,
        columnId: String,
        ordinal: Int = 0,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.title = title
        self.itemDescription = itemDescription
        self.dueDate = dueDate
        self.tagIds = tagIds
        self.linkedItemIds = linkedItemIds
        self.projectId = projectId
        self.columnId = columnId
        self.ordinal = ordinal
        self.isCompleted = isCompleted
    }
}
