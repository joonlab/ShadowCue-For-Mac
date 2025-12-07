import Cocoa
import Carbon

// MARK: - Hotkey Configuration
struct HotkeyConfig {
    var keyCode: UInt32
    var modifiers: UInt32

    var modifierString: String {
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        return parts.joined()
    }

    var keyString: String {
        return HotkeyManager.keyCodeToString(keyCode)
    }

    var displayString: String {
        return modifierString + keyString
    }
}

enum HotkeyAction: Int, CaseIterable {
    case togglePlay = 1
    case scrollUp = 2
    case scrollDown = 3
    case toggleVisibility = 4
    case toggleClickThrough = 5
    case speedUp = 6
    case speedDown = 7

    var name: String {
        switch self {
        case .togglePlay: return "재생/일시정지"
        case .scrollUp: return "위로 스크롤"
        case .scrollDown: return "아래로 스크롤"
        case .toggleVisibility: return "숨기기/보이기"
        case .toggleClickThrough: return "드래그 OFF 모드"
        case .speedUp: return "속도 증가"
        case .speedDown: return "속도 감소"
        }
    }

    var defaultKeyCode: UInt32 {
        switch self {
        case .togglePlay: return UInt32(kVK_Space)
        case .scrollUp: return UInt32(kVK_UpArrow)
        case .scrollDown: return UInt32(kVK_DownArrow)
        case .toggleVisibility: return UInt32(kVK_ANSI_H)
        case .toggleClickThrough: return UInt32(kVK_ANSI_D)
        case .speedUp: return UInt32(kVK_ANSI_Period)
        case .speedDown: return UInt32(kVK_ANSI_Comma)
        }
    }
}

// MARK: - Global Hotkey Manager
class HotkeyManager {
    static let shared = HotkeyManager()

    private var eventHandler: EventHandlerRef?
    private var registeredHotKeys: [UInt32: EventHotKeyRef] = [:]

    // Hotkey configurations
    var hotkeyConfigs: [HotkeyAction: HotkeyConfig] = [:]

    // Hotkey actions
    var onTogglePlay: (() -> Void)?
    var onScrollUp: (() -> Void)?
    var onScrollDown: (() -> Void)?
    var onToggleVisibility: (() -> Void)?
    var onToggleClickThrough: (() -> Void)?
    var onSpeedUp: (() -> Void)?
    var onSpeedDown: (() -> Void)?

    init() {
        // Set default hotkey configurations
        let defaultModifiers = UInt32(optionKey | controlKey)
        for action in HotkeyAction.allCases {
            hotkeyConfigs[action] = HotkeyConfig(keyCode: action.defaultKeyCode, modifiers: defaultModifiers)
        }
    }

    func registerHotkeys() {
        // Install event handler if not already installed
        if eventHandler == nil {
            var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

            let handler: EventHandlerUPP = { (nextHandler, theEvent, userData) -> OSStatus in
                var hotKeyID = EventHotKeyID()
                GetEventParameter(theEvent, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)

                DispatchQueue.main.async {
                    switch hotKeyID.id {
                    case 1: HotkeyManager.shared.onTogglePlay?()
                    case 2: HotkeyManager.shared.onScrollUp?()
                    case 3: HotkeyManager.shared.onScrollDown?()
                    case 4: HotkeyManager.shared.onToggleVisibility?()
                    case 5: HotkeyManager.shared.onToggleClickThrough?()
                    case 6: HotkeyManager.shared.onSpeedUp?()
                    case 7: HotkeyManager.shared.onSpeedDown?()
                    default: break
                    }
                }
                return noErr
            }

            InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, nil, &eventHandler)
        }

