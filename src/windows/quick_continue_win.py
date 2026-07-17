#!/usr/bin/env python3
"""
Quick Continue for Windows — zero third-party dependencies.
Uses Win32 API (ctypes) for global hotkey + clipboard + keyboard simulation.

Usage:
    python quick_continue_win.py          # Run with Ctrl+Shift+J hotkey
    python quick_continue_win.py --test   # Test type once and exit
"""

import ctypes
import ctypes.wintypes
import time
import argparse
import platform
import threading

# ─── Configuration ───────────────────────────────────────────────
TEXT = "继续"

# ─── Win32 constants ─────────────────────────────────────────────
CF_UNICODETEXT = 13
HOTKEY_ID = 1
MOD_ALT = 0x0001
MOD_SHIFT = 0x0004
VK_J = 0x4A
WM_HOTKEY = 0x0312

# Virtual key codes for keyboard simulation
VK_RETURN = 0x0D
VK_CONTROL = 0x11
VK_MENU = 0x12  # Alt
VK_V = 0x56

INPUT_KEYBOARD = 1
KEYEVENTF_KEYUP = 0x0002
KEYEVENTF_UNICODE = 0x0004

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
    send_key(VK_CONTROL)       # Ctrl down
    send_key(VK_V)             # V down
    send_key(VK_V, KEYEVENTF_KEYUP)    # V up
    send_key(VK_CONTROL, KEYEVENTF_KEYUP)  # Ctrl up


def send_enter():
    """Simulate Enter."""
    send_key(VK_RETURN)
    send_key(VK_RETURN, KEYEVENTF_KEYUP)


# ─── Main action ─────────────────────────────────────────────────

def do_continue():
    ts = time.strftime("%H:%M:%S")
    saved = get_clipboard()  # save before overwriting
    try:
        copy_to_clipboard(TEXT)
        time.sleep(0.08)
        send_ctrl_v()
        time.sleep(0.15)
        send_enter()
        print(f"[{ts}] OK", flush=True)
    except Exception as e:
        print(f"[{ts}] ERROR: {e}", flush=True)
    finally:
        # Restore original clipboard content
        if saved is not None:
            time.sleep(0.1)
            try:
                copy_to_clipboard(saved)
            except Exception:
                pass


# ─── Entry point ─────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Quick Continue (Windows)")
    parser.add_argument("--test", action="store_true", help="Type once and exit")
    args = parser.parse_args()

    if args.test:
        print(f"Typing '{TEXT}' + Enter in 2 seconds, switch to target window...")
        time.sleep(2)
        do_continue()
        return

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
                do_continue()
            user32.TranslateMessage(ctypes.byref(msg))
            user32.DispatchMessageW(ctypes.byref(msg))
    except KeyboardInterrupt:
        pass
    finally:
        user32.UnregisterHotKey(None, HOTKEY_ID)

    print("\nBye!")


if __name__ == "__main__":
    main()
