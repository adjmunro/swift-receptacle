// ArticleBodyExtractionTests.swift
// CLI-compatible: only `import Testing` (no Foundation).
// Tests for FeedItemRecord.articleBodyHTML(from:) extraction pipeline.

import Testing
@testable import Receptacle

// MARK: - ArticleBodyExtraction Tests

@Suite("FeedItemRecord — articleBodyHTML extraction")
struct ArticleBodyExtractionTests {

    // MARK: Primary extraction targets

    @Test("Extracts content from <article> tag")
    func extractsArticleTag() {
        let html = """
        <html><body>
        <nav>Navigation here</nav>
        <article>The real article content</article>
        <footer>Footer here</footer>
        </body></html>
        """
        let result = FeedItemRecord.articleBodyHTML(from: html)
        #expect(result.contains("The real article content"))
        #expect(!result.contains("Navigation here"))
        #expect(!result.contains("Footer here"))
    }

    @Test("Falls back to <main> when no <article>")
    func fallsBackToMain() {
        let html = """
        <html><body>
        <header>Site header</header>
        <main>Main page content goes here</main>
        <footer>Footer here</footer>
        </body></html>
        """
        let result = FeedItemRecord.articleBodyHTML(from: html)
        #expect(result.contains("Main page content goes here"))
        #expect(!result.contains("Site header"))
        #expect(!result.contains("Footer here"))
    }

    @Test("Falls back to <body> when no <article> or <main>")
    func fallsBackToBody() {
        let html = """
        <html><body>
        <p>Just some body content</p>
        </body></html>
        """
        let result = FeedItemRecord.articleBodyHTML(from: html)
        #expect(result.contains("Just some body content"))
    }

    // MARK: Noise element stripping

    @Test("Strips <nav>, <header>, <footer>, <aside> before extraction")
    func stripsNavHeaderFooterAside() {
        let html = """
        <html><body>
        <nav>Skip to content | Home | About</nav>
        <header>Site Logo — My Blog</header>
        <article>
        <aside>Related posts sidebar</aside>
        <p>Article body text here.</p>
        </article>
        <footer>Copyright 2024</footer>
        </body></html>
        """
        let result = FeedItemRecord.articleBodyHTML(from: html)
        #expect(result.contains("Article body text here."))
        #expect(!result.contains("Skip to content"))
        #expect(!result.contains("Site Logo"))
        #expect(!result.contains("Related posts sidebar"))
        #expect(!result.contains("Copyright 2024"))
    }

    @Test("Strips <script> and <style> blocks")
    func stripsScriptAndStyle() {
        let html = """
        <html><head>
        <style>body { color: red; }</style>
        </head><body>
        <script>var x = 1; alert("hello");</script>
        <article>
        <p>Clean article content.</p>
        </article>
        </body></html>
        """
        let result = FeedItemRecord.articleBodyHTML(from: html)
        #expect(result.contains("Clean article content."))
        #expect(!result.contains("color: red"))
        #expect(!result.contains("alert"))
        #expect(!result.contains("var x"))
    }

    // MARK: Edge cases

    @Test("Prefers <article> over <main> when both present")
    func prefersArticleOverMain() {
        let html = """
        <html><body>
        <main>
        <article>Specific article text</article>
        <p>Main wrapper text</p>
        </main>
        </body></html>
        """
        let result = FeedItemRecord.articleBodyHTML(from: html)
        #expect(result.contains("Specific article text"))
    }

    @Test("Returns non-empty result for minimal HTML")
    func handlesMinimalHTML() {
        let html = "<p>Hello world</p>"
        let result = FeedItemRecord.articleBodyHTML(from: html)
        #expect(!result.isEmpty)
    }
}
