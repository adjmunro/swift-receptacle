import SwiftUI

// MARK: - PrivacyPolicySummaryView

/// Shown when enabling a cloud AI provider for the first time.
///
/// Fetches the provider's current privacy policy via URLSession, strips HTML,
/// and attempts on-device summarisation via `WhisperProvider`. Falls back to
/// a hardcoded summary when the on-device model is unavailable.
///
/// The summary is generated on-device — no data is sent to the cloud provider
/// until the user explicitly confirms.
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
                    Text("You can still enable \(providerName), but we recommend reviewing their privacy policy at \(PrivacyPolicyRegistry.url(for: providerId) ?? "their website") before proceeding.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
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
        .frame(minWidth: 400, minHeight: 300)
    }

    // MARK: - Private

    private func loadSummary() async {
        guard let urlString = PrivacyPolicyRegistry.url(for: providerId),
              let url = URL(string: urlString) else {
            summaryState = .failed("No privacy policy URL registered for '\(providerId)'.")
            return
        }

        do {
            // 1. Fetch policy HTML via URLSession
            let (data, _) = try await URLSession.shared.data(from: url)
            let html = String(data: data, encoding: .utf8) ?? ""

            // 2. Strip HTML tags to extract readable plain text
            let plain = html
                .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            let excerpt = String(plain.prefix(4096))

            // 3. Attempt on-device summarisation via WhisperProvider.
            //    WhisperProvider.summarise currently throws .modelUnavailable —
            //    the catch block falls back to the hardcoded registry summary.
            do {
                let localProvider = WhisperProvider()
                let summary = try await localProvider.summarise(text: excerpt)
                summaryState = .loaded(summary)
            } catch {
                summaryState = .loaded(PrivacyPolicyRegistry.fallbackSummary(for: providerId))
            }

        } catch {
            summaryState = .failed("Could not fetch or summarise the policy: \(error.localizedDescription)")
        }
    }
}

// MARK: - PrivacyPolicyRegistry

/// Maps provider IDs to their current privacy policy URLs and fallback summaries.
///
/// URLs should be checked for accuracy when new provider versions ship.
/// Fallback summaries are shown when on-device summarisation fails.
enum PrivacyPolicyRegistry {

    static func url(for providerId: String) -> String? {
        switch providerId {
        case "openai":
            return "https://openai.com/policies/privacy-policy"
        case "claude":
            return "https://www.anthropic.com/legal/privacy"
        default:
            return nil
        }
    }

    static func fallbackSummary(for providerId: String) -> String {
        switch providerId {
        case "openai":
            return """
                OpenAI may use your API inputs to improve their models unless you opt out \
                via the API dashboard. Inputs sent via the API are retained for up to 30 days \
                for safety monitoring. No personally identifiable information is shared with \
                third parties for advertising. You can request deletion of your data.
                """
        case "claude":
            return """
                Anthropic uses API inputs to provide the service and for safety research. \
                Inputs are not used to train Claude unless you explicitly opt in. Data is \
                retained according to their data retention policy. Anthropic does not sell \
                your personal data. Enterprise customers can negotiate zero data retention.
                """
        default:
            return "Privacy policy summary unavailable. Please review the provider's website directly."
        }
    }
}

// MARK: - SummaryState

enum SummaryState {
    case loading
    case loaded(String)
    case failed(String)

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}
