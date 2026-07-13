import AppKit
import ApplicationServices

// Private-but-stable APIs, the same ones AltTab relies on.
//
// The public accessibility API (kAXWindowsAttribute) only returns windows in
// the *current* Space. To reach windows in other Spaces we construct AX
// elements directly from a "remote token" (pid + element id) and keep the
// ones that resolve to real windows.

@_silgen_name("_AXUIElementCreateWithRemoteToken")
func _AXUIElementCreateWithRemoteToken(_ token: CFData) -> Unmanaged<AXUIElement>?

/// Maps an AX window element to its CGWindowID.
@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ windowID: inout CGWindowID) -> AXError

enum PrivateAX {
    static func remoteTokenElement(pid: pid_t, axId: Int32) -> AXUIElement? {
        var token = Data(count: 20)
        token.replaceSubrange(0..<4, with: withUnsafeBytes(of: pid) { Data($0) })
        token.replaceSubrange(4..<8, with: withUnsafeBytes(of: Int32(0)) { Data($0) })
        token.replaceSubrange(8..<12, with: withUnsafeBytes(of: Int32(0x636f636f)) { Data($0) })
        token.replaceSubrange(12..<16, with: withUnsafeBytes(of: axId) { Data($0) })
        token.replaceSubrange(16..<20, with: withUnsafeBytes(of: Int32(0)) { Data($0) })
        return _AXUIElementCreateWithRemoteToken(token as CFData)?.takeRetainedValue()
    }

    static func windowID(of element: AXUIElement) -> CGWindowID? {
        var wid: CGWindowID = 0
        guard _AXUIElementGetWindow(element, &wid) == .success, wid != 0 else { return nil }
        return wid
    }
}
