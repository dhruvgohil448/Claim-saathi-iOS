import SwiftUI

extension Color {
    static let csNavy = Color(red: 7 / 255, green: 59 / 255, blue: 120 / 255)
    static let csCyan = Color(red: 8 / 255, green: 185 / 255, blue: 232 / 255)
    static let csBackground = Color(red: 245 / 255, green: 248 / 255, blue: 252 / 255)
    static let csSuccess = Color(red: 19 / 255, green: 168 / 255, blue: 121 / 255)
    static let csWarning = Color(red: 245 / 255, green: 166 / 255, blue: 35 / 255)
    static let csError = Color(red: 230 / 255, green: 91 / 255, blue: 91 / 255)
    static let csText = Color(red: 23 / 255, green: 43 / 255, blue: 77 / 255)
    static let csSecondary = Color(red: 102 / 255, green: 117 / 255, blue: 138 / 255)
    static let csPale = Color(red: 232 / 255, green: 244 / 255, blue: 252 / 255)
}

enum CSFont {
    static func title() -> Font { .system(size: 28, weight: .bold) }
    static func screenTitle() -> Font { .system(size: 22, weight: .bold) }
    static func cardTitle() -> Font { .system(size: 16, weight: .semibold) }
    static func body() -> Font { .system(size: 15, weight: .regular) }
    static func caption() -> Font { .system(size: 13, weight: .medium) }
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
            .shadow(color: Color.csNavy.opacity(0.06), radius: 14, y: 6)
    }
}

struct StatusBadge: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint.opacity(0.14))
            .clipShape(Capsule())
    }
}

struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.csNavy)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.csNavy)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Color.csPale)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct ScreenHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(CSFont.screenTitle())
                .foregroundStyle(Color.csNavy)
            if let subtitle {
                Text(subtitle)
                    .font(CSFont.body())
                    .foregroundStyle(Color.csSecondary)
            }
            Capsule()
                .fill(Color.csCyan)
                .frame(width: 36, height: 4)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LogoMark: View {
    var size: CGFloat = 84

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(Color.csCyan)
                .frame(width: size, height: size)
                .overlay {
                    Image(systemName: "cross.fill")
                        .font(.system(size: size * 0.38, weight: .bold))
                        .foregroundStyle(.white)
                }
                .background {
                    Circle()
                        .fill(Color.white)
                        .frame(width: size * 1.35, height: size * 1.35)
                }
            Text("Hi!")
                .font(.system(size: size * 0.16, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.csSuccess)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .offset(x: size * 0.22, y: -size * 0.08)
        }
        .padding(.top, 8)
        .padding(.trailing, 12)
    }
}

func inr(_ amount: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = "INR"
    formatter.locale = Locale(identifier: "en_IN")
    formatter.maximumFractionDigits = 0
    return formatter.string(from: NSNumber(value: amount)) ?? "₹\(amount)"
}