        // Register all hotkeys
        for action in HotkeyAction.allCases {
            if let config = hotkeyConfigs[action] {
                registerHotkey(id: UInt32(action.rawValue), keyCode: config.keyCode, modifiers: config.modifiers)
            }
        }
    }

    func unregisterAllHotkeys() {
        for (_, hotKeyRef) in registeredHotKeys {
            UnregisterEventHotKey(hotKeyRef)
        }
        registeredHotKeys.removeAll()
    }

    @discardableResult
    func registerHotkey(id: UInt32, keyCode: UInt32, modifiers: UInt32) -> Bool {
        // Unregister existing hotkey with same ID
        if let existingRef = registeredHotKeys[id] {
            UnregisterEventHotKey(existingRef)
            registeredHotKeys.removeValue(forKey: id)
        }

        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x4750524D), id: id)

        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        if status == noErr, let ref = hotKeyRef {
            registeredHotKeys[id] = ref
            return true
        }
        return false
    }

    func updateHotkey(action: HotkeyAction, keyCode: UInt32, modifiers: UInt32) -> Bool {
        let config = HotkeyConfig(keyCode: keyCode, modifiers: modifiers)
        hotkeyConfigs[action] = config

        return registerHotkey(id: UInt32(action.rawValue), keyCode: keyCode, modifiers: modifiers)
    }

    // Convert keyCode to readable string
    static func keyCodeToString(_ keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_Space: return "Space"
        case kVK_Return: return "Return"
        case kVK_Tab: return "Tab"
        case kVK_Delete: return "Delete"
        case kVK_Escape: return "Esc"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_ANSI_Minus: return "-"
        case kVK_ANSI_Equal: return "="
        case kVK_ANSI_LeftBracket: return "["
        case kVK_ANSI_RightBracket: return "]"
        case kVK_ANSI_Backslash: return "\\"
        case kVK_ANSI_Semicolon: return ";"
        case kVK_ANSI_Quote: return "'"
        case kVK_ANSI_Comma: return ","
        case kVK_ANSI_Period: return "."
        case kVK_ANSI_Slash: return "/"
        case kVK_ANSI_Grave: return "`"
        default: return "?"
        }
    }
}

// MARK: - Hotkey Recorder Field
class HotkeyRecorderField: NSTextField {
    var hotkeyAction: HotkeyAction?
    var statusLabel: NSTextField?
    var onHotkeyChanged: ((UInt32, UInt32) -> Bool)?

    private var isRecording = false
    private var recordedKeyCode: UInt32 = 0
    private var recordedModifiers: UInt32 = 0
    private var localMonitor: Any?
    private var globalMonitor: Any?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        isEditable = false
        isSelectable = false
        alignment = .center
        font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        wantsLayer = true
        layer?.cornerRadius = 4
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        backgroundColor = NSColor.controlBackgroundColor
    }

    override func mouseDown(with event: NSEvent) {
        startRecording()
    }

    func startRecording() {
        guard !isRecording else { return }

        isRecording = true
        stringValue = "키 입력 대기중..."
        layer?.borderColor = NSColor.systemBlue.cgColor
        layer?.borderWidth = 2
        backgroundColor = NSColor.selectedControlColor.withAlphaComponent(0.2)
        statusLabel?.stringValue = ""

        // Temporarily unregister all hotkeys to prevent them from firing during recording
        HotkeyManager.shared.unregisterAllHotkeys()

        // Local monitor - catches events when app is active
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self = self, self.isRecording else { return event }

            if event.type == .keyDown {
                self.handleKeyEvent(event)
                return nil  // Consume the event completely
            } else if event.type == .flagsChanged {
                self.handleFlagsChanged(event)
                return nil
            }
            return event
        }

        // Global monitor - catches events even if another app has focus
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self = self, self.isRecording else { return }

            if event.type == .keyDown {
                DispatchQueue.main.async {
                    self.handleKeyEvent(event)
                }
            } else if event.type == .flagsChanged {
                DispatchQueue.main.async {
                    self.handleFlagsChanged(event)
                }
            }
        }

        // Become first responder
        window?.makeFirstResponder(self)
    }

    func stopRecording() {
        guard isRecording else { return }

        isRecording = false
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.borderWidth = 1
        backgroundColor = NSColor.controlBackgroundColor

        // Remove monitors
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }

        // Re-register all hotkeys
        HotkeyManager.shared.registerHotkeys()
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if isRecording {
            handleKeyEvent(event)
        }
    }

    override func flagsChanged(with event: NSEvent) {
        if isRecording {
            handleFlagsChanged(event)
        }
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        // Show current modifiers being pressed
        let modifiers = event.modifierFlags
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }

        if !parts.isEmpty {
            stringValue = parts.joined() + "..."
        } else {
            stringValue = "키 입력 대기중..."
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if isRecording {
            handleKeyEvent(event)
            return true  // Consume the event, prevent system shortcuts
        }
        return super.performKeyEquivalent(with: event)
    }

    private func handleKeyEvent(_ event: NSEvent) {
        guard isRecording else { return }

        let keyCode = UInt32(event.keyCode)

        // Handle Escape to cancel
        if keyCode == UInt32(kVK_Escape) {
            // Restore previous value
            if let action = hotkeyAction, let config = HotkeyManager.shared.hotkeyConfigs[action] {
                stringValue = config.displayString
            } else {
                stringValue = ""
            }
            statusLabel?.stringValue = "취소됨"
            statusLabel?.textColor = .secondaryLabelColor
            stopRecording()
            return
        }

        // Ignore modifier-only keys
        if keyCode == UInt32(kVK_Shift) || keyCode == UInt32(kVK_RightShift) ||
           keyCode == UInt32(kVK_Control) || keyCode == UInt32(kVK_RightControl) ||
           keyCode == UInt32(kVK_Option) || keyCode == UInt32(kVK_RightOption) ||
           keyCode == UInt32(kVK_Command) || keyCode == UInt32(kVK_RightCommand) ||
           keyCode == UInt32(kVK_Function) || keyCode == UInt32(kVK_CapsLock) {
            return
        }

        // Convert NSEvent modifiers to Carbon modifiers
        var carbonModifiers: UInt32 = 0
        if event.modifierFlags.contains(.control) { carbonModifiers |= UInt32(controlKey) }
        if event.modifierFlags.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if event.modifierFlags.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
        if event.modifierFlags.contains(.command) { carbonModifiers |= UInt32(cmdKey) }

        // Require at least one modifier
        if carbonModifiers == 0 {
            statusLabel?.stringValue = "⚠️ 수정자 키 필요 (⌃⌥⇧⌘)"
            statusLabel?.textColor = .systemOrange
            return
        }

        recordedKeyCode = keyCode
        recordedModifiers = carbonModifiers

        // Update display
        let config = HotkeyConfig(keyCode: keyCode, modifiers: carbonModifiers)
        stringValue = config.displayString

        stopRecording()

        // Try to register the hotkey
        if let callback = onHotkeyChanged {
            let success = callback(keyCode, carbonModifiers)
            if success {
                statusLabel?.stringValue = "✓ 적용됨"
                statusLabel?.textColor = .systemGreen
            } else {
                statusLabel?.stringValue = "✗ 중복된 단축키"
                statusLabel?.textColor = .systemRed
            }
        }
    }

    func setHotkey(_ config: HotkeyConfig) {
        stringValue = config.displayString
        recordedKeyCode = config.keyCode
        recordedModifiers = config.modifiers
    }
}

