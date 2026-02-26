// AIProviderTests.swift
// CLI-compatible: only `import Testing` (no Foundation).
// Run via: swift test  (or open in Xcode for full test output)

import Testing
import Receptacle

// MARK: - AIGate Permission Tests

@Suite("AIGate permission gating")
struct AIGateTests {

    // Permission scope .never → perform throws permissionDenied
    @Test func permissionGate_blocksWhenNever() async throws {
        let manager = AIPermissionManager()
        await manager.set(scope: .never, providerId: "openai", feature: .summarise)
        let gate = AIGate(permissionManager: manager)

        var threw = false
        do {
            _ = try await gate.perform(
                providerId: "openai",
                feature: .summarise
            ) {
                "should not reach here"
            }
        } catch AIProviderError.permissionDenied {
            threw = true
        }
        #expect(threw, "perform should throw .permissionDenied when scope is .never")
    }

    // Permission scope .always → perform proceeds and returns result
    @Test func permissionGate_allowsWhenAlways() async throws {
        let manager = AIPermissionManager()
        await manager.set(scope: .always, providerId: "claude", feature: .summarise)
        let gate = AIGate(permissionManager: manager)

        let result = try await gate.perform(
            providerId: "claude",
            feature: .summarise
        ) {
            "summary result"
        }
        #expect(result == "summary result")
    }

    // Entity-level .never overrides global .always
    @Test func permissionGate_entityOverridesGlobal() async throws {
        let manager = AIPermissionManager()
        await manager.set(scope: .always, providerId: "openai", feature: .summarise)
        await manager.set(scope: .never,  providerId: "openai", feature: .summarise,
                          entityId: "sensitive-entity")
        let gate = AIGate(permissionManager: manager)

        // Global .always still works for other entities
        let globalResult = try await gate.perform(
            providerId: "openai",
            feature: .summarise
        ) { "ok" }
        #expect(globalResult == "ok")

        // Entity-level .never blocks
        var threw = false
        do {
            _ = try await gate.perform(
                providerId: "openai",
                feature: .summarise,
                entityId: "sensitive-entity"
            ) { "blocked" }
        } catch AIProviderError.permissionDenied {
            threw = true
        }
        #expect(threw, "entity scope .never should override global .always")
    }

    // .askEachTime proceeds (UI confirms before calling gate)
    @Test func permissionGate_allowsWhenAskEachTime() async throws {
        let manager = AIPermissionManager()
        await manager.set(scope: .askEachTime, providerId: "claude", feature: .reframeTone)
        let gate = AIGate(permissionManager: manager)

        let result = try await gate.perform(
            providerId: "claude",
            feature: .reframeTone
        ) { "reframed" }
        #expect(result == "reframed", ".askEachTime proceeds (UI confirms externally)")
    }

    // Convenience predicates
    @Test func gatePredicates() async {
        let manager = AIPermissionManager()
        await manager.set(scope: .always,     providerId: "openai", feature: .summarise)
        await manager.set(scope: .never,      providerId: "openai", feature: .transcribe)
        await manager.set(scope: .askEachTime, providerId: "openai", feature: .reframeTone)
        let gate = AIGate(permissionManager: manager)

        let isAlways = await gate.isAlwaysAllowed(providerId: "openai", feature: .summarise)
        #expect(isAlways)

        let isBlocked = await gate.isBlocked(providerId: "openai", feature: .transcribe)
        #expect(isBlocked)

        let needsConfirm = await gate.requiresConfirmation(providerId: "openai", feature: .reframeTone)
        #expect(needsConfirm)
    }
}

// MARK: - MockAIProvider Tests

@Suite("MockAIProvider")
struct MockAIProviderTests {

    // summarise returns configured result and tracks call count
    @Test func mockProvider_returnsExpectedSummary() async throws {
        let provider = MockAIProvider()
        await provider.set(summariseResult: "Key points: three items listed.")

        let result = try await provider.summarise(text: "Long email body here.")
        #expect(result == "Key points: three items listed.")

        let count = await provider.summariseCalled
        #expect(count == 1)

        let input = await provider.lastSummariseInput
        #expect(input == "Long email body here.")
    }

    // reframe returns configured result and tracks tone
    @Test func mockProvider_reframe() async throws {
        let provider = MockAIProvider()
        await provider.set(reframeResult: "Formal version of the reply.")

        let result = try await provider.reframe(text: "Hey thanks!", tone: .formal)
        #expect(result == "Formal version of the reply.")

        let count = await provider.reframeCalled
        #expect(count == 1)

        let tone = await provider.lastReframeTone
        #expect(tone == .formal)
    }

    // shouldThrow injects error into all methods
    @Test func mockProvider_errorInjection() async throws {
        let provider = MockAIProvider()
        await provider.set(shouldThrow: .rateLimited)

        var summariseThrew = false
        do { _ = try await provider.summarise(text: "test") }
        catch AIProviderError.rateLimited { summariseThrew = true }
        #expect(summariseThrew)

        var reframeThrew = false
        do { _ = try await provider.reframe(text: "test", tone: .friendly) }
        catch AIProviderError.rateLimited { reframeThrew = true }
        #expect(reframeThrew)
    }

    // resetCallCounts clears all tracking state
    @Test func mockProvider_resetCallCounts() async throws {
        let provider = MockAIProvider()
        _ = try await provider.summarise(text: "a")
        _ = try await provider.reframe(text: "b", tone: .casualClean)

        await provider.resetCallCounts()

        let summarise = await provider.summariseCalled
        let reframe   = await provider.reframeCalled
        let lastInput = await provider.lastSummariseInput
        #expect(summarise == 0)
        #expect(reframe   == 0)
        #expect(lastInput == nil)
    }

    // Multiple sequential calls — counter accumulates
    @Test func mockProvider_callCountAccumulates() async throws {
        let provider = MockAIProvider()
        _ = try await provider.summarise(text: "first")
        _ = try await provider.summarise(text: "second")
        _ = try await provider.summarise(text: "third")

        let count = await provider.summariseCalled
        #expect(count == 3)

        let lastInput = await provider.lastSummariseInput
        #expect(lastInput == "third")
    }
}
