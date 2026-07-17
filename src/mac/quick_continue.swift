// quick_continue.swift — Native macOS global hotkey + menu bar button
// Uses CGEventTap for hotkey detection (works in CLI tools)
// Uses osascript for keyboard simulation
//
// Compile:  swiftc -O -framework CoreGraphics -framework AppKit -o quick_continue quick_continue.swift
// Run:      ./quick_continue            # Hotkey only (Cmd+Shift+J)
//           ./quick_continue --button   # Hotkey + menu bar icon (click to trigger)
// Requires: Accessibility permission (System Settings → Privacy → Accessibility)

import CoreGraphics
import AppKit
import Foundation

let TEXT = "继续"
let KVK_ANSI_J: UInt32 = 0x26  // J key

let useButton = CommandLine.arguments.contains("--button")

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

// ─── Menu bar icon (always shown) ────────────────────────────────

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
statusItem.button?.title = "▶"
statusItem.button?.toolTip = "Quick Continue — click to type '\(TEXT)'"

if useButton {
    statusItem.button?.action = #selector(StatusButtonHandler.onClick)
    statusItem.button?.target = StatusButtonHandler.shared
    statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
} else {
    // Hotkey-only mode: show menu with just Quit
    let menu = NSMenu()
    menu.addItem(withTitle: "Quick Continue — Hotkey ⌘+Shift+J", action: nil, keyEquivalent: "")
    menu.addItem(NSMenuItem.separator())
    menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    statusItem.menu = menu
}

class StatusButtonHandler: NSObject {
    static let shared = StatusButtonHandler()
    @objc func onClick() {
        let event = NSApp.currentEvent!
        if event.type == .rightMouseUp {
            // Right-click: show menu
            let menu = NSMenu()
            menu.addItem(withTitle: "Quick Continue", action: nil, keyEquivalent: "")
            menu.addItem(NSMenuItem.separator())
            menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            // Left-click: trigger
            logTrigger("MenuBar click")
        }
    }
}

// ─── CGEventTap callback (hotkey) ────────────────────────────────

var tapCallback: CGEventTapCallBack = { proxy, type, event, refcon in
    guard type == .keyDown else { return Unmanaged.passRetained(event) }

    let keycode = event.getIntegerValueField(.keyboardEventKeycode)
    let flags = event.flags

    if keycode == Int64(KVK_ANSI_J) && flags.contains(.maskCommand) && flags.contains(.maskShift) {
        logTrigger("⌘+Shift+J")
    }

    return Unmanaged.passRetained(event)
}

// ─── Main ────────────────────────────────────────────────────────

print("================================================")
print("  Quick Continue (native macOS)")
print("================================================")
print("  Hotkey : ⌘+Shift+J")
if useButton {
    print("  Button : Menu bar icon (click ▶)")
}
print("  Text   : '\(TEXT)' + Enter")
print("------------------------------------------------")
print("  Clipboard: auto save & restore")
print("================================================")
fflush(stdout)

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
if !useButton {
    print("  Press ⌘+Shift+J to trigger.")
} else {
    print("  Press ⌘+Shift+J or click ▶ in menu bar.")
}
print("  Ctrl+C to quit.")
print("================================================")
fflush(stdout)

// Run app event loop (handles both menu bar and CGEventTap)
app.run()
