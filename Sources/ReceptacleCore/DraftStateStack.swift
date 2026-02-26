import Foundation

// MARK: - DraftState

/// A single revision in the voice-reply draft pipeline.
///
/// Produced by transcription, AI reframing, instruction application, or manual editing.
/// Stored in a `DraftStateStack` — the full history is always available for rollback.
public struct DraftState: Sendable {

    /// The draft text for this revision.
    public var text: String

    /// Human-readable description of how this revision was produced.
    /// Examples: "Transcribed", "AI reframed", "Instruction: make it formal", "Manual edit"
    public var changeDescription: String?

    /// When this revision was created.
    public var timestamp: Date

    public init(
        text: String,
        changeDescription: String? = nil,
        timestamp: Date = Date()
    ) {
        self.text = text
        self.changeDescription = changeDescription
        self.timestamp = timestamp
    }
}

// MARK: - DraftStateStack

/// An ordered stack of `DraftState` revisions.
///
/// Every AI or manual edit operation pushes a new state.
/// `undo()` removes the latest state, restoring the previous one.
/// `jump(to:)` restores any historical revision (discards all states after it).
///
/// Usage:
/// ```swift
/// var stack = DraftStateStack()
/// stack.push(text: "Hey thanks!", description: "Transcribed")
/// stack.push(text: "Thank you for your message.", description: "AI reframed")
/// stack.undo()  // back to "Hey thanks!"
/// ```
public struct DraftStateStack: Sendable {

    /// All states, oldest first. The last element is the current state.
    public private(set) var states: [DraftState] = []

    public init() {}

    // MARK: - Accessors

    /// The current (latest) draft state, or `nil` if the stack is empty.
    public var current: DraftState? { states.last }

    /// `true` if no states have been pushed.
    public var isEmpty: Bool { states.isEmpty }

    /// Number of revisions in the stack (including the current one).
    public var count: Int { states.count }

    // MARK: - Mutations

    /// Push a new `DraftState` onto the stack.
    public mutating func push(_ state: DraftState) {
        states.append(state)
    }

    /// Push a new state by text and optional description.
    public mutating func push(text: String, description: String? = nil) {
        push(DraftState(text: text, changeDescription: description))
    }

    /// Remove the latest state and return the new current (the previous one).
    ///
    /// If only one state remains, it is kept unchanged (can't undo past the initial state).
    /// Returns `nil` if the stack is empty.
    @discardableResult
    public mutating func undo() -> DraftState? {
        guard !states.isEmpty else { return nil }
        if states.count > 1 { states.removeLast() }
        return states.last
    }

    /// Jump to a specific historical revision by zero-based index.
    ///
    /// All states after `index` are discarded. Out-of-bounds indices are ignored.
    public mutating func jump(to index: Int) {
        guard index >= 0, index < states.count else { return }
        states = Array(states.prefix(index + 1))
    }

    /// Remove all states, resetting the stack to empty.
    public mutating func clear() {
        states.removeAll()
    }
}