// MARK: - Prompter Window (NSPanel for floating behavior)
class PrompterWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - Prompter View (Optimized with NSTextView)
class PrompterView: NSView {
    private var scrollView: NSScrollView!
    private var textView: NSTextView!
    private var cachedTotalHeight: CGFloat = 0
    private var scrollerHideTimer: Timer?

    var text: String = "" {
        didSet {
            updateTextContent()
        }
    }

    var textColor: NSColor = .white {
        didSet {
            updateTextContent()
        }
    }

    var fontSize: CGFloat = 32 {
        didSet {
            updateTextContent()
        }
    }

    // Computed property to always stay in sync with actual ClipView position
    var scrollOffset: CGFloat {
        get {
            return scrollView?.contentView.bounds.origin.y ?? 0
        }
        set {
            guard let scrollView = scrollView else { return }
            let clipView = scrollView.contentView
            let maxY = max(0, cachedTotalHeight - bounds.height)
            let clampedOffset = min(max(0, newValue), maxY)
            clipView.setBoundsOrigin(NSPoint(x: 0, y: clampedOffset))
            scrollView.reflectScrolledClipView(clipView)
        }
    }

    var lineHeight: CGFloat = 1.5

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        // Create scroll view
        scrollView = NSScrollView(frame: bounds)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.contentView.postsBoundsChangedNotifications = false

        // Configure scroller style and initial hidden state
        scrollView.scrollerStyle = .overlay
        scrollView.verticalScroller?.alphaValue = 0

        // Create text view with proper setup
        textView = NSTextView(frame: NSRect(x: 0, y: 0, width: bounds.width, height: bounds.height))
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: bounds.width - 40, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = false
        textView.textContainerInset = NSSize(width: 20, height: 20)

        textView.isEditable = false
        textView.isSelectable = false
        textView.drawsBackground = false
        textView.backgroundColor = .clear

        scrollView.documentView = textView
        addSubview(scrollView)
    }

    private func updateTextContent() {
        guard let textView = textView, let scrollView = scrollView else { return }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = lineHeight
        paragraphStyle.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .medium),
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        textView.textStorage?.setAttributedString(attributedString)

        // Force layout and calculate height
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)

        if let layoutManager = textView.layoutManager, let textContainer = textView.textContainer {
            let glyphRange = layoutManager.glyphRange(for: textContainer)
            let textRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            cachedTotalHeight = textRect.height + 60

            // Resize text view to fit content
            textView.frame.size.height = max(cachedTotalHeight, bounds.height)
        }

        // Scroll to top after content update
        let clipView = scrollView.contentView
        clipView.setBoundsOrigin(NSPoint(x: 0, y: 0))
        scrollView.reflectScrolledClipView(clipView)
    }

    func calculateTotalHeight() -> CGFloat {
        return cachedTotalHeight
    }

    // Show scroller with fade-in animation, then hide after 3 seconds
    func showScrollerTemporarily() {
        guard let scroller = scrollView?.verticalScroller else { return }

        // Cancel any pending hide timer
        scrollerHideTimer?.invalidate()

        // Fade in scroller
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            scroller.animator().alphaValue = 1.0
        }

        // Schedule hide after 3 seconds
        scrollerHideTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            self?.hideScroller()
        }
    }

    private func hideScroller() {
        guard let scroller = scrollView?.verticalScroller else { return }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            scroller.animator().alphaValue = 0
        }
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        if let textView = textView {
            textView.textContainer?.containerSize = NSSize(width: newSize.width - 40, height: CGFloat.greatestFiniteMagnitude)
            textView.frame.size.width = newSize.width
            updateTextContent()
        }
    }
}

