import AppKit

// Menu-bar-only app (LSUIElement): no Dock icon, everything lives in the
// AppDelegate (event tap, status item, permissions).
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
