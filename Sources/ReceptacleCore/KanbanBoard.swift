import Foundation

// MARK: - KanbanBoard

/// In-memory kanban board store.
///
/// Manages `ProjectRecord`, `KanbanColumnRecord`, and `TodoItemRecord` value types.
/// The SwiftData-backed `Project`, `KanbanColumn`, and `TodoItem` `@Model`s in `Shared/`
/// mirror this design and sync with SwiftData in Xcode.
///
/// Usage:
/// ```swift
/// let board = KanbanBoard()
/// let project = ProjectRecord(name: "Receptacle")
/// await board.add(project: project)
///
/// let col = KanbanColumnRecord(title: "To Do", ordinal: 0, projectId: project.id)
/// await board.add(column: col)
///
/// // Later — move an item to a different column:
/// await board.moveItem(id: itemId, toColumn: doneColumnId, atOrdinal: 0)
/// ```
public actor KanbanBoard {

    private var projects: [String: ProjectRecord] = [:]
    private var columns:  [String: KanbanColumnRecord] = [:]
    private var items:    [String: TodoItemRecord] = [:]

    public init() {}

    // MARK: - Project CRUD

    /// Add or replace a project.
    public func add(project: ProjectRecord) {
        projects[project.id] = project
    }

    /// Look up a project by ID.
    public func project(id: String) -> ProjectRecord? {
        projects[id]
    }

    /// All projects sorted by name.
    public func allProjects() -> [ProjectRecord] {
        projects.values.sorted { $0.name < $1.name }
    }

    // MARK: - Column CRUD

    /// Add or replace a column, updating the parent project's `columnIds` list.
    public func add(column: KanbanColumnRecord) {
        columns[column.id] = column
        if var project = projects[column.projectId],
           !project.columnIds.contains(column.id) {
            project.columnIds.append(column.id)
            projects[project.id] = project
        }
    }

    /// Look up a column by ID.
    public func column(id: String) -> KanbanColumnRecord? {
        columns[id]
    }

    /// All columns belonging to a project, sorted by `ordinal`.
    public func columns(for projectId: String) -> [KanbanColumnRecord] {
        columns.values
            .filter { $0.projectId == projectId }
            .sorted { $0.ordinal < $1.ordinal }
    }

    // MARK: - Item CRUD

    /// Add or replace a todo item.
    public func add(item: TodoItemRecord) {
        items[item.id] = item
    }

    /// Look up an item by ID.
    public func item(id: String) -> TodoItemRecord? {
        items[id]
    }

    /// All items in a column, sorted by `ordinal`.
    public func items(inColumn columnId: String) -> [TodoItemRecord] {
        items.values
            .filter { $0.columnId == columnId }
            .sorted { $0.ordinal < $1.ordinal }
    }

    /// Remove an item by ID.
    public func remove(itemId: String) {
        items.removeValue(forKey: itemId)
    }

    // MARK: - Move

    /// Move an item to a different column and set its ordinal position.
    ///
    /// - Returns: `true` if the item and target column both exist; `false` otherwise.
    @discardableResult
    public func moveItem(id itemId: String, toColumn columnId: String, atOrdinal ordinal: Int) -> Bool {
        guard var item = items[itemId] else { return false }
        guard columns[columnId] != nil else { return false }
        item.columnId = columnId
        item.ordinal = ordinal
        items[itemId] = item
        return true
    }

    // MARK: - Completion

    /// Toggle the `isCompleted` flag for an item.
    ///
    /// - Returns: `true` if the item was found and toggled; `false` if unknown.
    @discardableResult
    public func toggleComplete(itemId: String) -> Bool {
        guard var item = items[itemId] else { return false }
        item.isCompleted.toggle()
        items[itemId] = item
        return true
    }
}
