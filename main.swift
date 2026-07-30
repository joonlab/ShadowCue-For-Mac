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
    /// 단축키 녹화 중에는 설정창의 편집 단축키 폴백(⌘C/⌘V 등)이 끼어들면 안 된다.
    static var isRecordingActive = false

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
        HotkeyRecorderField.isRecordingActive = true
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
        HotkeyRecorderField.isRecordingActive = false
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

    // MARK: - Markdown Parser
    private func parseMarkdown(_ markdown: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let lines = markdown.components(separatedBy: "\n")

        let baseParagraphStyle = NSMutableParagraphStyle()
        baseParagraphStyle.lineHeightMultiple = lineHeight
        baseParagraphStyle.alignment = .left

        for (index, line) in lines.enumerated() {
            var processedLine = line
            var lineFont = NSFont.systemFont(ofSize: fontSize, weight: .medium)
            var lineColor = textColor
            var prefix = ""

            // Headers: #, ##, ###, ####, #####, ######
            if line.hasPrefix("###### ") {
                processedLine = String(line.dropFirst(7))
                lineFont = NSFont.systemFont(ofSize: fontSize * 0.85, weight: .semibold)
            } else if line.hasPrefix("##### ") {
                processedLine = String(line.dropFirst(6))
                lineFont = NSFont.systemFont(ofSize: fontSize * 0.9, weight: .semibold)
            } else if line.hasPrefix("#### ") {
                processedLine = String(line.dropFirst(5))
                lineFont = NSFont.systemFont(ofSize: fontSize * 1.0, weight: .bold)
            } else if line.hasPrefix("### ") {
                processedLine = String(line.dropFirst(4))
                lineFont = NSFont.systemFont(ofSize: fontSize * 1.15, weight: .bold)
            } else if line.hasPrefix("## ") {
                processedLine = String(line.dropFirst(3))
                lineFont = NSFont.systemFont(ofSize: fontSize * 1.3, weight: .bold)
            } else if line.hasPrefix("# ") {
                processedLine = String(line.dropFirst(2))
                lineFont = NSFont.systemFont(ofSize: fontSize * 1.5, weight: .bold)
            }
            // Unordered list: - or *
            else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                processedLine = String(line.dropFirst(2))
                prefix = "  •  "
            }
            // Numbered list: 1. 2. 3. etc
            else if let match = line.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                let number = line[line.startIndex..<match.upperBound].dropLast()
                processedLine = String(line[match.upperBound...])
                prefix = "  \(number) "
            }
            // Blockquote: >
            else if line.hasPrefix("> ") {
                processedLine = String(line.dropFirst(2))
                lineColor = textColor.withAlphaComponent(0.7)
                prefix = "┃ "
            }
            // Horizontal rule: --- or ***
            else if line == "---" || line == "***" || line == "___" {
                processedLine = "─────────────────────"
                lineColor = textColor.withAlphaComponent(0.5)
            }

            // Process inline formatting: **bold**, *italic*, ~~strikethrough~~, `code`
            let attributedLine = Self.processInlineMarkdown(processedLine, baseFont: lineFont, baseColor: lineColor)

            // Add prefix if exists
            if !prefix.isEmpty {
                let prefixAttr = NSAttributedString(string: prefix, attributes: [
                    .font: lineFont,
                    .foregroundColor: lineColor,
                    .paragraphStyle: baseParagraphStyle
                ])
                result.append(prefixAttr)
            }

            // Apply paragraph style to the line
            let lineWithStyle = NSMutableAttributedString(attributedString: attributedLine)
            lineWithStyle.addAttribute(.paragraphStyle, value: baseParagraphStyle, range: NSRange(location: 0, length: lineWithStyle.length))

            result.append(lineWithStyle)

            // Add newline except for last line
            if index < lines.count - 1 {
                result.append(NSAttributedString(string: "\n", attributes: [
                    .font: lineFont,
                    .foregroundColor: lineColor
                ]))
            }
        }

        return result
    }

    /// 인스턴스 상태를 쓰지 않는 순수 함수라 static 으로 둔다(--selftest 에서 직접 검사하기 위해).
    static func processInlineMarkdown(_ text: String, baseFont: NSFont, baseColor: NSColor) -> NSAttributedString {
        let result = NSMutableAttributedString()
        var remaining = text

        // 예전 구현은 "종류 우선순위"(굵게 -> 기울임 -> 취소선 -> 코드)로 훑고 매치 앞부분을
        // 평문으로 붙여버려서, 앞에 있던 다른 강조가 통째로 유실됐다.
        //   "*기울임* 그리고 **굵게**" -> 기울임이 별표째 평문으로 출력
        // 그래서 **위치가 가장 앞선 매치**를 고른다. 시작 위치가 같으면 더 긴 매치를 우선해
        // `**`가 `*`에게 잘리지 않게 한다(기존 우선순위가 우연히 지켜주던 규칙을 명시화).
        while !remaining.isEmpty {
            var best: (kind: InlineKind, range: Range<String.Index>)?
            for candidate in Self.inlinePatterns {
                guard let range = remaining.range(of: candidate.pattern, options: .regularExpression) else { continue }
                guard let current = best else { best = (candidate.kind, range); continue }
                let isEarlier = range.lowerBound < current.range.lowerBound
                let isLongerAtSamePosition = range.lowerBound == current.range.lowerBound
                    && range.upperBound > current.range.upperBound
                if isEarlier || isLongerAtSamePosition {
                    best = (candidate.kind, range)
                }
            }

            guard let match = best else { break }

            let beforeText = String(remaining[remaining.startIndex..<match.range.lowerBound])
            if !beforeText.isEmpty {
                result.append(NSAttributedString(string: beforeText, attributes: [
                    .font: baseFont,
                    .foregroundColor: baseColor
                ]))
            }

            let matchedText = String(remaining[match.range])
            let delimiter = match.kind.delimiterLength
            let content = String(matchedText.dropFirst(delimiter).dropLast(delimiter))
            result.append(match.kind.attributedString(content, baseFont: baseFont, baseColor: baseColor))

            remaining = String(remaining[match.range.upperBound...])
        }

        // 남은 평문
        if !remaining.isEmpty {
            result.append(NSAttributedString(string: remaining, attributes: [
                .font: baseFont,
                .foregroundColor: baseColor
            ]))
        }

        return result
    }

    enum InlineKind {
        case code, bold, strike, italic

        var delimiterLength: Int {
            switch self {
            case .code, .italic: return 1
            case .bold, .strike: return 2
            }
        }

        func attributedString(_ content: String, baseFont: NSFont, baseColor: NSColor) -> NSAttributedString {
            switch self {
            case .code:
                let font = NSFont.monospacedSystemFont(ofSize: baseFont.pointSize * 0.9, weight: .regular)
                return NSAttributedString(string: content, attributes: [
                    .font: font,
                    .foregroundColor: baseColor,
                    .backgroundColor: baseColor.withAlphaComponent(0.15)
                ])
            case .bold:
                return NSAttributedString(string: content, attributes: [
                    .font: NSFont.systemFont(ofSize: baseFont.pointSize, weight: .bold),
                    .foregroundColor: baseColor
                ])
            case .strike:
                return NSAttributedString(string: content, attributes: [
                    .font: baseFont,
                    .foregroundColor: baseColor,
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue
                ])
            case .italic:
                let font = NSFont(descriptor: baseFont.fontDescriptor.withSymbolicTraits(.italic),
                                  size: baseFont.pointSize) ?? baseFont
                return NSAttributedString(string: content, attributes: [
                    .font: font,
                    .foregroundColor: baseColor
                ])
            }
        }
    }

    /// 코드 스팬을 먼저 두어 동률일 때 백틱 안의 별표가 보호되게 한다.
    private static let inlinePatterns: [(kind: InlineKind, pattern: String)] = [
        (.code,   #"`(.+?)`"#),
        (.bold,   #"\*\*(.+?)\*\*"#),
        (.strike, #"~~(.+?)~~"#),
        (.italic, #"\*(.+?)\*"#),
    ]

    private func updateTextContent() {
        guard let textView = textView, let scrollView = scrollView else { return }

        let attributedString = parseMarkdown(text)
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
    private var editKeyMonitor: Any?

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

        installEditKeyFallback()
    }

    /// `.accessory` 앱은 메뉴바를 띄우지 않으므로 Edit 메뉴의 키 등가물(⌘C/⌘V/⌘X/⌘A/⌘Z)이
    /// 동작하지 않을 수 있다. 대본을 붙여넣는 창에서 붙여넣기가 안 되면 앱이 무용지물이므로
    /// 설정창이 키 윈도우일 때만 도는 로컬 폴백을 둔다. 메뉴 경로가 살아 있어도 결과는 같다.
    private func installEditKeyFallback() {
        editKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self,
                  let window = self.window, window.isKeyWindow,
                  !HotkeyRecorderField.isRecordingActive else { return event }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard flags == .command || flags == [.command, .shift] else { return event }

            let shift = flags.contains(.shift)
            let selector: Selector?
            switch event.charactersIgnoringModifiers?.lowercased() ?? "" {
            case "c": selector = #selector(NSText.copy(_:))
            case "v": selector = #selector(NSText.paste(_:))
            case "x": selector = #selector(NSText.cut(_:))
            case "a": selector = #selector(NSText.selectAll(_:))
            case "z": selector = shift ? Selector(("redo:")) : Selector(("undo:"))
            default:  selector = nil
            }
            guard let sel = selector else { return event }
            return NSApp.sendAction(sel, to: nil, from: nil) ? nil : event
        }
    }

    deinit {
        if let monitor = editKeyMonitor { NSEvent.removeMonitor(monitor) }
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
    private var lastTick: CFTimeInterval = 0
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

        // 스텔스: 창 제목을 비운다. 화면에는 어차피 안 보이지만(titleVisibility = .hidden),
        // CGWindowListCopyWindowInfo / SCShareableContent 가 title 과 bounds 를 그대로 노출한다.
        window.title = ""
        window.setAccessibilityLabel("프롬프터")
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
# ShadowCue for Mac

**화면 녹화에 보이지 않는** 스텔스 프롬프터

---

## 마크다운 지원

- **굵은 글씨**는 별표 두 개로
- *기울임*은 별표 하나로
- ~~취소선~~은 물결표 두 개로
- `코드`는 백틱으로

---

### 단축키

1. Ctrl+Option+Space - 재생/일시정지
2. Ctrl+Option+D - 클릭스루 모드
3. Ctrl+Option+H - 숨기기/보이기

> 설정 창에서 원하는 텍스트를 입력하세요.
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

    /// 자동 스크롤이 도달할 수 있는 최대 오프셋.
    /// **PrompterView.scrollOffset setter 의 클램프 식과 반드시 문자 그대로 같아야 한다.**
    /// 예전 코드는 여기에 +100 을 더해 정지 조건이 수학적으로 도달 불가였고,
    /// 그래서 대본 끝에 닿아도 타이머가 멈추지 않았다(되감으면 저절로 다시 흘러내려감).
    private var maxScrollOffset: CGFloat {
        max(0, prompterView.calculateTotalHeight() - prompterView.bounds.height)
    }

    func togglePlay() {
        isPlaying.toggle()
        if isPlaying {
            startScrolling()
        } else {
            stopScrolling()
        }
    }

    private func startScrolling() {
        stopScrolling()
        lastTick = CACurrentMediaTime()
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.scrollStep()
        }
        // .common 이어야 창 드래그·슬라이더 드래그·메뉴 트래킹 중에도 계속 흐른다.
        // 기본 .default 모드만 쓰면 그 동안 스크롤이 통째로 멈춘다.
        RunLoop.main.add(timer, forMode: .common)
        scrollTimer = timer
    }

    private func stopScrolling() {
        scrollTimer?.invalidate()
        scrollTimer = nil
    }

    private func scrollStep() {
        let now = CACurrentMediaTime()
        // 슬립에서 깨어난 직후 등 dt 가 클 때 대본이 순간이동하지 않도록 상한을 둔다.
        let dt = min(now - lastTick, 0.25)
        lastTick = now

        let limit = maxScrollOffset
        prompterView.scrollOffset += scrollSpeed * CGFloat(dt)

        if prompterView.scrollOffset >= limit - 0.5 {
            prompterView.scrollOffset = limit
            stopScrolling()
            isPlaying = false
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
        // .accessory 앱은 자동 활성화되지 않으므로 명시적으로 올려야 키 입력을 받는다.
        NSApp.activate(ignoringOtherApps: true)
        settingsController?.showWindow(nil)
        settingsController?.window?.makeKeyAndOrderFront(nil)
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var prompterController: PrompterWindowController!
    var statusItem: NSStatusItem?
    private var stealthObserver: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 스텔스 가드를 창 생성보다 먼저 건다.
        installStealthGuard()

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

    /// 이 앱이 만드는 **모든** 창을 화면 캡처에서 제외한다.
    ///
    /// 창 생성부에서 sharingType 을 거는 것만으로는 부족하다 — 시스템 컬러 패널, NSAlert,
    /// 폰트 패널처럼 우리가 직접 만들지 않는 보조 창이 기본값 `.readOnly` 로 뜨기 때문이다.
    /// `didUpdateNotification` 은 창별로 오므로 O(1) 로 처리한다.
    ///
    /// 한계: NSOpenPanel/NSSavePanel 은 별도 프로세스가 그리므로 여기서 강제할 수 없다.
    /// 상태바 아이템도 메뉴바 소속이라 캡처에 남는다(조작 수단이므로 의도된 노출).
    private func installStealthGuard() {
        NSColorPanel.shared.sharingType = .none
        NSFontPanel.shared.sharingType = .none

        stealthObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didUpdateNotification, object: nil, queue: .main
        ) { note in
            guard let window = note.object as? NSWindow else { return }
            if window.sharingType != .none {
                window.sharingType = .none
            }
        }
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
        // 단축키 문구는 하드코딩하지 않고 현재 설정에서 만든다(기본값을 바꿔도 어긋나지 않도록).
        let playKey = HotkeyManager.shared.hotkeyConfigs[.togglePlay]?.displayString ?? "-"
        alert.informativeText = """
        화면 녹화에 보이지 않는 스텔스 프롬프터

        버전 \(Self.appVersion)

        재생/일시정지: \(playKey)

        제작: 준랩 | JoonLab
        """
        alert.alertStyle = .informational
        // 스텔스: NSAlert 창은 기본 .readOnly 라 그대로 녹화된다.
        alert.window.sharingType = .none
        alert.runModal()
    }

    /// Info.plist 를 단일 출처로 삼는다(코드에 버전을 두 번 적지 않기 위해).
    static var appVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "개발 빌드"
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

// MARK: - Self Test (인라인 마크다운 골든 검사)

/// `ShadowCue --selftest` 로 실행하면 창을 띄우지 않고 파서 결과만 덤프하고 종료한다.
/// 인라인 강조는 눈으로 보기 전에는 회귀를 알아채기 어려워, 렌더 결과를 텍스트로 고정해 둔다.
func runInlineMarkdownSelfTest() {
    let font = NSFont.systemFont(ofSize: 32, weight: .medium)
    let cases = [
        "*기울임* 그리고 **굵게**",
        "`코드` 뒤에 ~~취소선~~",
        "`a**b**c`",
        "**A** 안에 `코드` 있는 **B**",
        "**굵게** 그리고 *기울임*",
        "~~취소선~~ 먼저 **굵게** 나중",
        "**굵은 글씨**는 별표 두 개로",
        "*기울임*은 별표 하나로",
        "~~취소선~~은 물결표 두 개로",
        "`코드`는 백틱으로",
        "강조 없는 평범한 줄",
        "**굵게**만",
    ]
    for source in cases {
        let attributed = PrompterView.processInlineMarkdown(source, baseFont: font, baseColor: .white)
        var parts: [String] = []
        attributed.enumerateAttributes(in: NSRange(location: 0, length: attributed.length)) { attrs, range, _ in
            let piece = (attributed.string as NSString).substring(with: range)
            var kind = "PLAIN"
            if attrs[.strikethroughStyle] != nil {
                kind = "STRIKE"
            } else if let f = attrs[.font] as? NSFont {
                if f.fontDescriptor.symbolicTraits.contains(.italic) { kind = "ITALIC" }
                else if f.fontDescriptor.symbolicTraits.contains(.monoSpace) { kind = "CODE" }
                else if f.fontDescriptor.symbolicTraits.contains(.bold) { kind = "BOLD" }
            }
            parts.append("[\(kind)]\"\(piece)\"")
        }
        print("IN : \(source)")
        print("OUT: \(parts.joined(separator: " "))")
    }
}

// MARK: - Main
if CommandLine.arguments.contains("--selftest") {
    runInlineMarkdownSelfTest()
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// 스텔스: 반드시 .accessory 여야 한다.
// 메뉴바는 NSWindow.sharingType 보호를 받지 않으므로, .regular 이면 앱이 최전면이 되는 순간
// 녹화 영상에 "ShadowCue" 앱 이름과 메뉴가 그대로 찍힌다(창 픽셀만 가리고 이름으로 자백하는 꼴).
// Info.plist 의 LSUIElement 도 true 여야 하며, 둘 중 하나만 바꾸면 나머지가 되돌린다.
app.setActivationPolicy(.accessory)
app.run()
