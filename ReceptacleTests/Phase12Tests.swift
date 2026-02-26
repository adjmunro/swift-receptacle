// Phase12Tests.swift
// CLI-compatible: only `import Testing` (no Foundation).
// Run via: swift test  (or open in Xcode for full output)

import Testing
import Receptacle

// MARK: - KanbanRecord Tests

@Suite("KanbanRecord")
struct KanbanRecordTests {

    @Test func projectRecord() {
        let p = ProjectRecord(id: "p1", name: "My Project", colorHex: "#FF0000")
        #expect(p.id == "p1")
        #expect(p.name == "My Project")
        #expect(p.colorHex == "#FF0000")
        #expect(p.columnIds.isEmpty)
    }

    @Test func kanbanColumnRecord() {
        let col = KanbanColumnRecord(id: "c1", title: "To Do", ordinal: 0, projectId: "p1")
        #expect(col.id == "c1")
        #expect(col.title == "To Do")
        #expect(col.ordinal == 0)
        #expect(col.projectId == "p1")
    }

    @Test func todoItemRecord() {
        let item = TodoItemRecord(
            id: "t1",
            title: "Write tests",
            itemDescription: "TDD first",
            projectId: "p1",
            columnId: "c1",
            ordinal: 2
        )
        #expect(item.id == "t1")
        #expect(item.title == "Write tests")
        #expect(item.itemDescription == "TDD first")
        #expect(item.columnId == "c1")
        #expect(item.ordinal == 2)
        #expect(item.isCompleted == false)
        #expect(item.tagIds.isEmpty)
        #expect(item.linkedItemIds.isEmpty)
    }
}

// MARK: - KanbanBoard Tests

@Suite("KanbanBoard")
struct KanbanBoardTests {

    @Test func addAndRetrieveProject() async {
        let board = KanbanBoard()
        let project = ProjectRecord(id: "p1", name: "My Project")
        await board.add(project: project)
        let retrieved = await board.project(id: "p1")
        #expect(retrieved?.name == "My Project")
        #expect(retrieved?.columnIds.isEmpty == true)
    }

    @Test func addColumnUpdatesProject() async {
        let board = KanbanBoard()
        await board.add(project: ProjectRecord(id: "p1", name: "Project"))
        let col = KanbanColumnRecord(id: "c1", title: "To Do", ordinal: 0, projectId: "p1")
        await board.add(column: col)

        let columns = await board.columns(for: "p1")
        #expect(columns.count == 1)
        #expect(columns[0].title == "To Do")

        let proj = await board.project(id: "p1")
        #expect(proj?.columnIds.contains("c1") == true)
    }

    @Test func columnsOrderedByOrdinal() async {
        let board = KanbanBoard()
        await board.add(project: ProjectRecord(id: "p2", name: "Ordered"))
        await board.add(column: KanbanColumnRecord(id: "c3", title: "Done",        ordinal: 2, projectId: "p2"))
        await board.add(column: KanbanColumnRecord(id: "c1", title: "To Do",       ordinal: 0, projectId: "p2"))
        await board.add(column: KanbanColumnRecord(id: "c2", title: "In Progress", ordinal: 1, projectId: "p2"))

        let cols = await board.columns(for: "p2")
        #expect(cols.count == 3)
        #expect(cols[0].title == "To Do")
        #expect(cols[1].title == "In Progress")
        #expect(cols[2].title == "Done")
    }

    @Test func itemsInColumnOrderedByOrdinal() async {
        let board = KanbanBoard()
        await board.add(item: TodoItemRecord(id: "t3", title: "Third",  projectId: "p", columnId: "c", ordinal: 2))
        await board.add(item: TodoItemRecord(id: "t1", title: "First",  projectId: "p", columnId: "c", ordinal: 0))
        await board.add(item: TodoItemRecord(id: "t2", title: "Second", projectId: "p", columnId: "c", ordinal: 1))

        let items = await board.items(inColumn: "c")
        #expect(items[0].title == "First")
        #expect(items[1].title == "Second")
        #expect(items[2].title == "Third")
    }

    @Test func moveItemBetweenColumns() async {
        let board = KanbanBoard()
        await board.add(project: ProjectRecord(id: "p", name: "Test"))
        await board.add(column: KanbanColumnRecord(id: "col-a", title: "A", ordinal: 0, projectId: "p"))
        await board.add(column: KanbanColumnRecord(id: "col-b", title: "B", ordinal: 1, projectId: "p"))
        await board.add(item: TodoItemRecord(id: "item1", title: "Task", projectId: "p", columnId: "col-a", ordinal: 0))

        let moved = await board.moveItem(id: "item1", toColumn: "col-b", atOrdinal: 0)
        #expect(moved, "moveItem returns true on success")

        let updatedItem = await board.item(id: "item1")
        #expect(updatedItem?.columnId == "col-b", "item moved to col-b")
        #expect(updatedItem?.ordinal == 0, "ordinal updated")

        let inA = await board.items(inColumn: "col-a")
        let inB = await board.items(inColumn: "col-b")
        #expect(inA.isEmpty, "col-a is empty after move")
        #expect(inB.count == 1, "col-b has 1 item")
    }

