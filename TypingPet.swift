// TypingPet for macOS — a desktop pet that reacts to typing.
// Mimics swoonqx/TypingPet (Windows): alternates left/right hand images on each key,
// shows special "pattern" images for chosen keys, bounces, can be dragged.
// Key presses are only used to switch images; nothing is stored or sent anywhere.

import Cocoa
import ApplicationServices

// Physical key codes (layout-independent, so they work with a Thai keyboard too).
let kKeySpace: UInt16 = 49
let kKeyT: UInt16 = 17
let kKey1: UInt16 = 18

final class PetView: NSImageView {
    var onRightClick: ((NSEvent) -> Void)?
    var dragEnabled = true
    private var dragStart: NSPoint?

    override func mouseDown(with event: NSEvent) {
        dragStart = event.locationInWindow
    }

    override func mouseDragged(with event: NSEvent) {
        guard dragEnabled, let start = dragStart, let window = window else { return }
        let now = NSEvent.mouseLocation
        window.setFrameOrigin(NSPoint(x: now.x - start.x, y: now.y - start.y))
    }

    override func mouseUp(with event: NSEvent) {
        dragStart = nil
        UserDefaults.standard.set(NSStringFromPoint(window?.frame.origin ?? .zero), forKey: "origin")
    }

    override func rightMouseDown(with event: NSEvent) {
        onRightClick?(event)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var petView: PetView!
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!

    private var images: [String: NSImage] = [:]
    private var patterns: [UInt16: String] = [kKeySpace: "space", kKeyT: "T", kKey1: "1"]
    private var nextIsLeft = true
    private var idleTimer: Timer?
    private var bounceTimer: Timer?
    private var baseOrigin = NSPoint.zero
    private var monitors: [Any] = []

    private let sizes: [(String, CGFloat)] = [("Small", 200), ("Medium", 300), ("Large", 400), ("Extra Large", 520)]
    private var width: CGFloat {
        get { let w = UserDefaults.standard.double(forKey: "width"); return w > 0 ? w : 300 }
        set { UserDefaults.standard.set(newValue, forKey: "width") }
    }
    private var locked: Bool {
        get { UserDefaults.standard.bool(forKey: "locked") }
        set { UserDefaults.standard.set(newValue, forKey: "locked") }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        loadImages()
        buildWindow()
        buildMenu()
        applyLock()
        requestAccessibilityIfNeeded()
        startMonitoring()
        watchPermission()
    }

    // Keyboard access can be granted while the app is running; when it flips on,
    // re-register the key monitors so typing works without a restart.
    private var wasTrusted = AXIsProcessTrusted()
    private var permissionTimer: Timer?

    private func watchPermission() {
        updateStatus()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let trusted = AXIsProcessTrusted()
            if trusted != self.wasTrusted {
                self.wasTrusted = trusted
                if trusted { self.startMonitoring() }
                self.updateStatus()
            }
        }
    }

