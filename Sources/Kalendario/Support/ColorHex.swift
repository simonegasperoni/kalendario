import SwiftUI
import AppKit

extension NSColor {
    static func hex(_ string: String) -> NSColor {
        var raw = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if raw.hasPrefix("#") { raw.removeFirst() }
        if raw.hasPrefix("0x") { raw.removeFirst(2) }

        if raw.count == 3 || raw.count == 4 {
            var expanded = ""
            for character in raw { expanded.append(contentsOf: [character, character]) }
            raw = expanded
        }

        var value: UInt64 = 0
        guard raw.count == 6 || raw.count == 8, Scanner(string: raw).scanHexInt64(&value) else {
            return NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)
        }

        let hasAlpha = raw.count == 8
        let red = CGFloat((value >> (hasAlpha ? 24 : 16)) & 0xFF) / 255
        let green = CGFloat((value >> (hasAlpha ? 16 : 8)) & 0xFF) / 255
        let blue = CGFloat((value >> (hasAlpha ? 8 : 0)) & 0xFF) / 255
        let alpha = hasAlpha ? CGFloat(value & 0xFF) / 255 : 1
        return NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }
}

extension Color {
    init(hex: String) {
        self.init(nsColor: NSColor.hex(hex))
    }

    static func dynamic(light: String, dark: String) -> Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor.hex(isDark ? dark : light)
        }))
    }
}