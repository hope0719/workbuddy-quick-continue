// quick_continue.swift — Native macOS global hotkey + floating button
// Uses CGEventTap for hotkey detection (works in CLI tools)
// Uses osascript for keyboard simulation
//
// Compile:  swiftc -O -framework CoreGraphics -framework AppKit -o quick_continue quick_continue.swift
// Run:      ./quick_continue            # Hotkey only (Cmd+Shift+J)
//           ./quick_continue --button   # Hotkey + floating click button
// Requires: Accessibility permission (System Settings → Privacy → Accessibility)

import CoreGraphics
import AppKit
import Foundation

let TEXT = "继续"
let KVK_ANSI_J: UInt32 = 0x26  // J key
let KVK_ANSI_B: UInt32 = 0x0B  // B key

let useButton = CommandLine.arguments.contains("--button")
let CURRENT_VERSION = "1.1.0"
let REPO = "hope0719/quick-continue"

// ─── Simulate input: save clipboard → paste → enter → restore ────

func simulateInput() {
    let pb = NSPasteboard.general

    // 0) Save current clipboard
    let saved = pb.string(forType: .string)

    // 1) Copy text to clipboard
    pb.clearContents()
    pb.setString(TEXT, forType: .string)

    Thread.sleep(forTimeInterval: 0.08)

    // 2) Simulate Cmd+V (paste) via osascript
    let pasteTask = Process()
    pasteTask.launchPath = "/usr/bin/osascript"
    pasteTask.arguments = ["-e", "tell application \"System Events\" to keystroke \"v\" using command down"]
    pasteTask.launch()
    pasteTask.waitUntilExit()

    Thread.sleep(forTimeInterval: 0.15)

    // 3) Simulate Enter via osascript
    let enterTask = Process()
    enterTask.launchPath = "/usr/bin/osascript"
    enterTask.arguments = ["-e", "tell application \"System Events\" to key code 36"]
    enterTask.launch()
    enterTask.waitUntilExit()

    // 4) Restore original clipboard content
    Thread.sleep(forTimeInterval: 0.1)
    pb.clearContents()
    if let saved = saved {
        pb.setString(saved, forType: .string)
    }
}

// ─── Log helper ──────────────────────────────────────────────────

func logTrigger(_ source: String) {
    let f = DateFormatter()
    f.dateFormat = "HH:mm:ss"
    let ts = f.string(from: Date())
    print("[\(ts)] \(source) → typing '\(TEXT)' + Enter")
    fflush(stdout)
    simulateInput()
}

// ─── Auto-update ─────────────────────────────────────────────────

func getExecutablePath() -> String {
    let buf = UnsafeMutablePointer<CChar>.allocate(capacity: Int(PATH_MAX))
    defer { buf.deallocate() }
    var size: UInt32 = UInt32(PATH_MAX)
    if _NSGetExecutablePath(buf, &size) == 0 {
        return String(cString: buf)
    }
    return ""
}

func checkForUpdate() {
    DispatchQueue.global(qos: .background).async {
        let url = "https://raw.githubusercontent.com/\(REPO)/main/VERSION"
        guard let data = try? Data(contentsOf: URL(string: url)!, options: .alwaysMapped),
              let remoteVersion = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !remoteVersion.isEmpty else { return }

        guard remoteVersion != CURRENT_VERSION else { return }

        print("[AutoUpdate] New version: \(remoteVersion) (current: \(CURRENT_VERSION))")
        fflush(stdout)
        performUpdate(version: remoteVersion)
    }
}

