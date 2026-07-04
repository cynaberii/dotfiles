import AppKit

struct WalColors {
    let background: NSColor
    let foreground: NSColor
    let color0: NSColor
    let color1: NSColor
    let color2: NSColor
    let color3: NSColor
    let color4: NSColor
    let color5: NSColor
    let color6: NSColor
    let color7: NSColor
    let color8: NSColor
    let color13: NSColor
    let color15: NSColor

    var sbFocusedBubbleBG: NSColor { color13 }
    var sbUnfocusedBubbleBG: NSColor { color8 }
    var sbFocusedGlyph: NSColor { background }
    var sbUnfocusedGlyph: NSColor { color15 }

    static var current: WalColors {
        load() ?? fallback
    }

    static func load() -> WalColors? {
        let path = NSString(string: "~/.cache/wal/colors.json").expandingTildeInPath
        guard
            let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let special = json["special"] as? [String: String],
            let colors = json["colors"] as? [String: String],
            let bg = special["background"].flatMap(NSColor.init(hex:)),
            let fg = special["foreground"].flatMap(NSColor.init(hex:))
        else { return nil }

        func c(_ key: String, _ fallback: NSColor) -> NSColor {
            colors[key].flatMap(NSColor.init(hex:)) ?? fallback
        }

        return WalColors(
            background: bg,
            foreground: fg,
            color0: c("color0", .black),
            color1: c("color1", .red),
            color2: c("color2", .green),
            color3: c("color3", .yellow),
            color4: c("color4", .blue),
            color5: c("color5", .magenta),
            color6: c("color6", .cyan),
            color7: c("color7", .white),
            color8: c("color8", .gray),
            color13: c("color13", .magenta),
            color15: c("color15", fg)
        )
    }

    static var fallback: WalColors {
        let fg = NSColor(hex: "#f2c4e1") ?? .white
        return WalColors(
            background: NSColor(hex: "#280d2a") ?? .black,
            foreground: fg,
            color0: NSColor(hex: "#280d2a") ?? .black,
            color1: NSColor(hex: "#642c66") ?? .red,
            color2: NSColor(hex: "#6d346e") ?? .green,
            color3: NSColor(hex: "#744271") ?? .yellow,
            color4: NSColor(hex: "#804482") ?? .blue,
            color5: NSColor(hex: "#8e568c") ?? .magenta,
            color6: NSColor(hex: "#9c5f9d") ?? .cyan,
            color7: fg,
            color8: NSColor(hex: "#541f57") ?? .gray,
            color13: NSColor(hex: "#aa80a8") ?? .magenta,
            color15: fg
        )
    }
}

extension NSColor {
    convenience init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s = String(s.dropFirst()) }
        guard s.count == 6, let value = UInt64(s, radix: 16) else { return nil }
        self.init(
            red:   CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8)  & 0xFF) / 255,
            blue:  CGFloat( value        & 0xFF) / 255,
            alpha: 1
        )
    }
}
