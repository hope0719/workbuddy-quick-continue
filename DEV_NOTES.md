# 开发踩坑记录

开发 Quick Continue 过程中遇到的问题和解决方案，供后续参考。

---

## macOS 悬浮按钮拖拽失效

**现象**：用 NSButton 子类实现拖拽，mouseDragged 永远不会被调用。

**原因**：NSButton 内部有一个 tracking loop，在鼠标按下后进入点击追踪状态，此期间所有 mouseDragged 事件都被内部拦截，不会分发到子类。

**解决**：放弃 NSButton 子类方案，改用自定义 NSView 子类（ClickableDraggableView），直接在 NSView 上处理 mouseDown / mouseDragged / mouseUp。

---

## 拖拽时窗口抖动、不跟手

**现象**：拖拽按钮时窗口剧烈抖动，没有跟随鼠标移动。

**原因**：用 `event.locationInWindow` 计算位移差值。但窗口移动时，窗口坐标系也在变化，导致计算出的 delta 包含窗口位移的反馈，形成正反馈循环。

**解决**：改用 `event.deltaX` / `event.deltaY`，这是屏幕级别的鼠标增量，不受窗口坐标系影响。注意 deltaY 方向与屏幕坐标相反，需要取反。

```swift
// 错误：locationInWindow 会随窗口移动而变化
let dx = current.x - _dragStart.x

// 正确：deltaX/deltaY 是屏幕级增量
let dx = event.deltaX
let dy = -event.deltaY  // 注意取反
```

---

## 按钮文字无法居中

**现象**：NSTextField 中的文字偏右，不在按钮正中央。

**原因**：NSTextField 有不可控的内边距和排版行为（baseline alignment、cell padding 等），即使设置了 alignment = .center 也无法精确居中。

**解决**：去掉 NSTextField，改用 `draw(_:)` 在 NSView 上直接绘制文字，手动计算中心坐标：

```swift
override func draw(_ dirtyRect: NSRect) {
    let text = "▶ 继续" as NSString
    let size = text.size(withAttributes: attrs)
    let x = (bounds.width - size.width) / 2
    let y = (bounds.height - size.height) / 2
    text.draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
}
```

同时在 `layout()` 中调用 `needsDisplay = true` 确保 resize 后重绘。

---

## 右键菜单遮挡按钮文字

**现象**：右键弹出的"隐藏"菜单覆盖在按钮文字上方。

**原因**：菜单弹出位置设为按钮中心 `NSPoint(x: bounds.midX, y: bounds.midY)`。

**解决**：将弹出位置改到按钮底部 `NSPoint(x: bounds.midX, y: -4)`。

---

## NSClickGestureRecognizer 在 borderless NSPanel 上无效

**现象**：给 NSButton 添加 NSClickGestureRecognizer 无法触发右键菜单。

**原因**：Button 覆盖了整个 contentView，拦截了手势识别器的事件。

**解决**：放弃 NSClickGestureRecognizer，直接在自定义 view 上 override `rightMouseDown` 来弹出菜单。

---

## startTracking / continueTracking override 编译失败

**现象**：尝试 override startTracking 和 continueTracking 实现拖拽判断，编译器报错 "method does not override any method from its superclass"。

**原因**：这两个是 NSCell 的方法，不是 NSButton 的方法。NSButton 不直接暴露这些方法。

**解决**：改用 mouseDown / mouseDragged / mouseUp 方案，用 `_didDrag` 标志位区分点击和拖拽。

---

## mktemp 报 "File exists"

**现象**：install.sh 中 mktemp 创建临时文件时报文件已存在。

**原因**：上次运行残留的临时文件未清理，mktemp 的随机位数不够（6 位 X）。

**解决**：将模板中的 X 从 6 位增加到 8 位，降低冲突概率。

---

## 自动更新时无法替换运行中的二进制文件

**现象**：macOS 上正在运行的二进制文件无法被覆盖写入。

**解决**：编译到临时路径 → 生成后台 bash 脚本（sleep → cp 替换 → 重启）→ 当前进程退出 → 脚本接力完成替换和重启。

Windows 版同理：下载 .py 到临时目录 → 生成 .bat 脚本（taskkill → copy → start）→ sys.exit() → bat 脚本接力。