func performUpdate(version: String) {
    let exePath = getExecutablePath()
    guard !exePath.isEmpty else {
        print("[AutoUpdate] Cannot determine executable path, skipping")
        fflush(stdout)
        return
    }

    let sourceURL = "https://raw.githubusercontent.com/\(REPO)/main/src/mac/quick_continue.swift"
    let tmpSource = "/tmp/quick_continue_update_\(version).swift"
    let tmpBinary = "/tmp/quick_continue_update_\(version)"

    // 1) Download source
    let dl = Process()
    dl.launchPath = "/usr/bin/curl"
    dl.arguments = ["-fsSL", sourceURL, "-o", tmpSource]
    dl.launch()
    dl.waitUntilExit()
    guard dl.terminationStatus == 0 else {
        print("[AutoUpdate] Download failed")
        fflush(stdout)
        return
    }

    // 2) Compile
    let comp = Process()
    comp.launchPath = "/usr/bin/swiftc"
    comp.arguments = ["-O", "-framework", "CoreGraphics", "-framework", "AppKit",
                      "-o", tmpBinary, tmpSource]
    comp.launch()
    comp.waitUntilExit()
    try? FileManager.default.removeItem(atPath: tmpSource)
    guard comp.terminationStatus == 0 else {
        print("[AutoUpdate] Compilation failed")
        fflush(stdout)
        return
    }

    // 3) Show notification
    let notify = Process()
    notify.launchPath = "/usr/bin/osascript"
    notify.arguments = ["-e",
        "display notification \"正在更新到 v\(version)，即将自动重启...\" with title \"Quick Continue\""]
    notify.launch()
    notify.waitUntilExit()

    // 4) Build restart command
    let args = CommandLine.arguments.dropFirst()
        .map { "'\($0)'" }
        .joined(separator: " ")
    let restartCmd = args.isEmpty ? exePath : "\(exePath) \(args)"

    // 5) Background script: wait → replace → restart
    let script = """
    sleep 2
    cp '\(tmpBinary)' '\(exePath)'
    rm -f '\(tmpBinary)'
    sleep 0.5
    \(restartCmd) &
    """
    let tmpScript = "/tmp/quick_continue_restart.sh"
    try? script.write(toFile: tmpScript, atomically: true, encoding: .utf8)

    let sh = Process()
    sh.launchPath = "/bin/bash"
    sh.arguments = [tmpScript]
    sh.launch()
    try? FileManager.default.removeItem(atPath: tmpScript)

    print("[AutoUpdate] Updating to v\(version)...")
    fflush(stdout)

    // 6) Exit current process so script can replace binary
    DispatchQueue.main.async {
        NSApp.terminate(nil)
    }
}

// ─── Floating button window ──────────────────────────────────────

// Custom view: handles left-click action, drag-to-move, and right-click menu
// Using NSView instead of NSButton because NSButton's internal tracking
// loop prevents mouseDragged from being called.
class ClickableDraggableView: NSView {
    var onClickAction: (() -> Void)?
    var contextMenu: NSMenu?
    private var _didDrag = false

    override func layout() {
        super.layout()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let text = "▶ 继续" as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 12),
            .foregroundColor: NSColor.white
        ]
        let size = text.size(withAttributes: attrs)
        let x = (bounds.width - size.width) / 2
        let y = (bounds.height - size.height) / 2
        text.draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
    }

    override func mouseDown(with event: NSEvent) {
        _didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        // Use deltaX/deltaY (screen-level deltas) instead of locationInWindow.
        // locationInWindow changes as the window moves, causing feedback loop jitter.
        let dx = event.deltaX
        let dy = event.deltaY
        if abs(dx) > 0.5 || abs(dy) > 0.5 {
            _didDrag = true
            if let panel = window as? NSPanel {
                var origin = panel.frame.origin
                origin.x += dx
                origin.y -= dy  // deltaX/deltaY: y is inverted vs screen coordinates
                panel.setFrameOrigin(origin)
            }
        }
    }

    override func mouseUp(with event: NSEvent) {
        if !_didDrag {
            onClickAction?()
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        if let menu = contextMenu {
            // Pop up below the button to avoid overlapping the text
            menu.popUp(positioning: nil, at: NSPoint(x: bounds.midX, y: -4), in: self)
        }
    }
}

class FloatingButton {
    var window: NSPanel!
    var button: ClickableDraggableView!
    var contextMenu: NSMenu!

