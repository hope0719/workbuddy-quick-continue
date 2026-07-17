// quick_continue.swift — Native macOS global hotkey tool
// Uses CGEventTap for hotkey detection (works in CLI tools)
// Uses CGEvent for keyboard simulation
//
// Compile:  swiftc -O -framework CoreGraphics -framework AppKit -o quick_continue quick_continue.swift
// Run:      ./quick_continue
// Requires: Accessibility permission (System Settings → Privacy → Accessibility)

import CoreGraphics
import AppKit
import Foundation

let TEXT = "继续"
let KVK_ANSI_J: UInt32 = 0x26  // J key

// ─── Simulate input: copy to clipboard → paste → enter ─────────

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

// ─── CGEventTap callback ────────────────────────────────────────

var tapCallback: CGEventTapCallBack = { proxy, type, event, refcon in
    guard type == .keyDown else { return Unmanaged.passRetained(event) }

    let keycode = event.getIntegerValueField(.keyboardEventKeycode)
    let flags = event.flags

    if keycode == Int64(KVK_ANSI_J) && flags.contains(.maskCommand) && flags.contains(.maskShift) {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        let ts = f.string(from: Date())
        print("[\(ts)] ⌘+Shift+J → typing '\(TEXT)' + Enter")
        fflush(stdout)
        simulateInput()
    }

    return Unmanaged.passRetained(event)
}

// ─── Main ───────────────────────────────────────────────────────

print("================================================")
print("  Quick Continue (native macOS)")
print("================================================")
print("  Hotkey : ⌘+Shift+J")
print("  Text   : '\(TEXT)' + Enter")
print("------------------------------------------------")
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
    print("[!] Make sure Accessibility permission is enabled for Terminal")
    print("[!] System Settings → Privacy & Security → Accessibility")
    exit(1)
}

// Add tap to run loop
let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)

print("  Ready. Press ⌘+Shift+J to trigger.")
print("  Ctrl+C to quit.")
print("================================================")
fflush(stdout)

// Run loop
CFRunLoopRun()
