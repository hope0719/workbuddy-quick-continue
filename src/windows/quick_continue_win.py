#!/usr/bin/env python3
"""
Quick Continue for Windows — zero third-party dependencies.
Uses Win32 API (ctypes) for global hotkey + clipboard + keyboard simulation.
Optional tkinter floating button (--button flag).

Usage:
    python quick_continue_win.py          # Hotkey only (Alt+J)
    python quick_continue_win.py --button # Hotkey + floating click button
    python quick_continue_win.py --test   # Test type once and exit
"""

import ctypes
import ctypes.wintypes
import time
import argparse
import sys

# ─── Configuration ───────────────────────────────────────────────
TEXT = "继续"

# ─── Win32 constants ─────────────────────────────────────────────
CF_UNICODETEXT = 13
HOTKEY_ID = 1
MOD_ALT = 0x0001
VK_J = 0x4A
WM_HOTKEY = 0x0312

# Virtual key codes for keyboard simulation
VK_RETURN = 0x0D
VK_CONTROL = 0x11
VK_V = 0x56

INPUT_KEYBOARD = 1
KEYEVENTF_KEYUP = 0x0002

# Module-level extra info to prevent GC of pointer
_extra_info = ctypes.c_ulong(0)
_p_extra_info = ctypes.pointer(_extra_info)


# ─── Structs ─────────────────────────────────────────────────────

class KEYBDINPUT(ctypes.Structure):
    _fields_ = [
        ("wVk", ctypes.wintypes.WORD),
        ("wScan", ctypes.wintypes.WORD),
        ("dwFlags", ctypes.wintypes.DWORD),
        ("time", ctypes.wintypes.DWORD),
        ("dwExtraInfo", ctypes.POINTER(ctypes.c_ulong)),
    ]


class INPUT(ctypes.Structure):
    class _INPUT(ctypes.Union):
        _fields_ = [("ki", KEYBDINPUT)]
    _anonymous_ = ("_input",)
    _fields_ = [
        ("type", ctypes.wintypes.DWORD),
        ("_input", _INPUT),
    ]


# ─── Clipboard ───────────────────────────────────────────────────

def copy_to_clipboard(text):
    user32 = ctypes.windll.user32
    kernel32 = ctypes.windll.kernel32
    user32.OpenClipboard(0)
    user32.EmptyClipboard()
    data = text.encode("utf-16-le") + b"\x00\x00"
    h = kernel32.GlobalAlloc(0x0042, len(data))  # GMEM_MOVEABLE | GMEM_ZEROINIT
    p = kernel32.GlobalLock(h)
    ctypes.memmove(p, data, len(data))
    kernel32.GlobalUnlock(h)
    user32.SetClipboardData(CF_UNICODETEXT, h)
    user32.CloseClipboard()


def get_clipboard():
    """Read current clipboard text. Returns None if empty or not text."""
    user32 = ctypes.windll.user32
    kernel32 = ctypes.windll.kernel32
    if not user32.OpenClipboard(0):
        return None
    try:
        if not user32.IsClipboardFormatAvailable(CF_UNICODETEXT):
            return None
        h = user32.GetClipboardData(CF_UNICODETEXT)
        if not h:
            return None
        p = kernel32.GlobalLock(h)
        if not p:
            return None
        try:
            return ctypes.wstring_at(p)
        finally:
            kernel32.GlobalUnlock(h)
    finally:
        user32.CloseClipboard()


# ─── Keyboard simulation ────────────────────────────────────────

def send_key(vk, flags=0):
    """Send a single key press/release via SendInput."""
    inp = INPUT()
    inp.type = INPUT_KEYBOARD
    inp.ki.wVk = vk
    inp.ki.wScan = 0
    inp.ki.dwFlags = flags
    inp.ki.time = 0
    inp.ki.dwExtraInfo = _p_extra_info
    ctypes.windll.user32.SendInput(1, ctypes.pointer(inp), ctypes.sizeof(inp))


def send_ctrl_v():
    """Simulate Ctrl+V."""
    send_key(VK_CONTROL)
    send_key(VK_V)
    send_key(VK_V, KEYEVENTF_KEYUP)
    send_key(VK_CONTROL, KEYEVENTF_KEYUP)


def send_enter():
    """Simulate Enter."""
    send_key(VK_RETURN)
    send_key(VK_RETURN, KEYEVENTF_KEYUP)


# ─── Main action ─────────────────────────────────────────────────

def do_continue(source="hotkey"):
    ts = time.strftime("%H:%M:%S")
    saved = get_clipboard()  # save before overwriting
    try:
        copy_to_clipboard(TEXT)
        time.sleep(0.08)
        send_ctrl_v()
        time.sleep(0.15)
        send_enter()
        print(f"[{ts}] {source} → OK", flush=True)
    except Exception as e:
        print(f"[{ts}] {source} → ERROR: {e}", flush=True)
    finally:
        # Restore original clipboard content
        if saved is not None:
            time.sleep(0.1)
            try:
                copy_to_clipboard(saved)
            except Exception:
                pass


# ─── Floating button (tkinter) ───────────────────────────────────