    init() {
        // Create borderless, floating panel
        window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 70, height: 36),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.level = .floating           // Always on top
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = false

        // Clickable/draggable button view (replaces NSButton)
        button = ClickableDraggableView(frame: window.contentView!.bounds)
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.systemBlue.cgColor
        button.layer?.cornerRadius = 18
        button.autoresizingMask = [.width, .height]
        window.contentView!.addSubview(button)

        // Click handler
        button.onClickAction = { [weak self] in
            self?.onClick()
        }

        // Right-click context menu
        contextMenu = NSMenu(title: "Quick Continue")
        let hideItem = NSMenuItem(title: "隐藏", action: #selector(onHide), keyEquivalent: "")
        hideItem.target = self
        contextMenu.addItem(hideItem)
        button.contextMenu = contextMenu

        // Position: bottom-right of main screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.maxX - 90
            let y = screenFrame.minY + 60
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }

    @objc func onClick() {
        logTrigger("Button click")
        // Flash green feedback
        button.layer?.backgroundColor = NSColor.systemGreen.cgColor
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.button.layer?.backgroundColor = NSColor.systemBlue.cgColor
        }
    }

    @objc func onHide() {
        window.orderOut(nil)
    }

    func show() {
        window.orderFrontRegardless()
    }

    func close() {
        window.close()
    }
}

var floatingBtn: FloatingButton?

// ─── CGEventTap callback (hotkey) ────────────────────────────────

var tapCallback: CGEventTapCallBack = { proxy, type, event, refcon in
    guard type == .keyDown else { return Unmanaged.passRetained(event) }

    let keycode = event.getIntegerValueField(.keyboardEventKeycode)
    let flags = event.flags

    if keycode == Int64(KVK_ANSI_J) && flags.contains(.maskCommand) && flags.contains(.maskShift) {
        logTrigger("⌘+Shift+J")
    }

    // Toggle button visibility with Cmd+Shift+B
    if keycode == Int64(KVK_ANSI_B) && flags.contains(.maskCommand) && flags.contains(.maskShift) {
        if let btn = floatingBtn {
            if btn.window.isVisible {
                btn.window.orderOut(nil)
            } else {
                btn.window.orderFrontRegardless()
            }
        }
    }

    return Unmanaged.passRetained(event)
}

// ─── Main ────────────────────────────────────────────────────────

print("================================================")
print("  Quick Continue v\(CURRENT_VERSION) (native macOS)")
print("================================================")
print("  Hotkey : ⌘+Shift+J")
if useButton {
    print("  Button : Floating button (bottom-right)")
    print("  Toggle : ⌘+Shift+B (show/hide button)")
    print("  Menu   : Right-click button → 隐藏")
    print("  Drag   : Drag button to reposition")
}
print("  Text   : '\(TEXT)' + Enter")
print("------------------------------------------------")
print("  Clipboard: auto save & restore")
print("================================================")
fflush(stdout)

// Setup NSApplication (needed for floating window)
let app = NSApplication.shared
app.setActivationPolicy(.accessory)

// Create floating button if requested
if useButton {
    floatingBtn = FloatingButton()
    floatingBtn?.show()
}

// Check for updates (async, non-blocking)
checkForUpdate()

// Create CGEventTap for keyboard events
let eventMask: CGEventMask = 1 << CGEventType.keyDown.rawValue
let tap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .listenOnly,
    eventsOfInterest: eventMask,
    callback: tapCallback,
    userInfo: nil
)

guard let tap = tap else {
    print("[ERROR] CGEventTap creation failed!")
    print("[!] Make sure Accessibility permission is enabled")
    print("[!] System Settings → Privacy & Security → Accessibility")
    exit(1)
}

// Add tap to run loop
let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)

print("  Ready.")
if useButton {
    print("  Press ⌘+Shift+J or click the floating ▶ button.")
} else {
    print("  Press ⌘+Shift+J to trigger.")
}
print("  Ctrl+C to quit.")
print("================================================")
fflush(stdout)

// Run app event loop
app.run()
