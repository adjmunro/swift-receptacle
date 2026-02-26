import SwiftUI
import SwiftData

/// Project kanban board. Columns are horizontally scrollable; cards are draggable.
/// Any inbox item (email, RSS, note) can be linked to a TodoItem.
struct KanbanBoardView: View {
    let project: Project

    @Query private var allColumns: [KanbanColumn]
    @Query private var allTodos: [TodoItem]

    var columns: [KanbanColumn] {
        allColumns
            .filter { $0.projectId == project.id.uuidString }
            .sorted { $0.ordinal < $1.ordinal }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(columns) { column in
                    KanbanColumnView(column: column, todos: todos(for: column))
                        .frame(width: 260)
                }
                // Add column button
                Button {
                    // TODO Phase 12: add column
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(column.title)
                .font(.headline)
                .padding(.horizontal, 8)

            ForEach(todos) { todo in
                KanbanCardView(todo: todo)
            }

            Button {
                // TODO Phase 12: add card
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
        .background(Color(
#if os(macOS)
            .windowBackground
#else
            .secondarySystemBackground
#endif
        ))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 1)
    }
}
