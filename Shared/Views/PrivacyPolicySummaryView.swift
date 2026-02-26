import SwiftUI

/// Shown when enabling a cloud AI provider for the first time.
///
/// Fetches the provider's current privacy policy, summarises it on-device,
/// and presents it before the user confirms activation.
struct PrivacyPolicySummaryView: View {
    let providerId: String
    let providerName: String
    var onConfirm: () -> Void
    var onCancel: () -> Void

    @State private var summaryState: SummaryState = .loading

    var body: some View {
        VStack(spacing: 16) {
            Text("Before enabling \(providerName)")
                .font(.title2.bold())

            Text("Receptacle will summarise \(providerName)'s privacy policy so you can make an informed decision. The summary is generated on-device — your data is not sent anywhere yet.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Divider()

            switch summaryState {
            case .loading:
                ProgressView("Fetching privacy policy…")
                    .task { await loadSummary() }

            case .loaded(let summary):
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Data Handling Summary", systemImage: "lock.shield")
                            .font(.headline)
                        Text(summary)
                            .font(.body)
                    }
                    .padding()
                }

            case .failed(let reason):
                VStack(spacing: 8) {
                    Label("Could not load policy", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack {
                Button("Cancel", role: .cancel) { onCancel() }
                    .buttonStyle(.bordered)
                Spacer()
                Button("Enable \(providerName)") { onConfirm() }
                    .buttonStyle(.borderedProminent)
                    .disabled(summaryState.isLoading)
            }
        }
        .padding()
    }

    private func loadSummary() async {
        // TODO Phase 8:
        // 1. Fetch privacy policy URL for this provider
        // 2. Extract relevant text (URLSession)
        // 3. Summarise locally via WhisperProvider/local model
        // 4. Update summaryState
        try? await Task.sleep(for: .seconds(1))
        summaryState = .loaded(
            "This provider may use your inputs to improve their models. Inputs are retained " +
            "for up to 30 days. You can opt out via their API dashboard settings. " +
            "No personally identifiable information is shared with third parties."
        )
    }
}

enum SummaryState {
    case loading
    case loaded(String)
    case failed(String)

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}
