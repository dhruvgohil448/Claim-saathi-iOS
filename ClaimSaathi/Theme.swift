import SwiftUI

extension Color {
    static let csNavy = Color(red: 0 / 255, green: 46 / 255, blue: 110 / 255)
    static let csCyan = Color(red: 0 / 255, green: 186 / 255, blue: 242 / 255)
    static let csBackground = Color(red: 245 / 255, green: 247 / 255, blue: 250 / 255)
    static let csSuccess = Color(red: 18 / 255, green: 183 / 255, blue: 106 / 255)
    static let csWarning = Color(red: 247 / 255, green: 144 / 255, blue: 9 / 255)
    static let csError = Color(red: 240 / 255, green: 68 / 255, blue: 56 / 255)
    static let csText = Color(red: 0 / 255, green: 46 / 255, blue: 110 / 255)
    static let csSecondary = Color(red: 107 / 255, green: 122 / 255, blue: 144 / 255)
    static let csPale = Color(red: 227 / 255, green: 234 / 255, blue: 243 / 255)
}

func inr(_ amount: Int?) -> String {
    guard let amount else { return "–" }
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = "INR"
    formatter.locale = Locale(identifier: "en_IN")
    formatter.maximumFractionDigits = 0
    return formatter.string(from: NSNumber(value: amount)) ?? "₹\(amount)"
}

func pretty(_ raw: String) -> String {
    raw.replacingOccurrences(of: "_", with: " ").capitalized
}

struct CSCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.csNavy.opacity(0.07), radius: 10, y: 4)
    }
}

struct StatusBadge: View {
    let title: String
    let tint: Color
    var body: some View {
        Text(pretty(title))
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint.opacity(0.12))
            .clipShape(Capsule())
    }
}

struct PrimaryButton: View {
    let title: String
    var busy: Bool = false
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if busy { ProgressView().tint(.white) }
                Text(title).font(.system(size: 16, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(enabled && !busy ? Color.csCyan : Color.csCyan.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .disabled(!enabled || busy)
        .buttonStyle(.plain)
    }
}

struct GhostButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.csNavy)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.csPale, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}

struct BrandMark: View {
    var size: CGFloat = 56
    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
            .fill(Color.csCyan)
            .frame(width: size, height: size)
            .overlay {
                Text("+").font(.system(size: size * 0.46, weight: .black)).foregroundStyle(.white)
            }
    }
}

struct NavyHero<Extra: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var extra: Extra

    init(_ title: String, _ subtitle: String, @ViewBuilder extra: () -> Extra = { EmptyView() }) {
        self.title = title
        self.subtitle = subtitle
        self.extra = extra()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            BrandMark()
            Text(title)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(3)
            extra
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 22)
        .safeAreaPadding(.top)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Color(red: 0, green: 0.23, blue: 0.55), Color.csNavy, Color(red: 0, green: 0.12, blue: 0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea(edges: .top)
        )
    }
}

struct StepDots: View {
    let current: Int
    let total: Int
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index <= current ? Color.csCyan : Color.csPale)
                    .frame(width: index == current ? 22 : 6, height: 6)
                    .animation(.spring(duration: 0.35), value: current)
            }
        }
    }
}

struct OtpBoxes: View {
    @Binding var value: String
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            TextField("", text: $value)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .textFieldStyle(.plain)
                .foregroundStyle(.clear)
                .tint(.clear)
                .focused($focused)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .onChange(of: value) { _, next in
                    value = String(next.filter(\.isNumber).prefix(6))
                }

            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { index in
                    let filled = value.count > index ? String(Array(value)[index]) : ""
                    Text(filled)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.csNavy)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(value.count == index ? Color.csCyan : Color.csPale, lineWidth: 2))
                }
            }
            .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
        .onAppear { focused = true }
    }
}

struct ActionTile: View {
    let icon: String
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(Color.csNavy)
                .frame(width: 36, height: 36)
                .background(Color.csPale)
                .clipShape(Circle())
            Text(title).font(.system(size: 13, weight: .bold)).foregroundStyle(Color.csNavy).lineLimit(2).minimumScaleFactor(0.8)
            Text(subtitle).font(.system(size: 11)).foregroundStyle(Color.csSecondary).lineLimit(2).minimumScaleFactor(0.8)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.csNavy.opacity(0.06), radius: 8, y: 4)
    }
}

struct FieldBox: View {
    let title: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.csSecondary)
            TextField(title, text: $text)
                .keyboardType(keyboard)
                .padding(14)
                .background(Color.csBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}


