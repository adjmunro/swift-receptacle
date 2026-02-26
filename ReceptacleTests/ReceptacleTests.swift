import Testing
@testable import Receptacle

// MARK: - Phase 0: Green baseline

/// Trivial canary — proves the test harness, import, and build are wired up correctly.
///
/// Note: Date-dependent tests (RuleEngine Phase 1) require Xcode's complete
/// _Testing_Foundation.swiftmodule (CLI tools ship a binary-only stub).
/// Those tests are in RuleEngineTests.swift and will be enabled once Xcode is installed.
@Suite("Phase 0 — Build Baseline")
struct BuildBaselineTests {

    @Test("Test suite can run")
    func canRunTests() {
        #expect(Bool(true))
    }

    @Test("RetentionPolicy.displayName is non-empty for all cases")
    func retentionPolicyDisplayNames() {
        let cases: [(RetentionPolicy, String)] = [
            (.keepAll, "Keep all"),
            (.keepLatest(3), "Keep latest 3"),
            (.keepDays(7), "Keep 7 days"),
            (.autoArchive, "Auto-archive"),
            (.autoDelete, "Auto-delete"),
        ]
        for (policy, expected) in cases {
            #expect(policy.displayName == expected)
        }
    }

    @Test("WikilinkParser extracts two links from markdown")
    func wikilinkExtraction() {
        let parser = WikilinkParser()
        let markdown = "See [[Project Notes]] and [[Meeting 2026-02-26]] for details."
        let links = parser.extractLinks(from: markdown)
        #expect(links.count == 2)
        #expect(links[0].target == "Project Notes")
        #expect(links[1].target == "Meeting 2026-02-26")
    }

    @Test("WikilinkParser returns empty array when no links present")
    func wikilinkEmptyInput() {
        let parser = WikilinkParser()
        let links = parser.extractLinks(from: "No wikilinks here.")
        #expect(links.isEmpty)
    }

    @Test("WikilinkParser resolves known targets")
    func wikilinkResolution() {
        let parser = WikilinkParser()
        let markdown = "See [[Project Notes]] and [[Unknown Note]]."
        let resolved = parser.resolve(markdown: markdown) { target in
            target == "Project Notes" ? "note-abc123" : nil
        }
        #expect(resolved.resolvedIds["Project Notes"] == "note-abc123")
        #expect(resolved.unresolvedTargets.contains("Unknown Note"))
    }

    @Test("RuleEngine can be instantiated with empty items")
    func ruleEngineEmptyEval() {
        let engine = RuleEngine()
        let entity = EntitySnapshot(id: "e1", retentionPolicy: .keepAll)
        // Uses Date() internally — but RuleEngine.evaluate with empty items
        // doesn't need Foundation in the TEST side; the default is Date()
        // which comes from RuleEngine.swift (Foundation is imported there)
        let result = engine.evaluate(items: [], entity: entity)
        #expect(result.itemsToDelete.isEmpty)
        #expect(result.itemsToArchive.isEmpty)
    }

    @Test("ImportanceLevel is comparable")
    func importanceLevelComparable() {
        #expect(ImportanceLevel.normal < ImportanceLevel.important)
        #expect(ImportanceLevel.important < ImportanceLevel.critical)
        #expect(!(ImportanceLevel.critical < ImportanceLevel.normal))
    }

    @Test("AIPermissionManager returns askEachTime by default")
    func aiPermissionManagerDefault() async {
        let manager = AIPermissionManager()
        let scope = await manager.scope(for: "openai", feature: .summarise)
        #expect(scope == .askEachTime)
    }

    @Test("AIPermissionManager respects set scope")
    func aiPermissionManagerSet() async {
        let manager = AIPermissionManager()
        await manager.set(scope: .always, providerId: "openai", feature: .summarise)
        let scope = await manager.scope(for: "openai", feature: .summarise)
        #expect(scope == .always)
    }
}
