import SwiftUI

/// Obsidian-style note graph: SwiftUI `Canvas` with a force-directed layout.
///
/// Nodes = Notes; Edges = [[wikilink]] connections.
/// Tapping a node calls `onSelectNote` with the note ID.
///
/// ## Usage
/// Supply `noteSnapshots` from a SwiftData query (mapped to `NoteSnapshot`).
/// The graph rebuilds automatically when `noteSnapshots` changes.
/// A background task drives the force-directed animation at ~30 fps.
///
/// Phase 12 implementation.
struct NoteGraphView: View {
    /// All notes as lightweight snapshots — updated from SwiftData by the parent view.
    var noteSnapshots: [NoteSnapshot] = []
    /// Called when the user taps a node — navigate to that note.
    var onSelectNote: ((String) -> Void)?

    @State private var graph = NoteGraph()
    @State private var canvasSize: CGSize = .zero
    @State private var selectedNoteId: String?

    var body: some View {
        // TimelineView(.animation) re-renders the Canvas every display frame,
        // so force-directed layout steps applied in the background task are
        // immediately visible without needing an explicit @State trigger.
        TimelineView(.animation) { _ in
            Canvas { context, size in
                // Draw edges
                for edge in graph.edges {
                    guard
                        let source = graph.nodes.first(where: { $0.id == edge.sourceId }),
                        let target = graph.nodes.first(where: { $0.id == edge.targetId })
                    else { continue }

                    var path = Path()
                    path.move(to: source.position)
                    path.addLine(to: target.position)
                    context.stroke(path, with: .color(.secondary.opacity(0.4)), lineWidth: 1)
                }

                // Draw nodes
                for node in graph.nodes {
                    let rect = CGRect(
                        x: node.position.x - 24,
                        y: node.position.y - 24,
                        width: 48,
                        height: 48
                    )
                    let isSelected = node.id == selectedNoteId
                    context.fill(
                        Ellipse().path(in: rect),
                        with: .color(isSelected ? .accentColor : .secondary.opacity(0.6))
                    )
                    context.draw(
                        Text(node.title).font(.caption2),
                        at: CGPoint(x: node.position.x, y: node.position.y + 32)
                    )
                }
            }
        }
#if os(macOS)
        .background(.windowBackground)
#else
        .background(Color(.systemBackground))
#endif
        .onTapGesture { location in
            if let node = graph.nodes.first(where: { node in
                let dx = node.position.x - location.x
                let dy = node.position.y - location.y
                return sqrt(dx * dx + dy * dy) < 24
            }) {
                selectedNoteId = node.id
                onSelectNote?(node.id)
            }
        }
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { size in
            canvasSize = size
        }
        .onChange(of: noteSnapshots) { _, newSnapshots in
            graph.rebuild(from: newSnapshots)
        }
        .onAppear {
            graph.rebuild(from: noteSnapshots)
        }
        .task {
            // Force-directed layout animation: step layout at ~30 fps.
            // TimelineView above ensures the Canvas re-draws each frame.
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(33))
                if !canvasSize.width.isZero {
                    graph.stepLayout(canvasSize: canvasSize)
                }
            }
        }
    }
}
