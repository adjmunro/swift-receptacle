import SwiftUI
import Receptacle  // CalendarEventParser, CalendarEventDraft, AIProviderError

/// AI-assisted event creation: text or voice input → parsed draft → confirm → EventKit.
///
/// ## Flow
/// 1. User types or dictates: "Meeting with Tom next Tuesday at 2pm for an hour in the office"
/// 2. `CalendarEventParser` calls the AI model (gated by `AIGate`) → `CalendarEventDraft`
/// 3. Confirmation section shows parsed fields before writing to EventKit
/// 4. On "Save to Calendar": parent receives draft via `onSave` callback and calls `CalendarSource`
///
/// ## EventKit write (Phase 12, wired in Xcode)
/// ```swift
/// // In the parent (CalendarSource):
/// let event = EKEvent(eventStore: store)
/// event.title    = draft.title
/// event.startDate = draft.startDate
/// event.endDate   = draft.endDate
/// event.location  = draft.location
/// event.notes     = draft.notes
/// event.calendar  = store.defaultCalendarForNewEvents
/// try store.save(event, span: .thisEvent)
/// ```
struct CalendarEventCreatorView: View {
    /// Optional AI parser; if nil, shows a placeholder draft (no AI).
    var parser: CalendarEventParser?
    var onSave: ((CalendarEventDraft) -> Void)?
    var onCancel: (() -> Void)?

    @State private var inputText = ""
    @State private var parsedDraft: CalendarEventDraft?
    @State private var isParsing = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Describe the event") {
                    TextField(
                        "e.g. Meeting with Tom next Tuesday at 2pm for an hour",
                        text: $inputText,
                        axis: .vertical
                    )
                    .lineLimit(3...6)

                    Button(isParsing ? "Parsing…" : "Parse with AI") {
                        Task { await parseInput() }
                    }
                    .disabled(inputText.isEmpty || isParsing)
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }

                if let draft = parsedDraft {
                    Section("Confirm Event") {
                        LabeledContent("Title", value: draft.title)
                        LabeledContent("Start", value: draft.startDate.formatted())
                        LabeledContent("End", value: draft.endDate.formatted())
                        if let location = draft.location {
                            LabeledContent("Location", value: location)
                        }
                        if !draft.attendees.isEmpty {
                            LabeledContent("Attendees", value: draft.attendees.joined(separator: ", "))
                        }
                        if draft.isAllDay {
                            LabeledContent("All-day", value: "Yes")
                        }
                    }
                }
            }
            .navigationTitle("New Event")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel?() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save to Calendar") {
                        if let draft = parsedDraft { onSave?(draft) }
                    }
                    .disabled(parsedDraft == nil)
                }
            }
        }
    }

    private func parseInput() async {
        isParsing = true
        errorMessage = nil
        defer { isParsing = false }
        do {
            if let parser {
                parsedDraft = try await parser.parse(text: inputText)
            } else {
                // Fallback: placeholder draft when no AI parser is configured
                parsedDraft = CalendarEventDraft(
                    title: inputText,
                    startDate: Date(),
                    endDate: Date().addingTimeInterval(3600)
                )
            }
        } catch AIProviderError.permissionDenied {
            errorMessage = "AI permission denied. Check AI settings."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
