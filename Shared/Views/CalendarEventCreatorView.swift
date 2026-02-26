import SwiftUI

/// AI-assisted event creation: text or voice input → parsed draft → confirm → EventKit.
///
/// Flow:
/// 1. User types or dictates: "Meeting with Tom next Tuesday at 2pm for an hour in the office"
/// 2. Local AI model extracts: title, date, time, duration, location, attendees
/// 3. Confirmation sheet shows parsed event before writing to EventKit
struct CalendarEventCreatorView: View {
    var onSave: ((CalendarEventDraft) -> Void)?
    var onCancel: (() -> Void)?

    @State private var inputText = ""
    @State private var parsedDraft: CalendarEventDraft?
    @State private var isParsing = false

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

                    Button("Parse with AI") {
                        Task { await parseInput() }
                    }
                    .disabled(inputText.isEmpty || isParsing)
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
        defer { isParsing = false }
        // TODO Phase 12: call aiProvider.parseEvent(from: inputText)
        // For now: placeholder draft
        parsedDraft = CalendarEventDraft(
            title: inputText,
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            location: nil,
            attendees: [],
            isAllDay: false
        )
    }
}