// MARK: - Fine-grained Undo TextView
class FineUndoTextView: NSTextView {
    private var coalescingTimer: Timer?

    override func didChangeText() {
        super.didChangeText()

        // Reset timer on each text change
        coalescingTimer?.invalidate()
        coalescingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            // Use built-in NSTextView method to break undo coalescing
            self?.breakUndoCoalescing()
        }
    }

    override func shouldChangeText(in affectedCharRange: NSRange, replacementString: String?) -> Bool {
        if let replacement = replacementString {
            // Break undo coalescing AFTER space or newline (word/line boundary)
            if replacement == " " || replacement == "\n" {
                // Schedule break after this character is inserted
                DispatchQueue.main.async { [weak self] in
                    self?.breakUndoCoalescing()
                }
            }
        }
        return super.shouldChangeText(in: affectedCharRange, replacementString: replacementString)
    }

    func setupInitialText(_ text: String) {
        // Disable undo registration while setting initial text
        undoManager?.disableUndoRegistration()
        self.string = text
        undoManager?.enableUndoRegistration()
        undoManager?.removeAllActions()
    }
}

// MARK: - Settings Window Controller
class SettingsWindowController: NSWindowController {
    var prompterController: PrompterWindowController?
    var hotkeyRecorders: [HotkeyAction: HotkeyRecorderField] = [:]
    var speedSlider: NSSlider?
    var speedValueLabel: NSTextField?
    var prompterTextView: FineUndoTextView?  // 텍스트 입력창 참조

