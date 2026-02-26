// VoiceReplyTests.swift
// CLI-compatible: only `import Testing` (no Foundation).
// Run via: swift test  (or open in Xcode for full output)

import Testing
import Receptacle

// MARK: - DraftStateStack Tests

@Suite("DraftStateStack")
struct DraftStateStackTests {

    @Test func test_draftStateStack_pushAndPop() {
        var stack = DraftStateStack()
        #expect(stack.isEmpty)
        #expect(stack.count == 0)
        #expect(stack.current == nil)

        stack.push(text: "First draft", description: "Transcribed")
        #expect(stack.count == 1)
        #expect(stack.current?.text == "First draft")
        #expect(stack.current?.changeDescription == "Transcribed")

        stack.push(text: "Second draft", description: "AI reframed")
        #expect(stack.count == 2)
        #expect(stack.current?.text == "Second draft")
    }

    @Test func test_draftStateStack_undoRestoresPrevious() {
        var stack = DraftStateStack()
        stack.push(text: "First",  description: "Initial")
        stack.push(text: "Second", description: "Reframed")
        stack.push(text: "Third",  description: "Instruction")

        #expect(stack.current?.text == "Third")

        stack.undo()
        #expect(stack.current?.text == "Second", "undo pops to previous state")
        #expect(stack.count == 2)

        stack.undo()
        #expect(stack.current?.text == "First", "undo reaches initial state")

        // Can't undo past the first state
        stack.undo()
        #expect(stack.current?.text == "First", "undo is idempotent at the first state")
        #expect(stack.count == 1)
    }

    @Test func test_draftStateStack_jumpToIndex() {
        var stack = DraftStateStack()
        stack.push(text: "v1")
        stack.push(text: "v2")
        stack.push(text: "v3")
        stack.push(text: "v4")

        stack.jump(to: 1)
        #expect(stack.count == 2, "jump(to:1) truncates to states[0...1]")
        #expect(stack.current?.text == "v2")
    }

    @Test func test_draftStateStack_jumpOutOfBoundsIgnored() {
        var stack = DraftStateStack()
        stack.push(text: "only")
        stack.jump(to: 99)
        #expect(stack.count == 1, "out-of-bounds jump is ignored")
        stack.jump(to: -1)
        #expect(stack.count == 1, "negative jump is ignored")
    }

    @Test func test_draftStateStack_clear() {
        var stack = DraftStateStack()
        stack.push(text: "a")
        stack.push(text: "b")
        stack.clear()
        #expect(stack.isEmpty)
        #expect(stack.count == 0)
        #expect(stack.current == nil)
    }

    @Test func test_draftStateStack_undoEmptyReturnsNil() {
        var stack = DraftStateStack()
        let result = stack.undo()
        #expect(result == nil, "undo on empty stack returns nil")
    }

    @Test func test_draftStateStack_changeDescriptionPreserved() {
        var stack = DraftStateStack()
        stack.push(text: "Hello",    description: "Transcribed")
        stack.push(text: "Hi there", description: "AI reframed")
        #expect(stack.states[0].changeDescription == "Transcribed")
        #expect(stack.states[1].changeDescription == "AI reframed")
        #expect(stack.current?.changeDescription == "AI reframed")
    }
}

// MARK: - VoiceReplyPipeline Tests

@Suite("VoiceReplyPipeline")
struct VoiceReplyPipelineTests {

    private func makeGate(scope: AIScope) async -> AIGate {
        let manager = AIPermissionManager()
        await manager.set(scope: scope, providerId: "mock-ai", feature: .reframeTone)
        return AIGate(permissionManager: manager)
    }

    @Test func test_reframeTone_producesDifferentText() async throws {
        let mockAI = MockAIProvider()
        await mockAI.set(reframeResult: "Formal version of the reply.")
        let gate = await makeGate(scope: .always)
        let pipeline = VoiceReplyPipeline(aiProvider: mockAI, gate: gate, providerId: "mock-ai")

        let draft = try await pipeline.reframe(
            transcript: "hey thanks for the update",
            tone: .formal
        )
        #expect(draft.text == "Formal version of the reply.")
        #expect(draft.changeDescription == "AI reframed")

        let count = await mockAI.reframeCalled
        #expect(count == 1)
    }

    @Test func test_instructionMode_revisesExistingDraft() async throws {
        let mockAI = MockAIProvider()
        await mockAI.set(reframeResult: "More concise revised draft.")
        let gate = await makeGate(scope: .always)
        let pipeline = VoiceReplyPipeline(aiProvider: mockAI, gate: gate, providerId: "mock-ai")

        let revised = try await pipeline.applyInstruction(
            "make it more concise",
            to: "Thank you very much for getting in touch with me about this matter."
        )
        #expect(revised.text == "More concise revised draft.")
        #expect(revised.changeDescription == "Instruction: make it more concise")

        let count = await mockAI.reframeCalled
        #expect(count == 1)
    }

    @Test func test_reframe_blockedByPermission() async throws {
        let mockAI = MockAIProvider()
        let gate = await makeGate(scope: .never)
        let pipeline = VoiceReplyPipeline(aiProvider: mockAI, gate: gate, providerId: "mock-ai")

        var threw = false
        do {
            _ = try await pipeline.reframe(transcript: "hi", tone: .formal)
        } catch AIProviderError.permissionDenied {
            threw = true
        }
        #expect(threw, "reframe is blocked when permission is .never")
    }

    @Test func test_instruction_blockedByPermission() async throws {
        let mockAI = MockAIProvider()
        let gate = await makeGate(scope: .never)
        let pipeline = VoiceReplyPipeline(aiProvider: mockAI, gate: gate, providerId: "mock-ai")

        var threw = false
        do {
            _ = try await pipeline.applyInstruction("be formal", to: "hey")
        } catch AIProviderError.permissionDenied {
            threw = true
        }
        #expect(threw, "applyInstruction is blocked when permission is .never")
    }

    @Test func test_pipeline_integrationWithDraftStack() async throws {
        let mockAI = MockAIProvider()
        await mockAI.set(reframeResult: "Professional reply.")
        let gate = await makeGate(scope: .always)
        let pipeline = VoiceReplyPipeline(aiProvider: mockAI, gate: gate, providerId: "mock-ai")

        var stack = DraftStateStack()

        // Push initial transcription
        stack.push(text: "yeah ok sounds good", description: "Transcribed")
        #expect(stack.count == 1)

        // Reframe → push
        let reframed = try await pipeline.reframe(
            transcript: stack.current!.text,
            tone: .formal
        )
        stack.push(reframed)
        #expect(stack.count == 2)
        #expect(stack.current?.text == "Professional reply.")

        // Undo back to transcription
        stack.undo()
        #expect(stack.count == 1)
        #expect(stack.current?.text == "yeah ok sounds good")
    }
}
