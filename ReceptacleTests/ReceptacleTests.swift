import Testing
@testable import Receptacle

// MARK: - Phase 0: Green baseline

/// Trivial canary — proves the test harness, import, and build are all wired up correctly.
/// If this fails, something is wrong with the project structure itself.
@Suite("Phase 0 — Build Baseline")
struct BuildBaselineTests {

    @Test("Test suite can run")
    func canRunTests() {
        #expect(true)
    }

    @Test("RetentionPolicy.displayName is non-empty for all cases")
    func retentionPolicyDisplayNames() {
        let policies: [RetentionPolicy] = [
            .keepAll,
            .keepLatest(3),
            .keepDays(7),
            .autoArchive,
            .autoDelete,
        ]
        for policy in policies {
            #expect(!policy.displayName.isEmpty, "Expected non-empty name for \(policy)")
        }
    }

    @Test("WikilinkParser extracts links correctly")
    func wikilinkExtraction() {
        let parser = WikilinkParser()
        let markdown = "See [[Project Notes]] and [[Meeting 2026-02-26]] for details."
        let links = parser.extractLinks(from: markdown)
        #expect(links.count == 2)
        #expect(links[0].target == "Project Notes")
        #expect(links[1].target == "Meeting 2026-02-26")
    }

    @Test("WikilinkParser returns empty for no links")
    func wikilinkEmptyInput() {
        let parser = WikilinkParser()
        let links = parser.extractLinks(from: "No wikilinks here.")
        #expect(links.isEmpty)
    }
}

// MARK: - Phase 0: RuleEngine Stubs (red → green in Phase 1)

/// Placeholder suite — full TDD implementation in Phase 1.
/// Keeping it here ensures the type is importable and the structure is correct.
@Suite("Phase 1 — RuleEngine (stub)")
struct RuleEngineStubTests {

    @Test("RuleEngine can be instantiated")
    func ruleEngineInit() {
        let engine = RuleEngine()
        let result = engine.evaluate(items: [], entity: EntitySnapshot(
            id: "e1",
            retentionPolicy: .keepAll,
            protectionLevel: .normal,
            importanceLevel: .normal,
            importancePatterns: [],
            subRules: []
        ))
        #expect(result.itemsToDelete.isEmpty)
        #expect(result.itemsToArchive.isEmpty)
    }
}