    // Diagnostics only: permission state and a count of key events (never which keys).
    private var keyCount = 0
    private func debugLog(_ msg: String) {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/TypingPet.log")
        let line = "\(Date()) \(msg)\n"
        if let h = try? FileHandle(forWritingTo: url) {
            h.seekToEndOfFile(); h.write(line.data(using: .utf8)!); try? h.close()
        } else {
            try? line.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func updateStatus() {
        let trusted = AXIsProcessTrusted()
        debugLog("accessibility=\(trusted) inputMonitoring=\(CGPreflightListenEventAccess()) monitors=\(monitors.count)")
        statusItem.button?.title = trusted ? "🐾" : "🐾⚠️"
        statusMenuItem.title = trusted ? "Keyboard access: ON ✅"
                                       : "Keyboard access: OFF ⚠️ — click to allow"
    }

    private var statusMenuItem = NSMenuItem()

    // MARK: - Images

    private func loadImages() {
        guard let dir = Bundle.main.resourceURL?.appendingPathComponent("images") else { return }
        for name in ["basic", "Left", "Right", "space", "T", "1"] {
            if let img = NSImage(contentsOf: dir.appendingPathComponent("\(name).png")) {
                images[name] = img
            }
        }
    }

    private func show(_ name: String) {
        petView.image = images[name] ?? images["basic"]
    }

    // MARK: - Window

    private func petSize() -> NSSize {
        let base = images["basic"]?.size ?? NSSize(width: 800, height: 500)
        return NSSize(width: width, height: width * base.height / base.width)
    }

    private func buildWindow() {
        let size = petSize()
        window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                          styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        petView = PetView(frame: NSRect(origin: .zero, size: size))
        petView.imageScaling = .scaleProportionallyUpOrDown
        petView.onRightClick = { [weak self] event in
            guard let self = self else { return }
            NSMenu.popUpContextMenu(self.menu, with: event, for: self.petView)
        }
        window.contentView = petView
        show("basic")

        if let saved = UserDefaults.standard.string(forKey: "origin") {
            window.setFrameOrigin(NSPointFromString(saved))
        } else {
            resetPosition()
        }
        window.orderFrontRegardless()
    }

    private func resetPosition() {
        guard let screen = NSScreen.main?.visibleFrame else { return }
        let size = window.frame.size
        window.setFrameOrigin(NSPoint(x: screen.maxX - size.width - 20, y: screen.minY + 20))
        UserDefaults.standard.set(NSStringFromPoint(window.frame.origin), forKey: "origin")
    }

    private func applySize() {
        let size = petSize()
        let origin = window.frame.origin
        window.setFrame(NSRect(origin: origin, size: size), display: true)
        petView.frame = NSRect(origin: .zero, size: size)
    }

    private func applyLock() {
        window.ignoresMouseEvents = locked
        petView.dragEnabled = !locked
    }

    // MARK: - Menu (menu bar icon + right-click on pet)

    private func buildMenu() {
        menu = NSMenu()

        statusMenuItem = NSMenuItem(title: "", action: #selector(openAccessibility), keyEquivalent: "")
        statusMenuItem.target = self
        menu.addItem(statusMenuItem)
        menu.addItem(.separator())

        let sizeItem = NSMenuItem(title: "Size", action: nil, keyEquivalent: "")
        let sizeMenu = NSMenu()
        for (i, (title, w)) in sizes.enumerated() {
            let item = NSMenuItem(title: title, action: #selector(setSize(_:)), keyEquivalent: "")
            item.target = self
            item.tag = i
            item.state = (w == width) ? .on : .off
            sizeMenu.addItem(item)
        }
        sizeItem.submenu = sizeMenu
        menu.addItem(sizeItem)

        let lockItem = NSMenuItem(title: "Lock Position (click-through)", action: #selector(toggleLock(_:)), keyEquivalent: "")
        lockItem.target = self
        lockItem.state = locked ? .on : .off
        menu.addItem(lockItem)

        let resetItem = NSMenuItem(title: "Reset Position", action: #selector(resetPositionAction), keyEquivalent: "")
        resetItem.target = self
        menu.addItem(resetItem)

        let hideItem = NSMenuItem(title: "Show / Hide Pet", action: #selector(toggleVisible), keyEquivalent: "")
        hideItem.target = self
        menu.addItem(hideItem)

        menu.addItem(.separator())
        let permItem = NSMenuItem(title: "Open Accessibility Settings…", action: #selector(openAccessibility), keyEquivalent: "")
        permItem.target = self
        menu.addItem(permItem)

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit Typing Pet", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🐾"
        statusItem.menu = menu
    }

    @objc private func setSize(_ sender: NSMenuItem) {
        width = sizes[sender.tag].1
        sender.menu?.items.forEach { $0.state = ($0 == sender) ? .on : .off }
        applySize()
    }

    @objc private func toggleLock(_ sender: NSMenuItem) {
        locked.toggle()
        sender.state = locked ? .on : .off
        applyLock()
    }

    @objc private func resetPositionAction() { resetPosition() }

    @objc private func toggleVisible() {
        if window.isVisible { window.orderOut(nil) } else { window.orderFrontRegardless() }
    }

    @objc private func openAccessibility() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Keyboard

    private func requestAccessibilityIfNeeded() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
    }

    private func startMonitoring() {
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors.removeAll()
        // Global monitor = keys typed in other apps (needs Accessibility permission).
        if let g = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: { [weak self] e in
            self?.handleKey(e)
        }) { monitors.append(g) }
        // Local monitor = keys typed while the pet itself is focused.
        if let l = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] e in
            self?.handleKey(e); return e
        }) { monitors.append(l) }
    }

    private func handleKey(_ event: NSEvent) {
        if event.isARepeat { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.keyCount += 1
            if self.keyCount <= 3 || self.keyCount % 50 == 0 { self.debugLog("key events received: \(self.keyCount)") }
            if let pattern = self.patterns[event.keyCode] {
                self.show(pattern)
                self.scheduleIdle(after: 0.8)
            } else {
                self.show(self.nextIsLeft ? "Left" : "Right")
                self.nextIsLeft.toggle()
                self.scheduleIdle(after: 0.35)
            }
            self.bounce()
        }
    }

    private func scheduleIdle(after seconds: TimeInterval) {
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            self?.show("basic")
        }
    }

    private func bounce() {
        // Small hop of the image inside the window; the window itself doesn't move.
        bounceTimer?.invalidate()
        let height: CGFloat = 8
        var step = 0
        let steps = 8
        bounceTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            step += 1
            let progress = CGFloat(step) / CGFloat(steps)
            let y = height * sin(progress * .pi)
            self.petView.frame.origin.y = y
            if step >= steps {
                self.petView.frame.origin.y = 0
                t.invalidate()
            }
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // no Dock icon; lives in the menu bar
app.run()
