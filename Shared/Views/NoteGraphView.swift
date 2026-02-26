import SwiftUI

/// Obsidian-style note graph: SwiftUI `Canvas` with a force-directed layout.
///
/// Nodes = Notes; Edges = [[wikilink]] connections.
/// Tapping a node opens that note's sidebar panel.
/// Phase 12 implementation.
struct NoteGraphView: View {
    @State private var graph = NoteGraph()
    @State private var canvasSize: CGSize = .zero
    @State private var selectedNoteId: String?
    @State private var animating = false

    var body: some View {
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
        .background(Color(
#if os(macOS)
            .windowBackground
#else
            .systemBackground
#endif
        ))
        .onTapGesture { location in
            selectedNoteId = graph.nodes.first(where: { node in
                let dx = node.position.x - location.x
                let dy = node.position.y - location.y
                return sqrt(dx * dx + dy * dy) < 24
            })?.id
        }
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { size in
            canvasSize = size
        }
        .task {
            // TODO Phase 12: load notes from SwiftData → graph.rebuild(from:)
            // Start animation loop via withAnimation + TimelineView
        }
    }
}
