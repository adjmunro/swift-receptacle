import Foundation
import CoreGraphics

// MARK: - NoteGraph

/// In-memory graph model for `NoteGraphView` (Canvas-based force-directed layout).
///
/// Nodes = Notes; Edges = [[wikilink]] connections between notes.
/// The graph is rebuilt from SwiftData whenever notes or their links change.
/// Phase 12 implementation.
final class NoteGraph: @unchecked Sendable {

    // MARK: - Types

    struct Node: Identifiable, Sendable {
        var id: String          // Note.id.uuidString
        var title: String
        var tagIds: [String]
        /// Current position in the graph canvas (updated by force-directed layout)
        var position: CGPoint
    }

    struct Edge: Identifiable, Sendable {
        var id: String          // "\(sourceId)→\(targetId)"
        var sourceId: String
        var targetId: String
    }

    // MARK: - Properties

    private(set) var nodes: [Node] = []
    private(set) var edges: [Edge] = []

    // MARK: - Build

    /// Rebuilds the graph from a flat list of notes.
    ///
    /// - Parameter notes: All notes currently in the store
    func rebuild(from notes: [NoteSnapshot]) {
        // Create nodes
        nodes = notes.map { note in
            Node(
                id: note.id,
                title: note.title,
                tagIds: note.tagIds,
                position: .zero
            )
        }

        // Create edges from wikilink connections
        let noteIdSet = Set(notes.map { $0.id })
        var newEdges: [Edge] = []
        for note in notes {
            for linkedId in note.linkedNoteIds where noteIdSet.contains(linkedId) {
                let edgeId = "\(note.id)→\(linkedId)"
                newEdges.append(Edge(id: edgeId, sourceId: note.id, targetId: linkedId))
            }
        }
        edges = newEdges

        applyInitialLayout()
    }

    /// Runs one iteration of a simple force-directed layout.
    /// Called repeatedly from a SwiftUI Canvas animation loop.
    func stepLayout(canvasSize: CGSize) {
        let repulsion: CGFloat = 5000
        let attraction: CGFloat = 0.05
        let damping: CGFloat = 0.85
        var velocities = [String: CGPoint](minimumCapacity: nodes.count)

        for i in nodes.indices {
            var velocity = CGPoint.zero

            // Repulsion between all node pairs
            for j in nodes.indices where i != j {
                let dx = nodes[i].position.x - nodes[j].position.x
                let dy = nodes[i].position.y - nodes[j].position.y
                let distSq = max(dx * dx + dy * dy, 1)
                let force = repulsion / distSq
                velocity.x += force * dx
                velocity.y += force * dy
            }

            // Attraction along edges
            for edge in edges where edge.sourceId == nodes[i].id || edge.targetId == nodes[i].id {
                let otherId = edge.sourceId == nodes[i].id ? edge.targetId : edge.sourceId
                if let other = nodes.first(where: { $0.id == otherId }) {
                    velocity.x += attraction * (other.position.x - nodes[i].position.x)
                    velocity.y += attraction * (other.position.y - nodes[i].position.y)
                }
            }

            velocities[nodes[i].id] = velocity
        }

        // Apply velocities with damping + clamp to canvas
        for i in nodes.indices {
            let v = velocities[nodes[i].id] ?? .zero
            nodes[i].position.x = max(0, min(canvasSize.width,
                nodes[i].position.x + v.x * damping))
            nodes[i].position.y = max(0, min(canvasSize.height,
                nodes[i].position.y + v.y * damping))
        }
    }

    // MARK: - Private

    private func applyInitialLayout() {
        // Distribute nodes in a circle as starting positions
        let radius: CGFloat = 300
        let centre = CGPoint(x: 400, y: 400)
        let count = nodes.count
        guard count > 0 else { return }
        for i in nodes.indices {
            let angle = 2 * CGFloat.pi * CGFloat(i) / CGFloat(count)
            nodes[i].position = CGPoint(
                x: centre.x + radius * cos(angle),
                y: centre.y + radius * sin(angle)
            )
        }
    }
}

/// Lightweight snapshot of a Note for graph building (no SwiftData references)
struct NoteSnapshot: Sendable, Equatable {
    var id: String
    var title: String
    var tagIds: [String]
    var linkedNoteIds: [String]
}

// MARK: - CGPoint helpers

extension CGPoint: @retroactive AdditiveArithmetic {
    public static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
    public static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }
    public static var zero: CGPoint { CGPoint(x: 0, y: 0) }
}
