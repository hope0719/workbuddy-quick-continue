# Quick Continue

一键自动输入"继续"并回车，搭配 AI 对话工具使用。

| 平台 | 快捷键 | 点击触发 | 原理 |
|------|--------|----------|------|
| macOS | `Cmd+Shift+J` | 悬浮小按钮 | Swift 原生，CGEventTap + osascript |
| Windows | `Alt+J` | 悬浮小按钮 | Python + Win32 API (ctypes)，零依赖 |

两个平台都会自动保存/恢复剪贴板，不会覆盖你已复制的内容。

## 安装

**macOS（一行命令）：**

```bash
curl -fsSL https://raw.githubusercontent.com/hope0719/workbuddy-quick-continue/main/install.sh | bash
```

需要 Xcode Command Line Tools（首次运行会提示安装）。安装后自动配置开机启动。

**需要悬浮按钮？** 加 `--button`：

```bash
curl -fsSL https://raw.githubusercontent.com/hope0719/workbuddy-quick-continue/main/install.sh | bash -s -- --button
```

悬浮按钮模式会创建启动器 .app 并添加到「登录项」，开机自动启动。

**使用说明：**
- **自动运行**：已添加到登录项，开机自动启动
- **显示按钮**：运行后自动显示在屏幕右下角
- **隐藏/显示**：点击悬浮按钮可切换
- **关闭程序**：`pkill -f quick_continue` 或从登录项移除

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

## 点击触发模式

默认只有快捷键。加 `--button` 启用点击触发：

**macOS** — 屏幕右下角出现悬浮小按钮，点击即触发（前台运行）：

```bash
curl -fsSL https://raw.githubusercontent.com/hope0719/workbuddy-quick-continue/main/install.sh | bash -s -- --button
```

**Windows** — 屏幕右下角出现悬浮小按钮，可拖动、可右键菜单：

```powershell
irm https://raw.githubusercontent.com/hope0719/workbuddy-quick-continue/main/install.ps1 | iex
```

悬浮按钮支持：
- 左键点击：触发输入
- 拖拽：移动位置
- 右键：暂停/继续、退出

## 工作原理

触发后（快捷键或点击）：

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
# macOS（仅快捷键）
git clone https://github.com/hope0719/workbuddy-quick-continue.git
cd workbuddy-quick-continue
swiftc -O -framework CoreGraphics -framework AppKit -o quick_continue src/mac/quick_continue.swift
./quick_continue

# macOS（快捷键 + 悬浮按钮）
./quick_continue --button
```

```powershell
# Windows（仅快捷键）
git clone https://github.com/hope0719/workbuddy-quick-continue.git
cd workbuddy-quick-continue
python src/windows/quick_continue_win.py

# Windows（快捷键 + 悬浮按钮）
python src/windows/quick_continue_win.py --button
```

## License

MIT
