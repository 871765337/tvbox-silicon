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
        #elseif os(macOS)
        FeedbackMacPage(kind: $kind, message: $message, sending: sending, sent: $sent, error: error, send: send)
        #else
        Form { Group {
            Section {
                Picker(L10n.text("Type"), selection: $kind) {
                    ForEach(Feedback.Kind.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden()
                TextField(L10n.text("Message"), text: $message, prompt: Text(L10n.text("Describe the problem or your idea")), axis: .vertical)
                    .lineLimit(6...12).labelsHidden()
                Button(action: send) {
                    HStack { Text(sending ? L10n.text("Sending…") : L10n.text("Send")); Spacer(); if sending { ProgressView() } }
                }
                .disabled(sending || empty)
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

#if os(macOS)
// MARK: Send Feedback on the Mac
// A page of its own rather than a form: a short invitation, the three kinds as cards, a roomy editor
// with Send in its bottom bar (⌘↩), and what goes with the message spelled out. Once the issue is
// up, a thank-you card links to it.

private struct FeedbackMacPage: View {
    @Binding var kind: Feedback.Kind
    @Binding var message: String
    let sending: Bool
    @Binding var sent: Feedback.Issue?
    let error: String?
    let send: () -> Void
    @FocusState private var editing: Bool
    @Environment(\.openURL) private var openURL

    private var empty: Bool { message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private static let card = RoundedRectangle(cornerRadius: 14, style: .continuous)

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                header
                if let sent {
                    thanks(sent).transition(.scale(scale: 0.97).combined(with: .opacity))
                } else {
                    form.transition(.opacity)
                }
            }
            .padding(.horizontal, 32).padding(.top, 32).padding(.bottom, 40)
            .frame(maxWidth: Layout.settingsWidth)
            .frame(maxWidth: .infinity)
            .animation(.smooth(duration: 0.35), value: sent)
        }
        .screenTitle(L10n.text("Send Feedback"), width: Layout.settingsWidth)
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "bubble.left.and.text.bubble.right.fill")
                .font(.system(size: 30, weight: .semibold)).foregroundStyle(.white)
                .frame(width: 68, height: 68)
                .background(LinearGradient(colors: [Brand.cyan, Brand.indigo], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.22), lineWidth: 0.5) }
                .shadow(color: Brand.indigo.opacity(0.45), radius: 18, y: 8)
                .padding(.bottom, 8)
            Text(L10n.text("Help Make Yingxia Better")).font(.title.weight(.bold))
            Text(L10n.text("Report a problem or share an idea. It goes straight to the developer."))
                .font(.title3).foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                ForEach(Feedback.Kind.allCases, id: \.self) { option in
                    FeedbackKindCard(kind: option, selected: option == kind) { kind = option; editing = true }
                }
            }
            composer
            if let error {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Brand.amber)
                    Text(error)
                }
                .font(.callout)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Brand.amber.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            details
        }
    }

    private var composer: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                // TextEditor has no prompt: this sits where its first line starts.
                if message.isEmpty {
                    Text(kind.prompt).foregroundStyle(.tertiary).padding(.leading, 5).allowsHitTesting(false)
                }
                TextEditor(text: $message)
                    .scrollContentBackground(.hidden)
                    .focused($editing)
            }
            .font(.system(size: 14))
            .frame(minHeight: 200)
            .padding(14)
            Divider()
            HStack(spacing: 10) {
                Text(verbatim: "\(message.count.formatted()) / \(Feedback.limit.formatted())")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(message.count > Feedback.limit ? AnyShapeStyle(Brand.amber) : AnyShapeStyle(.tertiary))
                Spacer()
                if sending { ProgressView().controlSize(.small) }
                Text(verbatim: "⌘↩").font(.callout).foregroundStyle(.tertiary)
                Button(action: send) {
                    Label(sending ? L10n.text("Sending…") : L10n.text("Send"), systemImage: "paperplane.fill").padding(.horizontal, 6)
                }
                .buttonStyle(.borderedProminent).tint(systemAccent).controlSize(.large)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(sending || empty)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
        }
        .background { Self.card.fill(Color.primary.opacity(0.05)) }
        .overlay { Self.card.strokeBorder(editing ? systemAccent.opacity(0.8) : Color.primary.opacity(0.08), lineWidth: editing ? 1.5 : 1) }
        .animation(.easeOut(duration: 0.15), value: editing)
        .onAppear { editing = true }
    }

    private var details: some View {
        let details = Feedback.details
        let language = Locale(identifier: details.language).localizedString(forIdentifier: details.language) ?? details.language
        return VStack(alignment: .leading, spacing: 10) {
            Text(L10n.text("Sent with your message")).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { chips(details, language: language) }
                VStack(alignment: .leading, spacing: 8) { chips(details, language: language) }
            }
            Label(FeedbackView.note, systemImage: "globe").font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder private func chips(_ details: Feedback.Details, language: String) -> some View {
        chip("app.badge.fill", "\(L10n.text("Yingxia")) \(details.app)")
        chip("desktopcomputer", details.system)
        chip("cpu", details.model)
        chip("character.bubble", language)
    }

    private func chip(_ symbol: String, _ text: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.callout).lineLimit(1).fixedSize()
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Color.primary.opacity(0.06), in: Capsule())
    }

    private func thanks(_ issue: Feedback.Issue) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56)).symbolRenderingMode(.palette).foregroundStyle(.white, .green)
                .shadow(color: .green.opacity(0.45), radius: 18, y: 6)
                .padding(.bottom, 4)
            Text(L10n.text("Thank You!")).font(.title2.weight(.bold))
            Text(L10n.text("Your feedback is now issue #%lld on GitHub.", issue.number)).font(.title3).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Button(L10n.text("Send Another")) { sent = nil; editing = true }
                    .controlSize(.large)
                Button { openURL(issue.url) } label: { Label(L10n.text("View on GitHub"), systemImage: "arrow.up.right") }
                    .buttonStyle(.borderedProminent).tint(systemAccent).controlSize(.large)
            }
            .padding(.top, 10)
        }
        .multilineTextAlignment(.center)
        .padding(.vertical, 40).padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .background {
            Self.card.fill(Color.primary.opacity(0.05))
                .overlay { Self.card.fill(RadialGradient(colors: [Color.green.opacity(0.16), .clear], center: .top, startRadius: 0, endRadius: 260)) }
        }
        .overlay { Self.card.strokeBorder(Color.primary.opacity(0.08)) }
    }
}