def run_with_button():
    """Run with floating button GUI + hotkey."""
    import tkinter as tk

    root = tk.Tk()
    root.title("Quick Continue")
    root.overrideredirect(True)          # No title bar
    root.attributes("-topmost", True)    # Always on top
    root.attributes("-alpha", 0.92)      # Slight transparency

    # Position: bottom-right corner
    root.update_idletasks()
    sw, sh = root.winfo_screenwidth(), root.winfo_screenheight()
    x, y = sw - 80, sh - 130
    root.geometry(f"+{x}+{y}")

    # Draggable window
    def start_drag(e):
        root._drag_x = e.x
        root._drag_y = e.y

    def do_drag(e):
        dx = e.x - root._drag_x
        dy = e.y - root._drag_y
        root.geometry(f"+{root.winfo_x() + dx}+{root.winfo_y() + dy}")

    # Frame with border
    frame = tk.Frame(root, bg="#3b82f6", padx=2, pady=2)
    frame.pack(fill="both", expand=True)

    # Click label (acts as button)
    label = tk.Label(
        frame, text="▶ 继续", font=("Microsoft YaHei", 11, "bold"),
        bg="#3b82f6", fg="white", padx=14, pady=6, cursor="hand2",
    )
    label.pack()

    active = [True]

    def on_click(e=None):
        if active[0]:
            do_continue("button")
            # Flash feedback
            frame.configure(bg="#22c55e")
            label.configure(bg="#22c55e")
            root.after(200, lambda: (
                frame.configure(bg="#3b82f6"),
                label.configure(bg="#3b82f6"),
            ))

    def toggle_state():
        active[0] = not active[0]
        if active[0]:
            frame.configure(bg="#3b82f6")
            label.configure(bg="#3b82f6", text="▶ 继续")
        else:
            frame.configure(bg="#6b7280")
            label.configure(bg="#6b7280", text="⏸ 暂停")

    def quit_app():
        try:
            ctypes.windll.user32.UnregisterHotKey(None, HOTKEY_ID)
        except Exception:
            pass
        root.destroy()

    # Right-click menu
    menu = tk.Menu(root, tearoff=0)
    menu.add_command(label="暂停/继续", command=toggle_state)
    menu.add_separator()
    menu.add_command(label="退出", command=quit_app)

    def show_menu(e):
        try:
            menu.tk_popup(e.x_root, e.y_root)
        finally:
            menu.grab_release()

    label.bind("<Button-1>", on_click)
    label.bind("<ButtonPress-1>", start_drag)
    label.bind("<B1-Motion>", do_drag)
    label.bind("<Button-3>", show_menu)
    frame.bind("<ButtonPress-1>", start_drag)
    frame.bind("<B1-Motion>", do_drag)

    # Register Win32 hotkey
    user32 = ctypes.windll.user32
    hotkey_ok = user32.RegisterHotKey(None, HOTKEY_ID, MOD_ALT, VK_J)

    print("=" * 48)
    print("  Quick Continue (Windows)")
    print("=" * 48)
    if hotkey_ok:
        print("  Hotkey : Alt+J")
    else:
        print("  Hotkey : (register failed, button only)")
    print("  Button : Click the floating ▶ button")
    print(f"  Text   : '{TEXT}' + Enter")
    print("-" * 48)
    print("  Drag: hold and move | Right-click: menu")
    print("=" * 48)

    # Poll for hotkey messages (integrates Win32 + tkinter)
    msg = ctypes.wintypes.MSG()

    def poll_hotkey():
        if hotkey_ok:
            while user32.PeekMessageW(ctypes.byref(msg), 0, 0, 0, 1):
                if msg.message == WM_HOTKEY and msg.wParam == HOTKEY_ID:
                    do_continue("hotkey")
                user32.TranslateMessage(ctypes.byref(msg))
                user32.DispatchMessageW(ctypes.byref(msg))
        root.after(50, poll_hotkey)

    root.after(50, poll_hotkey)
    root.protocol("WM_DELETE_WINDOW", quit_app)
    root.mainloop()


# ─── Hotkey-only mode (no GUI) ──────────────────────────────────

def run_hotkey_only():
    """Run with hotkey only, no GUI."""
    user32 = ctypes.windll.user32

    print("=" * 48)
    print("  Quick Continue (Windows)")
    print("=" * 48)
    print(f"  Hotkey : Alt+J")
    print(f"  Text   : '{TEXT}' + Enter")
    print("-" * 48)

    if not user32.RegisterHotKey(None, HOTKEY_ID, MOD_ALT, VK_J):
        print("[ERROR] RegisterHotKey failed. Is another app using Alt+J?")
        return

    print("  Ready. Press Alt+J to trigger.")
    print("  Ctrl+C to quit.")
    print("=" * 48)

    try:
        msg = ctypes.wintypes.MSG()
        while user32.GetMessageW(ctypes.byref(msg), None, 0, 0) != 0:
            if msg.message == WM_HOTKEY and msg.wParam == HOTKEY_ID:
                do_continue("hotkey")
            user32.TranslateMessage(ctypes.byref(msg))
            user32.DispatchMessageW(ctypes.byref(msg))
    except KeyboardInterrupt:
        pass
    finally:
        user32.UnregisterHotKey(None, HOTKEY_ID)

    print("\nBye!")


# ─── Entry point ─────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Quick Continue (Windows)")
    parser.add_argument("--test", action="store_true", help="Type once and exit")
    parser.add_argument("--button", action="store_true", help="Show floating click button")
    args = parser.parse_args()

    if args.test:
        print(f"Typing '{TEXT}' + Enter in 2 seconds, switch to target window...")
        time.sleep(2)
        do_continue("test")
        return

    if args.button:
        run_with_button()
    else:
        run_hotkey_only()


if __name__ == "__main__":
    main()