    convenience init(prompterController: PrompterWindowController) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 750),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "ShadowCue 설정"
        window.center()

        // Make settings window invisible to screen recording too
        window.sharingType = .none

        self.init(window: window)
        self.prompterController = prompterController

        setupUI()
    }

    private func setupUI() {
        guard let window = window, let prompterController = prompterController else { return }

        // Use scroll view for the content
        let scrollView = NSScrollView(frame: window.contentView!.bounds)
        scrollView.hasVerticalScroller = true
        scrollView.autoresizingMask = [.width, .height]

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 450, height: 850))
        contentView.wantsLayer = true

        var yOffset: CGFloat = 800
        let leftMargin: CGFloat = 20
        let labelWidth: CGFloat = 110
        let controlX: CGFloat = 140
        let controlWidth: CGFloat = 280

        // Title
        let titleLabel = NSTextField(labelWithString: "ShadowCue for Mac")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 20)
        titleLabel.frame = NSRect(x: leftMargin, y: yOffset, width: 360, height: 30)
        contentView.addSubview(titleLabel)
        yOffset -= 40

        // Subtitle
        let subtitleLabel = NSTextField(labelWithString: "화면 녹화에 보이지 않는 스텔스 프롬프터")
        subtitleLabel.font = NSFont.systemFont(ofSize: 12)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.frame = NSRect(x: leftMargin, y: yOffset, width: 360, height: 20)
        contentView.addSubview(subtitleLabel)
        yOffset -= 50

        // Text input
        let textLabel = NSTextField(labelWithString: "프롬프터 텍스트:")
        textLabel.frame = NSRect(x: leftMargin, y: yOffset, width: labelWidth, height: 20)
        contentView.addSubview(textLabel)
        yOffset -= 25

        let textScrollView = NSScrollView(frame: NSRect(x: leftMargin, y: yOffset - 80, width: 410, height: 100))
        let textView = FineUndoTextView(frame: textScrollView.bounds)
        textView.isEditable = true
        textView.isRichText = false
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.allowsUndo = true
        textView.autoresizingMask = [.width, .height]
        textScrollView.documentView = textView
        textScrollView.hasVerticalScroller = true
        textScrollView.borderType = .bezelBorder
        contentView.addSubview(textScrollView)

        // Store reference to text view as instance variable
        self.prompterTextView = textView

        // Set text and clear undo history
        textView.setupInitialText(prompterController.prompterView.text)
        yOffset -= 115

        // Apply text button
        let applyTextButton = NSButton(title: "텍스트 적용", target: self, action: #selector(applyText(_:)))
        applyTextButton.frame = NSRect(x: leftMargin, y: yOffset, width: 100, height: 28)
        applyTextButton.bezelStyle = .rounded
        contentView.addSubview(applyTextButton)
        yOffset -= 45

        // === Appearance Section ===
        let appearanceTitle = NSTextField(labelWithString: "외관 설정")
        appearanceTitle.font = NSFont.boldSystemFont(ofSize: 14)
        appearanceTitle.frame = NSRect(x: leftMargin, y: yOffset, width: 200, height: 20)
        contentView.addSubview(appearanceTitle)
        yOffset -= 30

        // Font size
        let fontLabel = NSTextField(labelWithString: "글자 크기:")
        fontLabel.frame = NSRect(x: leftMargin, y: yOffset, width: labelWidth, height: 20)
        contentView.addSubview(fontLabel)

        let fontSlider = NSSlider(value: Double(prompterController.prompterView.fontSize), minValue: 16, maxValue: 72, target: self, action: #selector(fontSizeChanged(_:)))
        fontSlider.frame = NSRect(x: controlX, y: yOffset, width: controlWidth - 60, height: 20)
        contentView.addSubview(fontSlider)

        let fontValueLabel = NSTextField(labelWithString: "\(Int(prompterController.prompterView.fontSize))pt")
        fontValueLabel.frame = NSRect(x: controlX + controlWidth - 55, y: yOffset, width: 50, height: 20)
        fontValueLabel.tag = 1
        contentView.addSubview(fontValueLabel)
        yOffset -= 30

        // Background opacity
        let opacityLabel = NSTextField(labelWithString: "배경 투명도:")
        opacityLabel.frame = NSRect(x: leftMargin, y: yOffset, width: labelWidth, height: 20)
        contentView.addSubview(opacityLabel)

        let opacitySlider = NSSlider(value: Double(prompterController.backgroundOpacity), minValue: 0.1, maxValue: 1.0, target: self, action: #selector(opacityChanged(_:)))
        opacitySlider.frame = NSRect(x: controlX, y: yOffset, width: controlWidth - 60, height: 20)
        contentView.addSubview(opacitySlider)

        let opacityValueLabel = NSTextField(labelWithString: "\(Int(prompterController.backgroundOpacity * 100))%")
        opacityValueLabel.frame = NSRect(x: controlX + controlWidth - 55, y: yOffset, width: 50, height: 20)
        opacityValueLabel.tag = 2
        contentView.addSubview(opacityValueLabel)
        yOffset -= 30

        // Scroll speed
        let speedLabel = NSTextField(labelWithString: "스크롤 속도:")
        speedLabel.frame = NSRect(x: leftMargin, y: yOffset, width: labelWidth, height: 20)
        contentView.addSubview(speedLabel)

        let slider = NSSlider(value: Double(prompterController.scrollSpeed), minValue: 10, maxValue: 200, target: self, action: #selector(speedChanged(_:)))
        slider.frame = NSRect(x: controlX, y: yOffset, width: controlWidth - 60, height: 20)
        contentView.addSubview(slider)
        self.speedSlider = slider

        let valueLabel = NSTextField(labelWithString: "\(Int(prompterController.scrollSpeed))")
        valueLabel.frame = NSRect(x: controlX + controlWidth - 55, y: yOffset, width: 50, height: 20)
        valueLabel.tag = 3
        contentView.addSubview(valueLabel)
        self.speedValueLabel = valueLabel
        yOffset -= 35

        // Color selection
        let textColorLabel = NSTextField(labelWithString: "글자 색상:")
        textColorLabel.frame = NSRect(x: leftMargin, y: yOffset, width: labelWidth, height: 20)
        contentView.addSubview(textColorLabel)

        let textColorWell = NSColorWell(frame: NSRect(x: controlX, y: yOffset - 5, width: 50, height: 30))
        textColorWell.color = prompterController.prompterView.textColor
        textColorWell.target = self
        textColorWell.action = #selector(textColorChanged(_:))
        contentView.addSubview(textColorWell)

        let bgColorLabel = NSTextField(labelWithString: "배경 색상:")
        bgColorLabel.frame = NSRect(x: controlX + 100, y: yOffset, width: 70, height: 20)
        contentView.addSubview(bgColorLabel)

        let bgColorWell = NSColorWell(frame: NSRect(x: controlX + 175, y: yOffset - 5, width: 50, height: 30))
        bgColorWell.color = prompterController.backgroundColor
        bgColorWell.target = self
        bgColorWell.action = #selector(bgColorChanged(_:))
        contentView.addSubview(bgColorWell)
        yOffset -= 55

        // === Hotkey Section ===
        let hotkeyTitle = NSTextField(labelWithString: "단축키 설정")
        hotkeyTitle.font = NSFont.boldSystemFont(ofSize: 14)
        hotkeyTitle.frame = NSRect(x: leftMargin, y: yOffset, width: 200, height: 20)
        contentView.addSubview(hotkeyTitle)
        yOffset -= 22

        let hotkeySubtitle = NSTextField(labelWithString: "클릭하여 새 단축키 입력 (수정자 키 + 일반 키)")
        hotkeySubtitle.font = NSFont.systemFont(ofSize: 11)
        hotkeySubtitle.textColor = .secondaryLabelColor
        hotkeySubtitle.frame = NSRect(x: leftMargin, y: yOffset, width: 360, height: 16)
        contentView.addSubview(hotkeySubtitle)
        yOffset -= 25

        // Create hotkey recorder for each action
        for action in HotkeyAction.allCases {
            let actionLabel = NSTextField(labelWithString: action.name + ":")
            actionLabel.frame = NSRect(x: leftMargin, y: yOffset, width: labelWidth, height: 20)
            contentView.addSubview(actionLabel)

            let recorder = HotkeyRecorderField(frame: NSRect(x: controlX, y: yOffset - 2, width: 120, height: 24))
            recorder.hotkeyAction = action

            // Set current hotkey
            if let config = HotkeyManager.shared.hotkeyConfigs[action] {
                recorder.setHotkey(config)
            }

            // Status label
            let statusLabel = NSTextField(labelWithString: "")
            statusLabel.frame = NSRect(x: controlX + 130, y: yOffset, width: 150, height: 20)
            statusLabel.font = NSFont.systemFont(ofSize: 11)
            statusLabel.isBezeled = false
            statusLabel.drawsBackground = false
            statusLabel.isEditable = false
            contentView.addSubview(statusLabel)

            recorder.statusLabel = statusLabel
            recorder.onHotkeyChanged = { [weak self] keyCode, modifiers in
                return self?.handleHotkeyChange(action: action, keyCode: keyCode, modifiers: modifiers) ?? false
            }

            contentView.addSubview(recorder)
            hotkeyRecorders[action] = recorder

            yOffset -= 32
        }

        yOffset -= 10

        // Reset hotkeys button
        let resetButton = NSButton(title: "단축키 초기화", target: self, action: #selector(resetHotkeys(_:)))
        resetButton.frame = NSRect(x: leftMargin, y: yOffset, width: 120, height: 24)
        resetButton.bezelStyle = .rounded
        contentView.addSubview(resetButton)

        // Set content view
        scrollView.documentView = contentView
        window.contentView = scrollView

        // Scroll to top
        if let docView = scrollView.documentView {
            docView.scroll(NSPoint(x: 0, y: docView.bounds.height))
        }
    }

    private func handleHotkeyChange(action: HotkeyAction, keyCode: UInt32, modifiers: UInt32) -> Bool {
        // Check for duplicates with other actions in our app
        for (otherAction, config) in HotkeyManager.shared.hotkeyConfigs {
            if otherAction != action && config.keyCode == keyCode && config.modifiers == modifiers {
                // Duplicate within our app
                return false
            }
        }

        // Try to register the hotkey (will fail if system-wide duplicate)
        let success = HotkeyManager.shared.updateHotkey(action: action, keyCode: keyCode, modifiers: modifiers)
        return success
    }

    @objc func resetHotkeys(_ sender: NSButton) {
        let defaultModifiers = UInt32(optionKey | controlKey)

        for action in HotkeyAction.allCases {
            let defaultConfig = HotkeyConfig(keyCode: action.defaultKeyCode, modifiers: defaultModifiers)
            HotkeyManager.shared.hotkeyConfigs[action] = defaultConfig
            HotkeyManager.shared.registerHotkey(id: UInt32(action.rawValue), keyCode: action.defaultKeyCode, modifiers: defaultModifiers)

            if let recorder = hotkeyRecorders[action] {
                recorder.setHotkey(defaultConfig)
                recorder.statusLabel?.stringValue = "✓ 초기화됨"
                recorder.statusLabel?.textColor = .systemGreen
            }
        }
    }

    @objc func applyText(_ sender: NSButton) {
        guard let textView = prompterTextView else { return }
        prompterController?.prompterView.text = textView.string
    }

    @objc func fontSizeChanged(_ sender: NSSlider) {
        prompterController?.prompterView.fontSize = CGFloat(sender.doubleValue)

        if let label = window?.contentView?.viewWithTag(1) as? NSTextField {
            label.stringValue = "\(Int(sender.doubleValue))pt"
        }
    }

    @objc func opacityChanged(_ sender: NSSlider) {
        prompterController?.backgroundOpacity = CGFloat(sender.doubleValue)
        prompterController?.updateBackgroundColor()

        if let label = window?.contentView?.viewWithTag(2) as? NSTextField {
            label.stringValue = "\(Int(sender.doubleValue * 100))%"
        }
    }

    @objc func speedChanged(_ sender: NSSlider) {
        prompterController?.scrollSpeed = CGFloat(sender.doubleValue)

        if let label = window?.contentView?.viewWithTag(3) as? NSTextField {
            label.stringValue = "\(Int(sender.doubleValue))"
        }
    }

    @objc func textColorChanged(_ sender: NSColorWell) {
        prompterController?.prompterView.textColor = sender.color
    }

    @objc func bgColorChanged(_ sender: NSColorWell) {
        prompterController?.backgroundColor = sender.color
        prompterController?.updateBackgroundColor()
    }

    func updateSpeedDisplay(_ speed: CGFloat) {
        speedSlider?.doubleValue = Double(speed)
        speedValueLabel?.stringValue = "\(Int(speed))"
    }
}

// MARK: - Prompter Window Controller
class PrompterWindowController: NSWindowController {
    var prompterView: PrompterView!
    var scrollTimer: Timer?
    var isPlaying = false
    var scrollSpeed: CGFloat = 50  // pixels per second
    var isClickThrough = false
    var backgroundColor: NSColor = .black
    var backgroundOpacity: CGFloat = 0.7

    var settingsController: SettingsWindowController?

    convenience init() {
        // Create panel that is invisible to screen capture
        let window = PrompterWindow(
            contentRect: NSRect(x: 100, y: 100, width: 600, height: 400),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false
        )

        // KEY: This makes the window invisible to screen recording/sharing
        window.sharingType = .none

        window.title = "ShadowCue"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true

        // Panel-specific settings for floating above everything
        window.isFloatingPanel = true
        window.becomesKeyOnlyIfNeeded = true
        window.worksWhenModal = true

        // Always on top - even above fullscreen apps and across all desktops
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1000)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        window.hidesOnDeactivate = false
        window.canHide = false
        window.isExcludedFromWindowsMenu = true

        window.isOpaque = false
        window.backgroundColor = NSColor.black.withAlphaComponent(0.7)

        self.init(window: window)

        setupPrompterView()
        setupScrollWheel()
    }

    private func setupPrompterView() {
        guard let window = window else { return }

        prompterView = PrompterView(frame: window.contentView!.bounds)
        prompterView.autoresizingMask = [.width, .height]
        prompterView.text = """
ShadowCue for Mac

이 텍스트는 화면 녹화나 화면 공유에 보이지 않습니다.

설정 창에서 원하는 텍스트를 입력하세요.

Ctrl+Option+Space로 자동 스크롤을 시작/중지할 수 있습니다.

Ctrl+Option+D로 클릭스루 모드를 전환할 수 있습니다.
(이 모드에서는 프롬프터 뒤의 내용을 클릭할 수 있습니다)
"""
        window.contentView?.addSubview(prompterView)
    }

    private func setupScrollWheel() {
        // Local monitor for when app is active
        NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self = self else { return event }
            self.handleScrollEvent(event)
            return event
        }

        // Global monitor for when app is NOT active - detect scroll over prompter area
        NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self = self else { return }
            self.handleScrollEvent(event)
        }
    }

    private func handleScrollEvent(_ event: NSEvent) {
        guard let window = self.window, window.isVisible, !isClickThrough else { return }

        // Get mouse location in screen coordinates
        let mouseLocation = NSEvent.mouseLocation

        // Check if mouse is within the prompter window frame
        if window.frame.contains(mouseLocation) {
            // Use higher multiplier for better trackpad sensitivity
            let delta = event.scrollingDeltaY * 3
            prompterView.scrollOffset -= delta
            prompterView.scrollOffset = max(0, prompterView.scrollOffset)

            // Show scroller temporarily on scroll activity
            prompterView.showScrollerTemporarily()
        }
    }

    func togglePlay() {
        isPlaying.toggle()

        if isPlaying {
            scrollTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.prompterView.scrollOffset += self.scrollSpeed / 60.0

                let maxScroll = self.prompterView.calculateTotalHeight() - self.prompterView.bounds.height + 100
                if self.prompterView.scrollOffset > maxScroll {
                    self.prompterView.scrollOffset = maxScroll
                    self.isPlaying = false
                    self.scrollTimer?.invalidate()
                }
            }
        } else {
            scrollTimer?.invalidate()
        }
    }

    func scrollUp() {
        prompterView.scrollOffset -= 50
        prompterView.scrollOffset = max(0, prompterView.scrollOffset)
    }

    func scrollDown() {
        prompterView.scrollOffset += 50
    }

    func toggleVisibility() {
        guard let window = window else { return }
        if window.isVisible {
            window.orderOut(nil)
        } else {
            window.orderFront(nil)
        }
    }

    func toggleClickThrough() {
        isClickThrough.toggle()
        window?.ignoresMouseEvents = isClickThrough

        // Visual feedback
        if isClickThrough {
            window?.backgroundColor = backgroundColor.withAlphaComponent(backgroundOpacity * 0.5)
        } else {
            window?.backgroundColor = backgroundColor.withAlphaComponent(backgroundOpacity)
        }
    }

    func speedUp() {
        scrollSpeed = min(200, scrollSpeed + 20)
        settingsController?.updateSpeedDisplay(scrollSpeed)
    }

    func speedDown() {
        scrollSpeed = max(10, scrollSpeed - 20)
        settingsController?.updateSpeedDisplay(scrollSpeed)
    }

    func updateBackgroundColor() {
        window?.backgroundColor = backgroundColor.withAlphaComponent(backgroundOpacity)
    }

    func showSettings() {
        if settingsController == nil {
            settingsController = SettingsWindowController(prompterController: self)
        }
        settingsController?.showWindow(nil)
        settingsController?.window?.makeKeyAndOrderFront(nil)
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var prompterController: PrompterWindowController!
    var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create prompter window
        prompterController = PrompterWindowController()
        prompterController.showWindow(nil)

        // Setup global hotkeys
        setupHotkeys()

        // Create menu bar item
        setupStatusItem()

        // Setup main menu
        setupMainMenu()
    }

    private func setupHotkeys() {
        let hotkeyManager = HotkeyManager.shared

        hotkeyManager.onTogglePlay = { [weak self] in
            self?.prompterController.togglePlay()
        }

        hotkeyManager.onScrollUp = { [weak self] in
            self?.prompterController.scrollUp()
        }

        hotkeyManager.onScrollDown = { [weak self] in
            self?.prompterController.scrollDown()
        }

        hotkeyManager.onToggleVisibility = { [weak self] in
            self?.prompterController.toggleVisibility()
        }

        hotkeyManager.onToggleClickThrough = { [weak self] in
            self?.prompterController.toggleClickThrough()
        }

        hotkeyManager.onSpeedUp = { [weak self] in
            self?.prompterController.speedUp()
        }

        hotkeyManager.onSpeedDown = { [weak self] in
            self?.prompterController.speedDown()
        }

        hotkeyManager.registerHotkeys()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "☷"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "프롬프터 보이기/숨기기", action: #selector(togglePrompter), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "재생/일시정지", action: #selector(togglePlay), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "클릭스루 모드", action: #selector(toggleClickThrough), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "설정...", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "업데이트 확인...", action: #selector(checkForUpdates), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // App menu
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "ShadowCue 정보", action: #selector(showAbout), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem(title: "업데이트 확인...", action: #selector(checkForUpdates), keyEquivalent: "u"))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "설정...", action: #selector(showSettings), keyEquivalent: ","))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "ShadowCue 종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // Edit menu (required for copy/paste/select all to work)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))

        let editMenuItem = NSMenuItem()
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        // Window menu
        let windowMenu = NSMenu(title: "윈도우")
        windowMenu.addItem(NSMenuItem(title: "프롬프터 보이기", action: #selector(showPrompter), keyEquivalent: "1"))
        windowMenu.addItem(NSMenuItem(title: "설정 열기", action: #selector(showSettings), keyEquivalent: "2"))

        let windowMenuItem = NSMenuItem()
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        NSApp.mainMenu = mainMenu
    }

    @objc func togglePrompter() {
        prompterController.toggleVisibility()
    }

    @objc func showPrompter() {
        prompterController.window?.orderFront(nil)
    }

    @objc func togglePlay() {
        prompterController.togglePlay()
    }

    @objc func toggleClickThrough() {
        prompterController.toggleClickThrough()
    }

    @objc func showSettings() {
        prompterController.showSettings()
    }

    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "ShadowCue for Mac"
        alert.informativeText = "화면 녹화에 보이지 않는 스텔스 프롬프터\n\n버전 1.0\n\n단축키: Ctrl+Option+Space (재생/일시정지)\n\n제작: 준랩 | JoonLab"
        alert.alertStyle = .informational
        alert.runModal()
    }

    @objc func checkForUpdates() {
        if let url = URL(string: "https://github.com/joonlab/ShadowCue-For-Mac/releases/latest") {
            NSWorkspace.shared.open(url)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}

// MARK: - Main
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
app.run()