// MARK: - Shared UI polish components

struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = -1
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { g in
                    LinearGradient(colors: [Color.white.opacity(0), Color.white.opacity(0.65), Color.white.opacity(0)], startPoint: .leading, endPoint: .trailing)
                        .frame(width: g.size.width * 0.5)
                        .offset(x: phase * g.size.width * 1.5)
                }
                .allowsHitTesting(false)
            )
            .clipped()
            .onAppear { withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) { phase = 1.2 } }
    }
}

struct SkeletonCard: View {
    var lines: Int = 3
    var body: some View {
        CSCard {
            VStack(alignment: .leading, spacing: 10) {
                RoundedRectangle(cornerRadius: 6).fill(Color.csPale).frame(width: 110, height: 12)
                ForEach(0..<lines, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 6).fill(Color.csPale.opacity(0.8))
                        .frame(maxWidth: i == lines - 1 ? 170 : .infinity).frame(height: 12)
                }
            }
        }
        .modifier(Shimmer())
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Color.csCyan)
                .frame(width: 64, height: 64)
                .background(Color.csCyan.opacity(0.1))
                .clipShape(Circle())
            Text(title).font(.headline).foregroundStyle(Color.csNavy)
            Text(message).font(.footnote).foregroundStyle(Color.csSecondary).multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}

struct UploadProgressBar: View {
    let done: Int
    let total: Int
    private var complete: Bool { total > 0 && done >= total }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: complete ? "checkmark.seal.fill" : "doc.badge.arrow.up.fill")
                    .foregroundStyle(complete ? Color.csSuccess : Color.csCyan)
                Text(complete ? "All documents verified" : "Documents verified")
                    .font(.subheadline.bold()).foregroundStyle(Color.csNavy)
                Spacer()
                Text("\(done)/\(total)").font(.subheadline.bold()).foregroundStyle(complete ? Color.csSuccess : Color.csCyan)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.csPale)
                    Capsule().fill(complete ? Color.csSuccess : Color.csCyan)
                        .frame(width: total > 0 ? g.size.width * CGFloat(min(done, total)) / CGFloat(total) : 0)
                }
            }
            .frame(height: 8)
            .animation(.spring(duration: 0.5), value: done)
        }
    }
}

struct SaathiAvatar: View {
    var size: CGFloat = 30
    var body: some View {
        Image(systemName: "sparkles")
            .font(.system(size: size * 0.45, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(LinearGradient(colors: [Color.csCyan, Color.csNavy], startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(Circle())
    }
}

/// Small bot bubble that explains the current step / next document.
struct SaathiTip: View {
    let text: String
    var action: (() -> Void)? = nil
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            SaathiAvatar()
            VStack(alignment: .leading, spacing: 4) {
                Text("Saathi tip").font(.caption.bold()).foregroundStyle(Color.csCyan)
                Text(text).font(.footnote).foregroundStyle(Color.csNavy).fixedSize(horizontal: false, vertical: true)
                if let action {
                    Button(action: action) { Text("Ask Saathi →").font(.caption.bold()) }.buttonStyle(.plain).foregroundStyle(Color.csCyan)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.csCyan.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.csCyan.opacity(0.25), lineWidth: 1))
    }
}

struct TypingDots: View {
    @State private var on = false
    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle().fill(Color.csSecondary)
                    .frame(width: 7, height: 7)
                    .opacity(on ? 1 : 0.3)
                    .scaleEffect(on ? 1 : 0.7)
                    .animation(.easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.18), value: on)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onAppear { on = true }
    }
}

/// Floating "Ask Saathi" button that opens the chat with context.
struct SaathiFab: ViewModifier {
    var prompt: String? = nil
    var claimId: String? = nil
    @Environment(AppState.self) private var app
    @State private var open = false
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottomTrailing) {
                Button { open = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                        Text("Ask Saathi").font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(LinearGradient(colors: [Color.csCyan, Color(red: 0, green: 0.45, blue: 0.85)], startPoint: .leading, endPoint: .trailing))
                    .clipShape(Capsule())
                    .shadow(color: Color.csNavy.opacity(0.25), radius: 10, y: 4)
                }
                .buttonStyle(.plain)
                .padding(16)
            }
            .sheet(isPresented: $open) {
                ChatScreen(initialPrompt: prompt, contextClaimId: claimId, inSheet: true)
                    .environment(app)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
    }
}

extension View {
    func saathiFab(prompt: String? = nil, claimId: String? = nil) -> some View {
        modifier(SaathiFab(prompt: prompt, claimId: claimId))
    }
}