    @Test func moveItemToUnknownColumn() async {
        let board = KanbanBoard()
        await board.add(item: TodoItemRecord(id: "t1", title: "Task", projectId: "p", columnId: "c1", ordinal: 0))
        let moved = await board.moveItem(id: "t1", toColumn: "nonexistent", atOrdinal: 0)
        #expect(!moved, "moveItem returns false for unknown column")
        let unchanged = await board.item(id: "t1")
        #expect(unchanged?.columnId == "c1", "column unchanged on failed move")
    }

    @Test func moveUnknownItemReturnsFalse() async {
        let board = KanbanBoard()
        let moved = await board.moveItem(id: "ghost", toColumn: "c1", atOrdinal: 0)
        #expect(!moved, "unknown item: returns false")
    }

    @Test func toggleComplete() async {
        let board = KanbanBoard()
        await board.add(item: TodoItemRecord(id: "t1", title: "Task", projectId: "p", columnId: "c", ordinal: 0))
        let toggled = await board.toggleComplete(itemId: "t1")
        #expect(toggled)
        let completed = await board.item(id: "t1")
        #expect(completed?.isCompleted == true, "toggled to true")
        await board.toggleComplete(itemId: "t1")
        let uncompleted = await board.item(id: "t1")
        #expect(uncompleted?.isCompleted == false, "toggled back to false")
    }

    @Test func removeItem() async {
        let board = KanbanBoard()
        await board.add(item: TodoItemRecord(id: "t1", title: "Task", projectId: "p", columnId: "c", ordinal: 0))
        await board.remove(itemId: "t1")
        let gone = await board.item(id: "t1")
        #expect(gone == nil, "removed item not found")
    }
}

// MARK: - CalendarEventParser Tests

@Suite("CalendarEventParser")
struct CalendarEventParserTests {

    private func makeParser(scope: AIScope = .always) async -> (CalendarEventParser, MockAIProvider) {
        let mockAI = MockAIProvider()
        let manager = AIPermissionManager()
        await manager.set(scope: scope, providerId: "mock-ai", feature: .eventParse)
        let gate = AIGate(permissionManager: manager)
        let parser = CalendarEventParser(aiProvider: mockAI, gate: gate, providerId: "mock-ai")
        return (parser, mockAI)
    }

    @Test func parseEventFromNaturalLanguage() async throws {
        let (parser, mockAI) = await makeParser()
        let expectedDraft = CalendarEventDraft(
            title: "Lunch with Alice",
            startDate: Date(timeIntervalSinceNow: 86_400),
            endDate:   Date(timeIntervalSinceNow: 90_000),
            location:  "The Office",
            attendees: ["alice@example.com"]
        )
        await mockAI.set(parseEventResult: expectedDraft)

        let draft = try await parser.parse(text: "Lunch with Alice tomorrow noon at The Office")
        #expect(draft.title == "Lunch with Alice")
        #expect(draft.location == "The Office")
        #expect(draft.attendees.contains("alice@example.com"))

        let calls = await mockAI.parseEventCalled
        #expect(calls == 1, "parseEvent called once")
    }

    @Test func parseEventBlockedByPermission() async {
        let (parser, _) = await makeParser(scope: .never)
        var threw = false
        do {
            _ = try await parser.parse(text: "Meeting tomorrow")
        } catch AIProviderError.permissionDenied {
            threw = true
        } catch {}
        #expect(threw, "parser throws permissionDenied when scope is .never")
    }

    @Test func parseEventEntityOverride() async throws {
        let mockAI = MockAIProvider()
        let manager = AIPermissionManager()
        await manager.set(scope: .always, providerId: "mock-ai", feature: .eventParse)
        await manager.set(scope: .never,  providerId: "mock-ai", feature: .eventParse, entityId: "private")
        let gate = AIGate(permissionManager: manager)
        let parser = CalendarEventParser(aiProvider: mockAI, gate: gate, providerId: "mock-ai")

        // Global parse succeeds
        let _ = try await parser.parse(text: "Meeting tomorrow")

        // Entity-blocked parse fails
        var entityBlocked = false
        do {
            _ = try await parser.parse(text: "Meeting tomorrow", entityId: "private")
        } catch AIProviderError.permissionDenied {
            entityBlocked = true
        }
        #expect(entityBlocked, "entity-level .never blocks parse")
    }
}
