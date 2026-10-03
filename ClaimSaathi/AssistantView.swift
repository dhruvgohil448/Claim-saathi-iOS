import SwiftUI

struct AssistantView: View {
    @EnvironmentObject private var model: AppModel
    @State private var draft = ""

    private let prompts = [
        "What does my policy cover?",
        "What is my room-rent limit?",
        "Which documents are missing?",
        "Explain this claim status.",
        "Why was this amount deducted?"
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            ScreenHeader(title: "Ask Saathi", subtitle: "Answers use the sample policy and claim only.")
                            suggestionRow
                            ForEach(model.messages) { message in
                                bubble(message)
                                    .id(message.id)
                            }
                        }
                        .padding(20)
                    }
                    .onChange(of: model.messages.count) { _, _ in
                        if let last = model.messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }
                inputBar
            }
            .background(Color.csBackground)
        }
    }

    private var suggestionRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(prompts, id: \.self) { prompt in
                    Button(prompt) {
                        model.ask(prompt)
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.csNavy)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .clipShape(Capsule())
                }
            }
        }
    }

    private func bubble(_ message: ChatMessage) -> some View {
        HStack {
            if message.isUser { Spacer(minLength: 40) }
            Text(message.text)
                .font(CSFont.body())
                .foregroundStyle(message.isUser ? Color.white : Color.csText)
                .padding(14)
                .background(message.isUser ? Color.csNavy : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            if !message.isUser { Spacer(minLength: 40) }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask about the policy or claim", text: $draft)
                .padding(12)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            Button {
                model.ask(draft)
                draft = ""
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.csNavy)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.csBackground)
    }
}

struct ProfileView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ScreenHeader(title: "Profile", subtitle: "Demo customer account.")
                    CSCard {
                        HStack(spacing: 14) {
                            Text("RS")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 52, height: 52)
                                .background(Color.csNavy)
                                .clipShape(Circle())
                            VStack(alignment: .leading, spacing: 4) {
                                Text(model.userName)
                                    .font(CSFont.cardTitle())
                                    .foregroundStyle(Color.csNavy)
                                Text(model.email)
                                    .font(CSFont.caption())
                                    .foregroundStyle(Color.csSecondary)
                                Text(model.phone)
                                    .font(CSFont.caption())
                                    .foregroundStyle(Color.csSecondary)
                            }
                        }
                    }
                    CSCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Linked policy")
                                .font(CSFont.cardTitle())
                                .foregroundStyle(Color.csNavy)
                            Text("\(model.policy.insurer) · \(model.policy.number)")
                                .font(CSFont.body())
                                .foregroundStyle(Color.csText)
                            Text("Sum insured \(inr(model.policy.sumInsured))")
                                .font(CSFont.caption())
                                .foregroundStyle(Color.csSecondary)
                        }
                    }
                    CSCard {
                        VStack(alignment: .leading, spacing: 10) {
                            row("Role", "Customer")
                            row("Data", "Sample records on this device")
                            row("Payouts", "Not connected")
                        }
                    }
                    Button(role: .destructive) {
                        model.logout()
                    } label: {
                        Text("Log out")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
            .background(Color.csBackground)
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(CSFont.caption())
                .foregroundStyle(Color.csSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.csText)
        }
    }
}
