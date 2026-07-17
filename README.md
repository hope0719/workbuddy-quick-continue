# Quick Continue

一键自动输入"继续"并回车，搭配 AI 对话工具使用。

| 平台 | 快捷键 | 原理 |
|------|--------|------|
| macOS | `Cmd+Shift+J` | Swift 原生，CGEventTap + osascript |
| Windows | `Alt+J` | Python + Win32 API (ctypes)，零依赖 |

两个平台都会自动保存/恢复剪贴板，不会覆盖你已复制的内容。

## 安装

**macOS（一行命令）：**

```bash
curl -fsSL https://raw.githubusercontent.com/hope0719/workbuddy-quick-continue/main/install.sh | bash
```

需要 Xcode Command Line Tools（首次运行会提示安装）。安装后自动配置开机启动。

**Windows（PowerShell 一行命令）：**

```powershell
irm https://raw.githubusercontent.com/hope0719/workbuddy-quick-continue/main/install.ps1 | iex
```

需要 Python 3（[下载](https://python.org)，安装时勾选 Add to PATH）。安装后自动配置开机启动。

## 卸载

```bash
# macOS
curl -fsSL https://raw.githubusercontent.com/hope0719/workbuddy-quick-continue/main/uninstall.sh | bash

# Windows
irm https://raw.githubusercontent.com/hope0719/workbuddy-quick-continue/main/uninstall.ps1 | iex
```

## 工作原理

触发快捷键后：

1. 保存当前剪贴板内容
2. 将"继续"写入剪贴板
3. 模拟粘贴（Cmd+V / Ctrl+V）+ 回车
4. 恢复原来的剪贴板内容

macOS 版用 Swift 编译，通过 CGEventTap 监听全局键盘事件，osascript 模拟输入，零第三方依赖。Windows 版纯 Python ctypes 调用 Win32 API，不需要 pip install 任何包。

## 注意事项

- macOS 首次使用需在「系统设置 → 隐私与安全 → 辅助功能」中允许终端应用
- 确保目标窗口的输入框已获得焦点
- 后台运行，不占资源（macOS 约 2MB 内存，Windows 约 10MB）

## 手动运行

如果不想安装为服务，也可以直接运行：

```bash
# macOS
git clone https://github.com/hope0719/workbuddy-quick-continue.git
cd workbuddy-quick-continue
swiftc -O -framework CoreGraphics -framework AppKit -o quick_continue src/mac/quick_continue.swift
./quick_continue
```

```powershell
# Windows
git clone https://github.com/hope0719/workbuddy-quick-continue.git
cd workbuddy-quick-continue
python src/windows/quick_continue_win.py
```

## License

MIT