/// One kind of feedback as a card: its symbol, name and a line on what it is for.
private struct FeedbackKindCard: View {
    let kind: Feedback.Kind
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false
    private let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Image(systemName: kind.symbol)
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(kind.tint.gradient, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16))
                        .foregroundStyle(selected ? AnyShapeStyle(kind.tint) : AnyShapeStyle(.tertiary))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.title).font(.headline)
                    Text(kind.blurb).font(.callout).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { shape.fill(selected ? kind.tint.opacity(0.14) : Color.primary.opacity(hovering ? 0.08 : 0.05)) }
            .overlay { shape.strokeBorder(selected ? kind.tint.opacity(0.85) : Color.primary.opacity(hovering ? 0.14 : 0.08), lineWidth: selected ? 1.5 : 1) }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: selected)
        .animation(.easeOut(duration: 0.12), value: hovering)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private extension Feedback.Kind {
    var symbol: String {
        switch self {
        case .bug: "ladybug.fill"
        case .idea: "lightbulb.fill"
        case .other: "ellipsis.bubble.fill"
        }
    }
    var tint: Color {
        switch self {
        case .bug: Brand.rose
        case .idea: .orange
        case .other: Brand.indigo
        }
    }
    var blurb: String {
        switch self {
        case .bug: L10n.text("Something isn't working")
        case .idea: L10n.text("An idea or a wish")
        case .other: L10n.text("Anything else")
        }
    }
    /// The editor's prompt, asking for what helps most with this kind.
    var prompt: String {
        switch self {
        case .bug: L10n.text("What happened? What did you expect instead?")
        case .idea: L10n.text("What would make Yingxia better for you?")
        case .other: L10n.text("What's on your mind?")
        }
    }
}
#endif
