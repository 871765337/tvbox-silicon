import SwiftUI
import TVCore

/// Settings › Send Feedback: a problem or an idea in the user's own words, posted as a public GitHub
/// issue (Feedback). Once it is up, the page shows the issue's number and, off Apple TV, a link to it.
struct FeedbackView: View {
    @State private var kind = Feedback.Kind.bug
    @State private var message = ""
    @State private var sending = false
    @State private var sent: Feedback.Issue?
    @State private var error: String?

    static var note: String {
        L10n.text("Your feedback becomes a public issue on Yingxia's GitHub page, with the app and system versions, the device model and the language. Please don't include accounts, passwords or subscription addresses.")
    }
    private var empty: Bool { message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var thanks: String? { sent.map { L10n.text("Thanks! Your feedback is issue #%lld.", $0.number) } }

    #if DEBUG
    private static var qaDrafted = false
    #endif

    var body: some View {
        content
            #if DEBUG
            // `-qaFeedbackDraft <text>` fills in the message (typing on the TV's keyboard is slow), and
            // `-qaFeedbackSend 1` sends it, to the server named by `-qaFeedback <url>`. Once per launch: the
            // page can appear more than once.
            .onAppear {
                guard !Self.qaDrafted, let draft = UserDefaults.standard.string(forKey: "qaFeedbackDraft") else { return }
                Self.qaDrafted = true
                message = draft
                if UserDefaults.standard.bool(forKey: "qaFeedbackSend") { send() }
            }
            #endif
    }

    @ViewBuilder private var content: some View {
        #if os(tvOS)
        // The note goes under the rows: the hero's subtitle stops at three lines.
        TVSettingsSubpage(symbol: "bubble.left.and.text.bubble.right", title: L10n.text("Send Feedback")) {
            TVSettingsSection(title: L10n.text("Feedback"), footer: [error ?? thanks, Self.note].compactMap { $0 }.joined(separator: "\n\n")) {
                TVSettingsAction(title: L10n.text("Type"), value: kind.title) {
                    let kinds = Feedback.Kind.allCases
                    kind = kinds[((kinds.firstIndex(of: kind) ?? 0) + 1) % kinds.count]
                }
                TVSettingsField(title: L10n.text("Message"), text: $message, prose: true)
                TVSettingsAction(title: sending ? L10n.text("Sending…") : L10n.text("Send"), busy: sending, action: send)
                    .disabled(sending || empty)
            }
        }
        #else
        Form { Group {
            Section {
                Picker(L10n.text("Type"), selection: $kind) {
                    ForEach(Feedback.Kind.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden()
                TextField(L10n.text("Message"), text: $message, prompt: Text(L10n.text("Describe the problem or your idea")), axis: .vertical)
                    .lineLimit(6...12).labelsHidden()
                #if os(macOS)
                HStack {
                    Spacer()
                    if sending { ProgressView().controlSize(.small) }
                    Button(L10n.text("Send"), action: send).buttonStyle(.borderedProminent).disabled(sending || empty)
                }
                #else
                Button(action: send) {
                    HStack { Text(sending ? L10n.text("Sending…") : L10n.text("Send")); Spacer(); if sending { ProgressView() } }
                }
                .disabled(sending || empty)
                #endif
            } footer: {
                Text(Self.note)
            }
            if let sent, let thanks {
                Section {
                    Link(destination: sent.url) {
                        FormLabel(symbol: "checkmark.circle.fill", tint: .green, title: thanks, subtitle: L10n.text("View on GitHub"))
                    }
                    .formRowButton()
                }
            } else if let error {
                Section { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Brand.amber) }
            }
        }.settingsRows() }
        .settingsForm(L10n.text("Send Feedback"))
        #endif
    }

    private func send() {
        guard !sending, !empty else { return }
        sending = true; error = nil; sent = nil
        Task {
            defer { sending = false }
            do {
                sent = try await Feedback.send(message, kind: kind)
                message = ""
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
