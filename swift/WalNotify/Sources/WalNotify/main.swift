import AppKit

// Usage: WalNotify "wallpaper name"        → shows "<prefix><message>"
//        WalNotify --raw "any message"      → shows the message verbatim, no prefix
// (pywal-coloured HUD in the top-right that fades in/out, then exits.)

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

final class NotifyController: NSObject {
    let message: String
    let raw: Bool
    var window: NSPanel!

    init(message: String, raw: Bool) {
        self.message = message
        self.raw = raw
        super.init()
    }

    func show() {
        let colors = WalColors.current

        let cfg = NotifyConfig.load()

        let accentBarWidth: CGFloat = cfg.accentBarWidth
        let padX: CGFloat = cfg.paddingX
        let padY: CGFloat = cfg.paddingY
        let fontSize = cfg.fontSize

        let font = NSFont(name: "JetBrainsMono Nerd Font", size: fontSize)
            ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)
        let labelText = raw ? message : "\(cfg.prefix)\(message)"
        let attr = NSAttributedString(string: labelText, attributes: [
            .font: font,
            .foregroundColor: colors.color15,
        ])

        let textBounds = attr.boundingRect(
            with: NSSize(width: cfg.maxWidth, height: 100),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        let textSize = NSSize(width: ceil(textBounds.width), height: ceil(textBounds.height))
        let contentW = textSize.width + padX * 2 + accentBarWidth + 8
        let contentH = textSize.height + padY * 2
        let W = min(contentW, cfg.maxWidth)
        let H = max(contentH, cfg.minHeight)

        guard let screen = NSScreen.main else { return }
        let sf = screen.frame
        let x = sf.maxX - W - cfg.marginRight
        let y = sf.maxY - H - cfg.marginTop

        window = NSPanel(
            contentRect: NSRect(x: x, y: y, width: W, height: H),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.hasShadow = true
        window.ignoresMouseEvents = true   // never steals focus/attention
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.alphaValue = 0.0

        let container = NSView(frame: NSRect(x: 0, y: 0, width: W, height: H))
        container.wantsLayer = true
        container.layer?.backgroundColor = colors.background.cgColor
        container.layer?.cornerRadius = cfg.cornerRadius
        container.layer?.borderWidth = 1
        container.layer?.borderColor = colors.color13.cgColor
        container.layer?.masksToBounds = true
        window.contentView = container

        let bar = NSView(frame: NSRect(x: 0, y: 0, width: accentBarWidth, height: H))
        bar.wantsLayer = true
        bar.layer?.backgroundColor = colors.color13.cgColor
        bar.autoresizingMask = [.height]
        container.addSubview(bar)

        let label = NSTextField(labelWithAttributedString: attr)
        label.isBordered = false
        label.drawsBackground = false
        label.lineBreakMode = .byTruncatingTail
        label.frame = NSRect(
            x: accentBarWidth + padX,
            y: (H - ceil(textSize.height)) / 2 + cfg.textYOffset,
            width: ceil(textSize.width) + 4,
            height: ceil(textSize.height)
        )
        container.addSubview(label)

        window.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            window.animator().alphaValue = CGFloat(cfg.maxAlpha)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + cfg.durationSeconds) {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.4
                self.window.animator().alphaValue = 0.0
            }, completionHandler: {
                NSApp.terminate(nil)
            })
        }
    }
}

struct NotifyConfig {
    var prefix: String = "wallpaper changed  ·  "
    var fontSize: CGFloat = 13
    var accentBarWidth: CGFloat = 5
    var paddingX: CGFloat = 16
    var paddingY: CGFloat = 14
    var cornerRadius: CGFloat = 10
    var marginRight: CGFloat = 24
    var marginTop: CGFloat = 52
    var durationSeconds: Double = 3.0
    var maxAlpha: Double = 0.95
    var maxWidth: CGFloat = 600
    var minHeight: CGFloat = 44
    var textYOffset: CGFloat = 0

    static func load() -> NotifyConfig {
        var cfg = NotifyConfig()
        let path = NSString(string: "~/.config/walnotify/config.json").expandingTildeInPath
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return cfg }
        func d(_ k: String) -> CGFloat? { (json[k] as? Double).map { CGFloat($0) } }
        if let s = json["prefix"] as? String { cfg.prefix = s }
        if let v = d("fontSize") { cfg.fontSize = v }
        if let v = d("accentBarWidth") { cfg.accentBarWidth = v }
        if let v = d("paddingX") { cfg.paddingX = v }
        if let v = d("paddingY") { cfg.paddingY = v }
        if let v = d("cornerRadius") { cfg.cornerRadius = v }
        if let v = d("marginRight") { cfg.marginRight = v }
        if let v = d("marginTop") { cfg.marginTop = v }
        if let v = (json["durationSeconds"] as? Double) { cfg.durationSeconds = v }
        if let v = (json["maxAlpha"] as? Double) { cfg.maxAlpha = v }
        if let v = d("maxWidth") { cfg.maxWidth = v }
        if let v = d("minHeight") { cfg.minHeight = v }
        if let v = d("textYOffset") { cfg.textYOffset = v }
        return cfg
    }
}

var parsedArgs = Array(CommandLine.arguments.dropFirst())
var rawMode = false
if let first = parsedArgs.first, first == "--raw" || first == "-r" {
    rawMode = true
    parsedArgs.removeFirst()
}
let message = parsedArgs.first ?? "unknown"
let controller = NotifyController(message: message, raw: rawMode)

final class AppDelegate: NSObject, NSApplicationDelegate {
    let controller: NotifyController
    init(_ c: NotifyController) { self.controller = c }
    func applicationDidFinishLaunching(_ notification: Notification) {
        controller.show()
    }
}

let delegate = AppDelegate(controller)
app.delegate = delegate
app.run()
