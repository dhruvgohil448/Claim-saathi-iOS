import SwiftUI

extension Color {
    static let csNavy = Color(red: 0 / 255, green: 46 / 255, blue: 110 / 255)
    static let csCyan = Color(red: 0 / 255, green: 186 / 255, blue: 242 / 255)
    static let csBackground = Color(red: 245 / 255, green: 248 / 255, blue: 252 / 255)
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
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.csNavy.opacity(0.08), radius: 12, y: 6)
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
