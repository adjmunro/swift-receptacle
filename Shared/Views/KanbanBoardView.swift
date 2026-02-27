import SwiftUI
import SwiftData
import Receptacle  // KanbanBoard, TodoItemRecord

/// Project kanban board. Columns are horizontally scrollable; cards are draggable.
/// Any inbox item (email, RSS, note) can be linked to a `TodoItem`.
///
/// ## Drag-to-reorder
/// Each `KanbanCardView` is `.draggable` — dragging a card and dropping it onto
/// a `KanbanColumnView`'s drop zone moves the item via `KanbanBoard.moveItem(id:toColumn:atOrdinal:)`
/// and syncs the new position to SwiftData.
struct KanbanBoardView: View {
    let project: Project
    let board: KanbanBoard

    @Environment(\.modelContext) private var modelContext

    @Query private var allColumns: [KanbanColumn]
    @Query private var allTodos: [TodoItem]

    @State private var showAddColumn = false
    @State private var newColumnTitle = ""

    var columns: [KanbanColumn] {
        allColumns
            .filter { $0.projectId == project.id.uuidString }
            .sorted { $0.ordinal < $1.ordinal }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(columns) { column in
                    KanbanColumnView(
                        column: column,
                        todos: todos(for: column),
                        board: board
                    )
                    .frame(width: 260)
                }
                // Add column button
                Button {
                    newColumnTitle = ""
                    showAddColumn = true
                } label: {
                    Label("Add Column", systemImage: "plus")
                        .frame(width: 260, height: 60)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            .padding()
        }
        .navigationTitle(project.name)
        .sheet(isPresented: $showAddColumn) {
            addColumnSheet
        }
    }

    private var addColumnSheet: some View {
        NavigationStack {
            Form {
                Section("Column Name") {
                    TextField("e.g. To Do, In Progress, Done", text: $newColumnTitle)
                }
            }
            .navigationTitle("Add Column")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAddColumn = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard !newColumnTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        let ordinal = columns.count
                        let newCol = KanbanColumn(
                            title: newColumnTitle.trimmingCharacters(in: .whitespaces),
                            ordinal: ordinal,
                            projectId: project.id.uuidString
                        )
                        modelContext.insert(newCol)
                        Task {
                            await board.add(column: KanbanColumnRecord(
                                id: newCol.id.uuidString,
                                title: newCol.title,
                                ordinal: ordinal,
                                projectId: project.id.uuidString
                            ))
                        }
                        showAddColumn = false
                    }
                    .disabled(newColumnTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.height(200)])
    }

    private func todos(for column: KanbanColumn) -> [TodoItem] {
        allTodos
            .filter { $0.columnId == column.id.uuidString }
            .sorted { $0.ordinal < $1.ordinal }
    }
}

struct KanbanColumnView: View {
    let column: KanbanColumn
    let todos: [TodoItem]
    let board: KanbanBoard

    @Environment(\.modelContext) private var modelContext

    @State private var showAddCard = false
    @State private var newCardTitle = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(column.title)
                .font(.headline)
                .padding(.horizontal, 8)

            ForEach(todos) { todo in
                KanbanCardView(todo: todo)
                    .draggable(todo.id.uuidString) {
                        // Drag preview
                        KanbanCardView(todo: todo)
                            .frame(width: 220)
                            .opacity(0.85)
                    }
            }

            // Drop zone at the bottom of each column
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .dropDestination(for: String.self) { itemIds, _ in
                    guard let itemId = itemIds.first else { return false }
                    let colId = column.id.uuidString
                    let ordinal = todos.count
                    Task { @MainActor in
                        await board.moveItem(id: itemId, toColumn: colId, atOrdinal: ordinal)
                        // Sync moved item position back to SwiftData
                        if let uuid = UUID(uuidString: itemId),
                           let todo = try? modelContext.fetch(
                               FetchDescriptor<TodoItem>(predicate: #Predicate { $0.id == uuid })
                           ).first {
                            todo.columnId = colId
                            todo.ordinal = ordinal
                        }
                    }
                    return true
                }

            Button {
                newCardTitle = ""
                showAddCard = true
            } label: {
                Label("Add Card", systemImage: "plus")
                    .font(.caption)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderless)
        }
        .padding(8)
        .background(Color.secondary.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .sheet(isPresented: $showAddCard) {
            addCardSheet
        }
    }

    private var addCardSheet: some View {
        NavigationStack {
            Form {
                Section("Card Title") {
                    TextField("e.g. Fix the login bug", text: $newCardTitle)
                }
            }
            .navigationTitle("Add Card")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAddCard = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let title = newCardTitle.trimmingCharacters(in: .whitespaces)
                        guard !title.isEmpty else { return }
                        let ordinal = todos.count
                        let newTodo = TodoItem(
                            title: title,
                            projectId: column.projectId,
                            columnId: column.id.uuidString,
                            ordinal: ordinal
                        )
                        modelContext.insert(newTodo)
                        Task {
                            await board.add(item: TodoItemRecord(
                                id: newTodo.id.uuidString,
                                title: title,
                                projectId: column.projectId,
                                columnId: column.id.uuidString,
                                ordinal: ordinal
                            ))
                        }
                        showAddCard = false
                    }
                    .disabled(newCardTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.height(200)])
    }
}

struct KanbanCardView: View {
    let todo: TodoItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(todo.title)
                .font(.subheadline.weight(.medium))
            if !todo.itemDescription.isEmpty {
                Text(todo.itemDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if let due = todo.dueDate {
                Label(due.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                    .font(.caption2)
                    .foregroundStyle(due < Date() ? .red : .secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
#if os(macOS)
        .background(.windowBackground)
#else
        .background(Color(.secondarySystemBackground))
#endif
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 1)
    }
}
