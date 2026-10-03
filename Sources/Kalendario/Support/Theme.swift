import SwiftUI

enum Theme {
    static let paper = Color.dynamic(light: "#F8F4EC", dark: "#191817")
    /// A touch darker than the paper: the big weather icon that lies behind each day of the week.
    static let paperShade = Color.dynamic(light: "#EAE2D3", dark: "#0D0C0B")
    /// The column of today: a dark slate (in both appearances) with the events drawn on their own
    /// paper inside it, so they keep their colours and stay readable. The forecast on it is a
    /// **darker celeste** (`#3D8FBC`, about 2,2:1) and lies *behind* the events exactly like the
    /// paperShade of the other days: the user asked for the same superimposition everywhere
    /// («fai il simbolo più scuro e fai lo stesso effetto grafico di sovrapposizione che abbiamo sulle
    /// altre colonne», 2026-10-04). In the dark appearance the column stays *lighter* than the paper,
    /// so the cards do not melt into it. The round "+" of the column is white on today instead of
    /// accent blue: blue on this slate is only 1,7:1, and the button disappeared.
    static let todayColumn = Color.dynamic(light: "#39414B", dark: "#2A313A")
    static let todayColumnIcon = Color(hex: "#3D8FBC")
    static let todayColumnText = Color(hex: "#CFEFFF")
    static let paperElevated = Color.dynamic(light: "#FFFCF5", dark: "#221F1D")
    static let ink = Color.dynamic(light: "#211F1B", dark: "#F3EFE7")
    static let inkSoft = Color.dynamic(light: "#6C655A", dark: "#A8A093")
    static let inkFaint = Color.dynamic(light: "#B6AC9D", dark: "#6B6459")
    static let hairline = Color.dynamic(light: "#E4DBCB", dark: "#312E2A")
    static let accent = Color(hex: "#2C7BC0")
    static let accentStrong = Color(hex: "#1F4E7E")
    static let accentSoft = Color.dynamic(light: "#DCEAF8", dark: "#152A3D")
    static let azure = Color(hex: "#5AA5D8")
    static let todayWash = Color.dynamic(light: "#2C7BC00F", dark: "#2C7BC01A")
    static let weekendWash = Color.dynamic(light: "#8A7F6D0F", dark: "#FFFFFF0D")

    static let titleFont = Font.system(size: 19, weight: .semibold, design: .serif)
    static let tinyFont = Font.system(size: 10.5)
}

struct Separator: View {
    var axis: Axis = .horizontal

    var body: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(width: axis == .vertical ? 1 : nil, height: axis == .vertical ? nil : 1)
    }
}

struct IconButton: View {
    let symbol: String
    var help: String = ""
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .frame(width: 24, height: 24)
                .foregroundStyle(Theme.inkSoft)
                .background(Theme.ink.opacity(0.06), in: Circle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

struct PillButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary }

    var kind: Kind = .secondary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .foregroundStyle(kind == .primary ? Color.white : Theme.ink)
            .background(Capsule().fill(kind == .primary ? Theme.accent : Theme.ink.opacity(0.08)))
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct StatChip: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: 9.5, weight: .semibold))
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
                .lineLimit(1)
        }
        .foregroundStyle(Theme.inkSoft)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Theme.ink.opacity(0.055), in: Capsule())
        .fixedSize()
    }
}

struct FieldBox<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 9.5, weight: .semibold))
                .kerning(0.7)
                .foregroundStyle(Theme.inkFaint)
            content
        }
    }
}

extension View {
    func fieldChrome() -> some View {
        padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(Theme.paperElevated, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            )
    }
}