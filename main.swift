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
    // ⚠️ 새 액션을 추가할 때는 rawValue 가 곧 hotkey ID 이므로 **4곳을 함께** 고쳐야 한다:
    //    이 enum / HotkeyManager 의 콜백 프로퍼티 / 이벤트 핸들러 switch / AppDelegate 배선.
    //    하나만 빠지면 등록은 되는데 아무 일도 안 일어나 원인을 찾기 어렵다.
    case scrollToTop = 8
    case previousSection = 9
    case nextSection = 10
    case pasteClipboard = 11
    case cheatSheet = 12

    var name: String {
        switch self {
        case .togglePlay: return "재생/일시정지"
        case .scrollUp: return "위로 스크롤"
        case .scrollDown: return "아래로 스크롤"
        case .toggleVisibility: return "숨기기/보이기"
        case .toggleClickThrough: return "클릭 통과"
        case .speedUp: return "속도 증가"
        case .speedDown: return "속도 감소"
        case .scrollToTop: return "처음으로"
        case .previousSection: return "이전 섹션"
        case .nextSection: return "다음 섹션"
        case .pasteClipboard: return "클립보드를 대본으로"
        case .cheatSheet: return "단축키 보기"
        }
    }

    /// 기본 수정자. 한 곳에서만 정의해 초기화·기본값 표시가 어긋나지 않게 한다.
    static let defaultModifiers = UInt32(optionKey | controlKey)

    /// README·데모 대본·정보창에 같은 단축키를 세 번 하드코딩하지 않기 위한 표시 문자열.
    var defaultDisplayString: String {
        HotkeyConfig(keyCode: defaultKeyCode, modifiers: HotkeyAction.defaultModifiers).displayString
    }

    var defaultKeyCode: UInt32 {
        switch self {
        // ⌃⌥Space 를 쓰면 안 된다 — 한국어 로케일 macOS 의 **공장 기본값**이
        // "입력 메뉴에서 다음 소스 선택"(symbolic hotkey id 61, [32, 49, 786432])으로
        // 이 조합을 이미 켜 둔 채 출고된다. 그 맥에서는 재생 대신 한/영만 전환된다.
        // (en 로케일과 재매핑한 맥에서는 재현되지 않아 발견이 늦었다)
        case .togglePlay: return UInt32(kVK_Return)
        case .scrollUp: return UInt32(kVK_UpArrow)
        case .scrollDown: return UInt32(kVK_DownArrow)
        case .toggleVisibility: return UInt32(kVK_ANSI_H)
        case .toggleClickThrough: return UInt32(kVK_ANSI_D)
        case .speedUp: return UInt32(kVK_ANSI_Period)
        case .speedDown: return UInt32(kVK_ANSI_Comma)
        case .scrollToTop: return UInt32(kVK_ANSI_R)
        case .previousSection: return UInt32(kVK_ANSI_LeftBracket)
        case .nextSection: return UInt32(kVK_ANSI_RightBracket)
        case .pasteClipboard: return UInt32(kVK_ANSI_V)
        case .cheatSheet: return UInt32(kVK_ANSI_Slash)
        }
    }
}

// MARK: - Persistence

/// NSColor 를 저장 가능한 sRGB 성분으로 바꾼다.
///
/// `NSColor.redComponent` 를 바로 부르면 안 된다 — 기본값인 `.white`/`.black` 은
/// `_NSTaggedPointerColor` 라서 성분 접근이 NSException 을 던지고 **프로세스가 즉사**한다.
/// 반드시 `usingColorSpace(.sRGB)` 를 거친다(패턴 색 등 변환 불가한 색은 nil).
///
/// NSKeyedArchiver 를 쓰지 않는 이유: 색 하나에 수 KB 인 데다, `.labelColor` 같은 다이내믹 색이
/// 다이내믹한 채로 복원돼 **다크모드 전환 시 촬영 중에 글자색이 바뀐다**.
struct RGBA: Codable, Equatable {
    var r: Double
    var g: Double
    var b: Double
    var a: Double

    init(r: Double, g: Double, b: Double, a: Double) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    init?(_ color: NSColor) {
        guard let converted = color.usingColorSpace(.sRGB) else { return nil }
        self.init(r: Double(converted.redComponent),
                  g: Double(converted.greenComponent),
                  b: Double(converted.blueComponent),
                  a: Double(converted.alphaComponent))
    }

    var nsColor: NSColor {
        NSColor(srgbRed: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(a))
    }

    static let white = RGBA(r: 1, g: 1, b: 1, a: 1)
    static let black = RGBA(r: 0, g: 0, b: 0, a: 1)
}

/// 단축키는 딕셔너리가 아니라 배열로 저장한다.
/// `[HotkeyAction: Config]` 를 JSON 으로 넣으면 Int 키가 평면 교대 배열로 인코딩돼 읽기 어렵다.
struct HotkeyRecord: Codable, Equatable {
    var action: Int
    var keyCode: UInt32
    var modifiers: UInt32
}

struct Settings: Codable, Equatable {
    var schema: Int = 1
    var fontSize: Double = 32
    var lineHeight: Double = 1.5
    var textColor: RGBA = .white
    var backgroundColor: RGBA = .black
    var backgroundOpacity: Double = 0.7
    var scrollSpeed: Double = 50
    var windowFrame: [Double]?
    var hotkeys: [HotkeyRecord] = []
    var activeScriptID: String?
    /// 뱃지가 상시 표시되므로 복원해도 "왜 클릭이 안 되지" 상태에 빠지지 않는다.
    var isClickThrough: Bool = false

    // 타이포그래피
    var fontName: String?          // nil = 시스템 폰트
    var kern: Double = 0           // 자간
    var maxLineWidth: Double = 0   // 0 = 창 너비까지
    // 읽기 보조
    var showFocusBand: Bool = true
    var countdownEnabled: Bool = false
    // 유리 프롬프터(반사 리그)용 반전
    var mirrorHorizontal: Bool = false
    var mirrorVertical: Bool = false

    init() {}

    /// **전방호환 디코더 — 자동 합성에 맡기면 안 된다.**
    /// 합성된 `init(from:)` 은 프로퍼티 기본값을 쓰지 않아서, 다음 버전에서 필드를 하나만 추가해도
    /// 기존 사용자의 블롭이 `keyNotFound` 로 **통째로** 디코드 실패한다(= 설정 전체 초기화).
    /// 필드마다 개별 폴백을 두어 모르는/깨진 값만 버린다.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = Settings()

        func value<T: Decodable>(_ key: CodingKeys, _ defaultValue: T) -> T {
            ((try? container.decodeIfPresent(T.self, forKey: key)) ?? nil) ?? defaultValue
        }

        schema            = value(.schema, fallback.schema)
        fontSize          = value(.fontSize, fallback.fontSize)
        lineHeight        = value(.lineHeight, fallback.lineHeight)
        textColor         = value(.textColor, fallback.textColor)
        backgroundColor   = value(.backgroundColor, fallback.backgroundColor)
        backgroundOpacity = value(.backgroundOpacity, fallback.backgroundOpacity)
        scrollSpeed       = value(.scrollSpeed, fallback.scrollSpeed)
        windowFrame       = value(.windowFrame, fallback.windowFrame)
        hotkeys           = value(.hotkeys, fallback.hotkeys)
        activeScriptID    = value(.activeScriptID, fallback.activeScriptID)
        isClickThrough    = value(.isClickThrough, fallback.isClickThrough)
        fontName          = value(.fontName, fallback.fontName)
        kern              = value(.kern, fallback.kern)
        maxLineWidth      = value(.maxLineWidth, fallback.maxLineWidth)
        showFocusBand     = value(.showFocusBand, fallback.showFocusBand)
        countdownEnabled  = value(.countdownEnabled, fallback.countdownEnabled)
        mirrorHorizontal  = value(.mirrorHorizontal, fallback.mirrorHorizontal)
        mirrorVertical    = value(.mirrorVertical, fallback.mirrorVertical)
    }
}

final class SettingsStore {
    static let shared = SettingsStore()

    /// 번들 밖 임시 바이너리(`swiftc -o /tmp/x`)는 bundleIdentifier 가 nil 이라 기본 도메인이
    /// 엉뚱한 곳이 된다. 도메인을 고정해야 "저장이 안 된다"는 오진을 피한다.
    /// (SHADOWCUE_DEFAULTS_SUITE 는 셀프테스트가 실제 환경설정을 건드리지 않게 하는 훅)
    private let defaults: UserDefaults = {
        let suite = ProcessInfo.processInfo.environment["SHADOWCUE_DEFAULTS_SUITE"] ?? "com.shadowcue.mac"
        return UserDefaults(suiteName: suite) ?? .standard
    }()
    private let storageKey = "settings.v1"
    private var pendingSave: DispatchWorkItem?

    private(set) var isFirstLaunch = false

    var settings: Settings {
        didSet {
            // 이 Equatable 가드 덕분에 복원 시 didSet 이 같은 값을 되써도 재저장이 안 일어난다.
            guard settings != oldValue else { return }
            scheduleSave()
        }
    }

    private init() {
        // `register(defaults:)` 는 쓰지 않는다 — 등록한 키가 object(forKey:) 에 잡혀
        // 최초 실행 판별이 깨진다.
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(Settings.self, from: data) {
            settings = decoded
        } else {
            settings = Settings()
            isFirstLaunch = true
        }
    }

    func update(_ mutate: (inout Settings) -> Void) {
        var copy = settings
        mutate(&copy)
        settings = copy
    }

    /// 슬라이더 드래그마다 디스크에 쓰지 않도록 묶는다.
    /// Timer 가 아니라 DispatchWorkItem 인 이유: 드래그 중에는 런루프가 `.eventTracking` 이라
    /// 기본 모드 Timer 가 아예 돌지 않는다.
    private func scheduleSave() {
        pendingSave?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.writeNow() }
        pendingSave = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: item)
    }

    func flushNow() {
        pendingSave?.cancel()
        pendingSave = nil
        writeNow()
    }

    private func writeNow() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: storageKey)
    }

    // MARK: 이식·초기화

    /// 사람이 읽을 수 있는 형태로 내보낸다(노트북 <-> 데스크톱 이식용).
    func exportData() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(settings)
    }

    /// 가져오기. 전방호환 디코더를 그대로 타므로 낯선/깨진 필드는 각각 기본값으로 떨어진다.
    @discardableResult
    func importData(_ data: Data) -> Bool {
        guard let decoded = try? JSONDecoder().decode(Settings.self, from: data) else { return false }
        settings = decoded
        flushNow()
        return true
    }

    /// 대본은 건드리지 않는다 — 설정만 되돌린다(activeScriptID 는 유지).
    func resetAll() {
        var fresh = Settings()
        fresh.activeScriptID = settings.activeScriptID
        settings = fresh
        flushNow()
    }
}

// MARK: - Script Storage

struct ScriptMeta: Codable, Equatable {
    var id: String
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var lastScrollOffset: Double = 0
}

struct ScriptLibrary: Codable, Equatable {
    var version: Int = 1
    var scripts: [ScriptMeta] = []
}

/// 대본은 설정이 아니라 **문서**다. 그래서 UserDefaults 가 아니라 파일로 둔다.
/// (성능 문제가 아니다 — `defaults delete` 한 번에 강의 대본이 함께 증발하면 안 되고,
///  Finder·Obsidian·git 으로 직접 열어보고 백업할 수 있어야 한다)
///
/// ~/Library/Application Support/ShadowCue/
///   ├── library.json        대본 목록(제목·수정시각·마지막 위치)
///   └── scripts/<uuid>.md   본문 (+ <uuid>.md.bak 직전 세대 1개)
///
/// UI 는 아직 단일 대본이지만 스토리지는 처음부터 N개를 표현한다 — 나중에 라이브러리를
/// 붙일 때 마이그레이션이 필요 없도록.
enum ScriptStore {
    static let demoScript = """
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

1. \(HotkeyAction.togglePlay.defaultDisplayString) - 재생/일시정지
2. \(HotkeyAction.toggleClickThrough.defaultDisplayString) - 클릭스루 모드
3. \(HotkeyAction.toggleVisibility.defaultDisplayString) - 숨기기/보이기

> 설정 창에서 원하는 텍스트를 입력하세요. 입력하면 바로 반영됩니다.
"""

    static var baseURL: URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return root.appendingPathComponent("ShadowCue", isDirectory: true)
    }
    static var scriptsURL: URL { baseURL.appendingPathComponent("scripts", isDirectory: true) }
    static var libraryURL: URL { baseURL.appendingPathComponent("library.json") }

    static func prepare() {
        try? FileManager.default.createDirectory(at: scriptsURL, withIntermediateDirectories: true)
    }

    static func url(for id: String) -> URL {
        scriptsURL.appendingPathComponent("\(id).md")
    }

    static func exists(id: String) -> Bool {
        FileManager.default.fileExists(atPath: url(for: id).path)
    }

    static func read(id: String) -> String? {
        try? String(contentsOf: url(for: id), encoding: .utf8)
    }

    /// 원자적으로 쓰고 직전 세대를 .bak 으로 한 개 남긴다.
    @discardableResult
    static func write(id: String, text: String) -> Bool {
        prepare()
        let target = url(for: id)
        if FileManager.default.fileExists(atPath: target.path) {
            let backup = target.appendingPathExtension("bak")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.copyItem(at: target, to: backup)
        }
        do {
            try text.write(to: target, atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }

    static func loadLibrary() -> ScriptLibrary {
        guard let data = try? Data(contentsOf: libraryURL),
              let library = try? JSONDecoder().decode(ScriptLibrary.self, from: data) else {
            return ScriptLibrary()
        }
        return library
    }

    static func saveLibrary(_ library: ScriptLibrary) {
        prepare()
        guard let data = try? JSONEncoder().encode(library) else { return }
        try? data.write(to: libraryURL, options: .atomic)
    }

    /// 어디까지 읽었는지 기억한다(재실행 후 이어읽기).
    static func saveScrollOffset(id: String, offset: Double) {
        var library = loadLibrary()
        guard let index = library.scripts.firstIndex(where: { $0.id == id }) else { return }
        guard abs(library.scripts[index].lastScrollOffset - offset) > 1 else { return }
        library.scripts[index].lastScrollOffset = offset
        saveLibrary(library)
    }

    static func scrollOffset(id: String) -> Double {
        loadLibrary().scripts.first(where: { $0.id == id })?.lastScrollOffset ?? 0
    }

    static func touch(id: String, title: String? = nil) {
        var library = loadLibrary()
        if let index = library.scripts.firstIndex(where: { $0.id == id }) {
            library.scripts[index].updatedAt = Date()
            if let title { library.scripts[index].title = title }
        } else {
            library.scripts.append(ScriptMeta(id: id, title: title ?? "기본 대본",
                                              createdAt: Date(), updatedAt: Date()))
        }
        saveLibrary(library)
    }

    /// 활성 대본을 보장한다. 없으면 데모 대본으로 새로 만든다.
    ///
    /// 최초 실행 판별은 **문자열이 비었는지가 아니라 파일 존재 여부로** 한다.
    /// (사용자가 대본을 통째로 지운 것도 정상 상태이며, 그 빈 상태가 보존돼야 한다)
    static func ensureActiveScript() -> (id: String, text: String) {
        prepare()
        let storedID = SettingsStore.shared.settings.activeScriptID
        if let id = storedID, exists(id: id) {
            return (id, read(id: id) ?? "")
        }
        let id = storedID ?? UUID().uuidString
        write(id: id, text: demoScript)
        touch(id: id, title: "기본 대본")
        SettingsStore.shared.update { $0.activeScriptID = id }
        return (id, demoScript)
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
    var onScrollToTop: (() -> Void)?
    var onPreviousSection: (() -> Void)?
    var onNextSection: (() -> Void)?
    var onPasteClipboard: (() -> Void)?
    var onCheatSheet: (() -> Void)?

    /// 부팅 시 등록에 실패한 액션(다른 앱이 이미 그 조합을 잡고 있는 경우 등).
    private(set) var failedActions: Set<HotkeyAction> = []

    init() {
        // Set default hotkey configurations
        for action in HotkeyAction.allCases {
            hotkeyConfigs[action] = HotkeyConfig(keyCode: action.defaultKeyCode,
                                                 modifiers: HotkeyAction.defaultModifiers)
        }
        applyStoredHotkeys(SettingsStore.shared.settings.hotkeys)
    }

    /// 저장된 단축키를 적용한다. 신뢰할 수 없는 입력이므로 정규화한다:
    /// 모르는 액션 폐기 -> 수정자 없는 것 폐기 -> 중복 폐기 -> 누락은 기본값 유지.
    func applyStoredHotkeys(_ records: [HotkeyRecord]) {
        var seen = Set<String>()
        for record in records {
            guard let action = HotkeyAction(rawValue: record.action) else { continue }
            guard record.modifiers != 0 else { continue }
            let signature = "\(record.keyCode)-\(record.modifiers)"
            guard !seen.contains(signature) else { continue }
            seen.insert(signature)
            hotkeyConfigs[action] = HotkeyConfig(keyCode: record.keyCode, modifiers: record.modifiers)
        }
    }

    func persist() {
        let records = HotkeyAction.allCases.compactMap { action -> HotkeyRecord? in
            guard let config = hotkeyConfigs[action] else { return nil }
            return HotkeyRecord(action: action.rawValue, keyCode: config.keyCode, modifiers: config.modifiers)
        }
        SettingsStore.shared.update { $0.hotkeys = records }
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
                    case 8: HotkeyManager.shared.onScrollToTop?()
                    case 9: HotkeyManager.shared.onPreviousSection?()
                    case 10: HotkeyManager.shared.onNextSection?()
                    case 11: HotkeyManager.shared.onPasteClipboard?()
                    case 12: HotkeyManager.shared.onCheatSheet?()
                    default: break
                    }
                }
                return noErr
            }

            InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, nil, &eventHandler)
        }

        // Register all hotkeys — 실패를 버리지 않고 모아 둔다(사용자에게 알려야 하므로).
        failedActions.removeAll()
        for action in HotkeyAction.allCases {
            guard let config = hotkeyConfigs[action] else { continue }
            let ok = registerHotkey(id: UInt32(action.rawValue),
                                    keyCode: config.keyCode, modifiers: config.modifiers)
            if !ok { failedActions.insert(action) }
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

        let ok = registerHotkey(id: UInt32(action.rawValue), keyCode: keyCode, modifiers: modifiers)
        if ok { failedActions.remove(action) } else { failedActions.insert(action) }
        persist()
        SettingsStore.shared.flushNow()   // 단축키는 바꾸는 즉시 확정한다
        return ok
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

// MARK: - Prompter Overlay (읽기 보조 레이어)

/// 대본 위에 얹히는 비대화형 레이어. 시선 밴드·상하 페이드·진행률·남은 시간·상태 뱃지·토스트를 그린다.
///
/// `hitTest` 가 항상 nil 이라 마우스·트랙패드 이벤트를 하나도 가로채지 않는다
/// (프롬프터 스크롤은 그대로 동작해야 한다).
/// draw(_:) 대신 CALayer 로 구성해, 자동 스크롤 60fps 중에는 진행률 레이어의 frame 만 바뀌게 한다.
final class PrompterOverlayView: NSView {
    private let topFade = CAGradientLayer()
    private let bottomFade = CAGradientLayer()
    private let bandLayer = CALayer()
    private let progressTrack = CALayer()
    private let progressFill = CALayer()

    private let hudLabel = NSTextField(labelWithString: "")
    private let badgeLabel = NSTextField(labelWithString: "")
    private let toastLabel = NSTextField(labelWithString: "")
    private let cheatSheetLabel = NSTextField(labelWithString: "")
    private var toastHideWork: DispatchWorkItem?
    private var cheatSheetHideWork: DispatchWorkItem?

    /// 화면 높이에서 시선 밴드가 놓이는 위치(0=맨 위, 1=맨 아래).
    private let bandPosition: CGFloat = 0.38
    private let fadeHeight: CGFloat = 64

    var accentColor: NSColor = .white { didSet { applyColors() } }

    var showsFocusBand = true {
        didSet { bandLayer.isHidden = !showsFocusBand }
    }

    var progress: Double = 0 {
        didSet { layoutProgress() }
    }

    /// 재생 중 남은 시간(초). nil 이면 숨긴다.
    var remainingSeconds: Double? {
        didSet { updateHUD() }
    }

    var badgeText: String? {
        didSet {
            badgeLabel.stringValue = badgeText ?? ""
            badgeLabel.isHidden = (badgeText ?? "").isEmpty
            needsLayout = true
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.masksToBounds = true

        for gradient in [topFade, bottomFade] {
            gradient.isHidden = false
            layer?.addSublayer(gradient)
        }
        layer?.addSublayer(bandLayer)
        progressTrack.addSublayer(progressFill)
        layer?.addSublayer(progressTrack)

        for label in [hudLabel, badgeLabel, toastLabel] {
            label.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
            label.alignment = .center
            label.wantsLayer = true
            label.layer?.cornerRadius = 4
            label.isHidden = true
            addSubview(label)
        }
        toastLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        toastLabel.alignment = .center

        cheatSheetLabel.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        cheatSheetLabel.alignment = .left
        cheatSheetLabel.maximumNumberOfLines = 0
        cheatSheetLabel.wantsLayer = true
        cheatSheetLabel.layer?.cornerRadius = 8
        cheatSheetLabel.isHidden = true
        addSubview(cheatSheetLabel)

        applyColors()
    }

    private func applyColors() {
        let base = accentColor
        bandLayer.backgroundColor = base.withAlphaComponent(0.16).cgColor
        progressTrack.backgroundColor = base.withAlphaComponent(0.12).cgColor
        progressFill.backgroundColor = base.withAlphaComponent(0.55).cgColor

        // 위아래를 살짝 눌러 시선이 중앙 밴드에 머물게 한다.
        let clear = NSColor.black.withAlphaComponent(0).cgColor
        let dim = NSColor.black.withAlphaComponent(0.45).cgColor
        topFade.colors = [dim, clear]
        bottomFade.colors = [clear, dim]

        for label in [hudLabel, badgeLabel] {
            label.textColor = base.withAlphaComponent(0.85)
            label.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.35).cgColor
        }
        toastLabel.textColor = base
        toastLabel.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.6).cgColor
        cheatSheetLabel.textColor = base
        cheatSheetLabel.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.78).cgColor
    }

    /// 이 레이어는 절대 이벤트를 먹지 않는다.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func layout() {
        super.layout()
        let width = bounds.width
        let height = bounds.height

        topFade.frame = NSRect(x: 0, y: height - fadeHeight, width: width, height: fadeHeight)
        topFade.startPoint = CGPoint(x: 0.5, y: 1)
        topFade.endPoint = CGPoint(x: 0.5, y: 0)
        bottomFade.frame = NSRect(x: 0, y: 0, width: width, height: fadeHeight)
        bottomFade.startPoint = CGPoint(x: 0.5, y: 1)
        bottomFade.endPoint = CGPoint(x: 0.5, y: 0)

        let bandY = height * (1 - bandPosition)
        bandLayer.frame = NSRect(x: 0, y: bandY - 1, width: width, height: 2)

        progressTrack.frame = NSRect(x: 0, y: 0, width: width, height: 2)
        layoutProgress()

        hudLabel.frame = NSRect(x: width - 96, y: height - 26, width: 88, height: 18)
        badgeLabel.frame = NSRect(x: 8, y: height - 26, width: 132, height: 18)
        toastLabel.frame = NSRect(x: (width - 200) / 2, y: 18, width: 200, height: 24)

        if !cheatSheetLabel.isHidden {
            let size = cheatSheetLabel.attributedStringValue.size()
            let boxWidth = min(width - 32, size.width + 28)
            let boxHeight = min(height - 32, size.height + 20)
            cheatSheetLabel.frame = NSRect(x: (width - boxWidth) / 2,
                                           y: (height - boxHeight) / 2,
                                           width: boxWidth, height: boxHeight)
        }
    }

    /// 단축키 목록을 화면에 띄운다. 외울 필요 없이 필요할 때 확인하면 된다.
    func toggleCheatSheet(_ lines: [(String, String)]) {
        if !cheatSheetLabel.isHidden {
            hideCheatSheet()
            return
        }
        let width = lines.map { $0.0.count }.max() ?? 0
        let body = lines
            .map { "\($0.0.padding(toLength: max(width, $0.0.count), withPad: " ", startingAt: 0))   \($0.1)" }
            .joined(separator: "\n")
        cheatSheetLabel.stringValue = body
        cheatSheetLabel.isHidden = false
        needsLayout = true

        cheatSheetHideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.hideCheatSheet() }
        cheatSheetHideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: work)
    }

    func hideCheatSheet() {
        cheatSheetHideWork?.cancel()
        cheatSheetHideWork = nil
        cheatSheetLabel.isHidden = true
    }

    private func layoutProgress() {
        let clamped = max(0, min(1, progress))
        progressFill.frame = NSRect(x: 0, y: 0, width: bounds.width * CGFloat(clamped), height: 2)
    }

    private func updateHUD() {
        guard let seconds = remainingSeconds, seconds.isFinite, seconds > 0 else {
            hudLabel.isHidden = true
            return
        }
        let total = Int(seconds.rounded())
        hudLabel.stringValue = String(format: "남음 %d:%02d", total / 60, total % 60)
        hudLabel.isHidden = false
    }

    /// 설정 창을 닫아 둔 상태에서 단축키로 속도를 바꿔도 바뀐 걸 알 수 있게 한다.
    func showToast(_ message: String) {
        toastLabel.stringValue = message
        toastLabel.isHidden = false
        toastLabel.alphaValue = 1
        toastHideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                self.toastLabel.animator().alphaValue = 0
            } completionHandler: {
                self.toastLabel.isHidden = true
            }
        }
        toastHideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4, execute: work)
    }
}

// MARK: - Prompter Control Strip (호버 시 나타나는 조작 바)

/// 단축키를 외우지 않아도, 설정 창을 열지 않아도 기본 조작이 되게 한다.
/// 오버레이(PrompterOverlayView)는 이벤트를 통과시키므로 클릭을 받으려면 별도 뷰여야 한다.
final class PrompterControlStrip: NSView {
    var onTogglePlay: (() -> Void)?
    var onSlower: (() -> Void)?
    var onFaster: (() -> Void)?
    var onSmaller: (() -> Void)?
    var onBigger: (() -> Void)?
    var onTop: (() -> Void)?
    var onSettings: (() -> Void)?

    private var playButton: NSButton?
    private var hideWork: DispatchWorkItem?
    private var buttons: [NSButton] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.72).cgColor
        alphaValue = 0

        playButton = addButton("▶︎") { [weak self] in self?.onTogglePlay?() }
        _ = addButton("느리게") { [weak self] in self?.onSlower?() }
        _ = addButton("빠르게") { [weak self] in self?.onFaster?() }
        _ = addButton("가")     { [weak self] in self?.onSmaller?() }
        _ = addButton("가+")    { [weak self] in self?.onBigger?() }
        _ = addButton("처음")   { [weak self] in self?.onTop?() }
        _ = addButton("설정")   { [weak self] in self?.onSettings?() }
    }

    private func addButton(_ title: String, action: @escaping () -> Void) -> NSButton {
        let button = ClosureButton(title: title, handler: action)
        button.bezelStyle = .inline
        button.isBordered = false
        button.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        button.contentTintColor = .white
        button.attributedTitle = NSAttributedString(string: title, attributes: [
            .foregroundColor: NSColor.white,
            .font: NSFont.systemFont(ofSize: 12, weight: .medium)
        ])
        addSubview(button)
        buttons.append(button)
        return button
    }

    func setPlaying(_ playing: Bool) {
        let title = playing ? "⏸" : "▶︎"
        playButton?.attributedTitle = NSAttributedString(string: title, attributes: [
            .foregroundColor: NSColor.white,
            .font: NSFont.systemFont(ofSize: 12, weight: .medium)
        ])
    }

    override func layout() {
        super.layout()
        var x: CGFloat = 8
        for button in buttons {
            let width = max(34, button.attributedTitle.size().width + 16)
            button.frame = NSRect(x: x, y: 4, width: width, height: bounds.height - 8)
            x += width + 4
        }
    }

    /// 버튼 폭 합계에 맞는 크기.
    var fittingWidth: CGFloat {
        var total: CGFloat = 12
        for button in buttons { total += max(34, button.attributedTitle.size().width + 16) + 4 }
        return total
    }

    func show() {
        hideWork?.cancel()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            animator().alphaValue = 1
        }
    }

    func scheduleHide() {
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                self.animator().alphaValue = 0
            }
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }
}

/// 타깃-액션 대신 클로저를 쓰기 위한 최소 버튼.
final class ClosureButton: NSButton {
    private let handler: () -> Void

    init(title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(frame: .zero)
        self.title = title
        self.target = self
        self.action = #selector(fire)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) 미지원") }

    @objc private func fire() { handler() }
}

// MARK: - Prompter View (Optimized with NSTextView)
class PrompterView: NSView {
    private var scrollView: NSScrollView!
    private var textView: NSTextView!
    private var cachedTotalHeight: CGFloat = 0
    private var scrollerHideTimer: Timer?
    let overlay = PrompterOverlayView()
    let controlStrip = PrompterControlStrip()
    private let flipContainer = NSView()

    /// 유리 프롬프터(반사 리그)는 거울에 비친 글자를 읽으므로 좌우를 뒤집어야 한다.
    var mirrorHorizontal = false {
        didSet {
            guard mirrorHorizontal != oldValue else { return }
            applyMirrorTransform()
            SettingsStore.shared.update { $0.mirrorHorizontal = mirrorHorizontal }
        }
    }

    var mirrorVertical = false {
        didSet {
            guard mirrorVertical != oldValue else { return }
            applyMirrorTransform()
            SettingsStore.shared.update { $0.mirrorVertical = mirrorVertical }
        }
    }

    /// 셀프테스트용 — 반전이 실제 좌표 변환으로 이어졌는지 확인한다.
    /// (레이어 transform 은 컴포지터가 적용하므로 픽셀 캡처로는 검증이 불안정하다)
    func mirrorProbe() -> (topLeftMapsTo: CGPoint, size: CGSize)? {
        guard let inner = flipContainer.layer, let outer = layer else { return nil }
        return (inner.convert(CGPoint.zero, to: outer), flipContainer.bounds.size)
    }

    /// 레이어 transform 은 anchorPoint 기준으로 걸린다. AppKit 이 layer.frame 을 다시 쓰면
    /// transform 과 충돌하므로, 매번 bounds/position 을 직접 맞춘 뒤 transform 을 건다.
    private func applyMirrorTransform() {
        guard let layer = flipContainer.layer else { return }
        let size = flipContainer.bounds.size
        guard size.width > 0, size.height > 0 else { return }

        layer.transform = CATransform3DIdentity
        layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        layer.bounds = CGRect(origin: .zero, size: size)
        layer.position = CGPoint(x: flipContainer.frame.midX, y: flipContainer.frame.midY)

        guard mirrorHorizontal || mirrorVertical else { return }
        layer.transform = CATransform3DMakeScale(mirrorHorizontal ? -1 : 1,
                                                 mirrorVertical ? -1 : 1, 1)
    }

    /// 스크롤 정책(맨 위로 갈지 읽던 자리를 지킬지)은 호출자가 정한다.
    /// 새 대본을 여는 것과, 보고 있는 대본을 편집하는 것은 다르게 다뤄야 한다.
    private(set) var text: String = ""

    func setText(_ newValue: String, preserveScroll: Bool) {
        guard newValue != text else { return }
        text = newValue
        updateTextContent(preserveScroll: preserveScroll)
    }

    var textColor: NSColor = .white {
        didSet {
            guard textColor != oldValue else { return }
            updateTextContent()
            overlay.accentColor = textColor
            if let rgba = RGBA(textColor) {
                SettingsStore.shared.update { $0.textColor = rgba }
            }
        }
    }

    var fontSize: CGFloat = 32 {
        didSet {
            guard fontSize != oldValue else { return }
            updateTextContent()
            SettingsStore.shared.update { $0.fontSize = Double(fontSize) }
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
            overlay.progress = maxY > 0 ? Double(clampedOffset / maxY) : 0
        }
    }

    /// 자동 스크롤이 도달할 수 있는 최대 오프셋. 컨트롤러의 정지 판정과 같은 식을 쓴다.
    var maxScrollOffset: CGFloat {
        max(0, cachedTotalHeight - bounds.height)
    }

    /// 한 번에 몇 픽셀 움직일지. 고정 50px 은 48pt 글자에서 한 줄도 못 넘기고
    /// 16pt 에서는 두 줄이 넘어가 버린다. 글자 크기에 비례시킨다.
    var lineScrollStep: CGFloat {
        max(24, fontSize * lineHeight * 2)
    }

    /// didSet 이 없으면 값을 복원해도 화면에 반영되지 않는다(설정 저장을 붙이면서 드러난 누락).
    var lineHeight: CGFloat = 1.5 {
        didSet {
            guard lineHeight != oldValue else { return }
            updateTextContent()
            SettingsStore.shared.update { $0.lineHeight = Double(lineHeight) }
        }
    }

    /// nil 이면 시스템 폰트. 한글 대본이 많아 커버리지가 있는 폰트만 노출한다.
    var fontName: String? {
        didSet {
            guard fontName != oldValue else { return }
            updateTextContent()
            SettingsStore.shared.update { $0.fontName = fontName }
        }
    }

    var kern: CGFloat = 0 {
        didSet {
            guard kern != oldValue else { return }
            updateTextContent()
            SettingsStore.shared.update { $0.kern = Double(kern) }
        }
    }

    /// 한 줄의 최대 폭(pt). 0 이면 창 너비를 다 쓴다.
    ///
    /// 프롬프터에서 가장 치명적인 가독성 문제가 이것이다 — 창을 넓히면 한 줄이 수십 자로
    /// 늘어져 줄 끝에서 다음 줄 머리를 못 찾는다. 폭을 제한하고 가운데로 모은다.
    var maxLineWidth: CGFloat = 0 {
        didSet {
            guard maxLineWidth != oldValue else { return }
            applyTextInsets()
            updateTextContent()
            SettingsStore.shared.update { $0.maxLineWidth = Double(maxLineWidth) }
        }
    }

    /// 본문에 쓸 폰트를 만든다. 이름이 유효하지 않으면 시스템 폰트로 조용히 되돌아간다.
    func bodyFont(size: CGFloat, weight: NSFont.Weight) -> NSFont {
        guard let name = fontName, !name.isEmpty else {
            return NSFont.systemFont(ofSize: size, weight: weight)
        }
        if let custom = NSFont(name: name, size: size) {
            if weight == .bold || weight == .semibold {
                let bolded = NSFontManager.shared.convert(custom, toHaveTrait: .boldFontMask)
                return bolded
            }
            return custom
        }
        return NSFont.systemFont(ofSize: size, weight: weight)
    }

    /// 텍스트 컨테이너 폭과 좌우 여백을 maxLineWidth 에 맞춘다.
    private func applyTextInsets() {
        guard let textView = textView else { return }
        let available = max(80, bounds.width - 40)
        let target = maxLineWidth > 0 ? min(available, maxLineWidth) : available
        let sideInset = max(20, (bounds.width - target) / 2)
        textView.textContainerInset = NSSize(width: sideInset, height: 20)
        textView.textContainer?.containerSize = NSSize(width: target,
                                                       height: CGFloat.greatestFiniteMagnitude)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        wantsLayer = true   // flipContainer 의 transform 이 좌표계에 제대로 반영되도록

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

        // 미러 반전은 이 컨테이너에만 건다. 오버레이·조작 바까지 뒤집히면
        // 진행률·뱃지·버튼이 거울상이 되어 못 쓴다.
        flipContainer.frame = bounds
        flipContainer.autoresizingMask = [.width, .height]
        flipContainer.wantsLayer = true
        flipContainer.addSubview(scrollView)
        addSubview(flipContainer)

        // 읽기 보조 레이어는 스크롤뷰의 형제로 위에 얹는다(이벤트는 통과시킨다).
        overlay.frame = bounds
        overlay.autoresizingMask = [.width, .height]
        overlay.accentColor = textColor
        addSubview(overlay)

        // 조작 바는 오버레이보다 위. 이건 클릭을 받아야 하므로 hitTest 를 막지 않는다.
        addSubview(controlStrip)
        layoutControlStrip()
    }

    private func layoutControlStrip() {
        let height: CGFloat = 32
        let width = min(controlStrip.fittingWidth, bounds.width - 24)
        controlStrip.frame = NSRect(x: (bounds.width - width) / 2, y: 12, width: width, height: height)
        controlStrip.needsLayout = true
    }

    // MARK: 호버 감지

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        // .activeAlways 여야 앱이 비활성일 때도(=다른 앱으로 촬영 중일 때도) 반응한다.
        addTrackingArea(NSTrackingArea(rect: .zero,
                                       options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }

    override func mouseEntered(with event: NSEvent) {
        controlStrip.show()
    }

    override func mouseExited(with event: NSEvent) {
        controlStrip.scheduleHide()
    }

    // MARK: - Markdown Parser
    private func parseMarkdown(_ markdown: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let lines = markdown.components(separatedBy: "\n")
        var anchors: [Int] = []

        let baseParagraphStyle = NSMutableParagraphStyle()
        baseParagraphStyle.lineHeightMultiple = lineHeight
        baseParagraphStyle.alignment = .left

        // 제목에는 본문 행간을 그대로 쓰지 않는다. lineHeightMultiple 이 큰 글자에 곱해지면
        // 제목 줄만 과하게 벌어져 대본이 뚝뚝 끊겨 보인다.
        let headingParagraphStyle = NSMutableParagraphStyle()
        headingParagraphStyle.lineHeightMultiple = min(lineHeight, 1.15)
        headingParagraphStyle.paragraphSpacingBefore = fontSize * 0.4
        headingParagraphStyle.alignment = .left

        for (index, line) in lines.enumerated() {
            var processedLine = line
            var lineFont = bodyFont(size: fontSize, weight: .medium)
            var lineColor = textColor
            var prefix = ""
            var isHeading = false

            // Headers: #, ##, ###, ####, #####, ######
            if line.hasPrefix("###### ") {
                processedLine = String(line.dropFirst(7))
                lineFont = bodyFont(size: fontSize * 0.85, weight: .semibold)
                isHeading = true
            } else if line.hasPrefix("##### ") {
                processedLine = String(line.dropFirst(6))
                lineFont = bodyFont(size: fontSize * 0.9, weight: .semibold)
                isHeading = true
            } else if line.hasPrefix("#### ") {
                processedLine = String(line.dropFirst(5))
                lineFont = bodyFont(size: fontSize * 1.0, weight: .bold)
                isHeading = true
            } else if line.hasPrefix("### ") {
                processedLine = String(line.dropFirst(4))
                lineFont = bodyFont(size: fontSize * 1.15, weight: .bold)
                isHeading = true
            } else if line.hasPrefix("## ") {
                processedLine = String(line.dropFirst(3))
                lineFont = bodyFont(size: fontSize * 1.3, weight: .bold)
                isHeading = true
            } else if line.hasPrefix("# ") {
                processedLine = String(line.dropFirst(2))
                lineFont = bodyFont(size: fontSize * 1.5, weight: .bold)
                isHeading = true
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

            // 섹션 앵커: 제목 줄이 시작하는 문자 위치를 기록해 둔다(섹션 점프용).
            if isHeading {
                anchors.append(result.length)
            }

            let paragraphStyle = isHeading ? headingParagraphStyle : baseParagraphStyle

            // Process inline formatting: **bold**, *italic*, ~~strikethrough~~, `code`
            let attributedLine = Self.processInlineMarkdown(processedLine, baseFont: lineFont, baseColor: lineColor)

            // Add prefix if exists
            if !prefix.isEmpty {
                let prefixAttr = NSAttributedString(string: prefix, attributes: [
                    .font: lineFont,
                    .foregroundColor: lineColor,
                    .paragraphStyle: paragraphStyle
                ])
                result.append(prefixAttr)
            }

            // Apply paragraph style to the line
            let lineWithStyle = NSMutableAttributedString(attributedString: attributedLine)
            lineWithStyle.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: lineWithStyle.length))

            result.append(lineWithStyle)

            // Add newline except for last line
            if index < lines.count - 1 {
                result.append(NSAttributedString(string: "\n", attributes: [
                    .font: lineFont,
                    .foregroundColor: lineColor
                ]))
            }
        }

        // 자간은 줄별 처리와 무관하므로 마지막에 한 번에 건다.
        if kern != 0, result.length > 0 {
            result.addAttribute(.kern, value: kern, range: NSRange(location: 0, length: result.length))
        }

        sectionAnchors = anchors
        return result
    }

    // MARK: 섹션 점프

    /// 제목 줄이 시작하는 문자 인덱스 목록(parseMarkdown 이 채운다).
    private(set) var sectionAnchors: [Int] = []

    /// 문자 인덱스가 문서 좌표계에서 몇 px 지점인지.
    private func documentY(forCharacterIndex index: Int) -> CGFloat? {
        guard let layoutManager = textView?.layoutManager,
              let container = textView?.textContainer,
              index >= 0, index <= (textView?.string.count ?? 0) else { return nil }
        let glyphIndex = layoutManager.glyphIndexForCharacter(at: index)
        let rect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 1),
                                              in: container)
        return rect.minY + (textView?.textContainerInset.height ?? 0)
    }

    /// 다음/이전 섹션으로 이동. 이동했으면 섹션 번호(1-based)와 총 개수를 돌려준다.
    func jumpToSection(forward: Bool) -> (index: Int, total: Int)? {
        guard !sectionAnchors.isEmpty else { return nil }
        let positions = sectionAnchors.compactMap { documentY(forCharacterIndex: $0) }
        guard !positions.isEmpty else { return nil }

        let current = scrollOffset
        let epsilon: CGFloat = 4
        let target: CGFloat?
        if forward {
            target = positions.first { $0 > current + epsilon }
        } else {
            target = positions.last { $0 < current - epsilon }
        }
        guard let destination = target else { return nil }

        scrollOffset = destination
        let ordinal = (positions.firstIndex(of: destination) ?? 0) + 1
        return (ordinal, positions.count)
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

    /// - Parameter preserveScroll: 읽던 위치를 비율로 유지할지. 새 대본을 넣을 때만 false.
    ///
    /// 예전에는 무조건 맨 위로 되돌렸는데, 이 메서드는 글자 크기·색·창 크기 변경에서도
    /// 호출되고 NSSlider 는 기본이 연속(isContinuous) 이라 슬라이더를 한 번 끄는 동안
    /// 수십 번 리셋됐다. 낭독 중이면 읽던 자리를 통째로 잃는다.
    private func updateTextContent(preserveScroll: Bool = true) {
        guard let textView = textView, let scrollView = scrollView else { return }

        let previousMax = max(0, cachedTotalHeight - bounds.height)
        let previousRatio = previousMax > 0 ? scrollOffset / previousMax : 0

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

        let clipView = scrollView.contentView
        let newMax = max(0, cachedTotalHeight - bounds.height)
        if preserveScroll {
            clipView.setBoundsOrigin(NSPoint(x: 0, y: min(previousRatio * newMax, newMax)))
        } else {
            clipView.setBoundsOrigin(.zero)
        }
        scrollView.reflectScrolledClipView(clipView)
        overlay.progress = newMax > 0 ? Double(clipView.bounds.origin.y / newMax) : 0
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
        // 폭이 안 바뀌면 줄바꿈이 그대로라 재파싱·재레이아웃이 불필요하다.
        // (실측상 비용의 대부분은 정규식이 아니라 setAttributedString + ensureLayout 이다)
        let widthChanged = abs(newSize.width - frame.width) > 0.5
        super.setFrameSize(newSize)
        layoutControlStrip()
        applyMirrorTransform()   // 크기가 바뀌면 anchor/position 을 다시 맞춰야 한다
        guard let textView = textView else { return }
        textView.frame.size.width = newSize.width
        if widthChanged {
            applyTextInsets()
            updateTextContent(preserveScroll: true)
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
class SettingsWindowController: NSWindowController, NSWindowDelegate, NSTextViewDelegate {
    var prompterController: PrompterWindowController?
    var hotkeyRecorders: [HotkeyAction: HotkeyRecorderField] = [:]
    // viewWithTag 조회 대신 직접 참조를 들고 있는다.
    // 태그 조회는 뷰 계층이 바뀌면 조용히 nil 이 되어 "슬라이더는 움직이는데 숫자가 안 바뀌는"
    // 회귀를 만든다(그때 컴파일러는 아무 말도 해주지 않는다).
    var fontSlider: NSSlider?
    var fontValueLabel: NSTextField?
    var opacitySlider: NSSlider?
    var opacityValueLabel: NSTextField?
    var speedSlider: NSSlider?
    var speedValueLabel: NSTextField?
    var lineHeightValueLabel: NSTextField?
    var kernValueLabel: NSTextField?
    var maxLineWidthValueLabel: NSTextField?
    var targetMinutesField: NSTextField?
    var prompterTextView: FineUndoTextView?  // 텍스트 입력창 참조
    private var editKeyMonitor: Any?
    private var livePreviewWorkItem: DispatchWorkItem?

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
        window.delegate = self

        setupUI()
    }

    func windowWillClose(_ notification: Notification) {
        // 설정을 만지고 창을 닫는 건 작업 확정이다. 디바운스를 기다리지 않고 기록한다.
        SettingsStore.shared.flushNow()
    }

    /// 대본이 밖(메뉴 전환·클립보드 투입)에서 바뀌면 편집 상자도 따라가야 한다.
    /// 안 그러면 설정창에 옛 대본이 남아 다음 타이핑이 그걸 되살린다.
    func reloadScriptText() {
        guard let textView = prompterTextView, let controller = prompterController else { return }
        let current = controller.prompterView.text
        guard textView.string != current else { return }
        livePreviewWorkItem?.cancel()
        textView.setupInitialText(current)
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
        textView.delegate = self   // 실시간 반영
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
        // 타이핑하면 자동 반영되므로 이 버튼은 "지금 즉시 파일에 확정"이라는 의미로 남긴다.
        let applyTextButton = NSButton(title: "지금 저장", target: self, action: #selector(applyText(_:)))
        applyTextButton.frame = NSRect(x: leftMargin, y: yOffset, width: 100, height: 28)
        applyTextButton.bezelStyle = .rounded
        contentView.addSubview(applyTextButton)

        let autoApplyHint = NSTextField(labelWithString: "입력하면 자동으로 반영·저장됩니다")
        autoApplyHint.font = NSFont.systemFont(ofSize: 11)
        autoApplyHint.textColor = .secondaryLabelColor
        autoApplyHint.frame = NSRect(x: leftMargin + 110, y: yOffset + 4, width: 260, height: 18)
        contentView.addSubview(autoApplyHint)
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
        self.fontSlider = fontSlider

        let fontValueLabel = NSTextField(labelWithString: "\(Int(prompterController.prompterView.fontSize))pt")
        fontValueLabel.frame = NSRect(x: controlX + controlWidth - 55, y: yOffset, width: 50, height: 20)
        contentView.addSubview(fontValueLabel)
        self.fontValueLabel = fontValueLabel
        yOffset -= 30

        // Background opacity
        let opacityLabel = NSTextField(labelWithString: "배경 투명도:")
        opacityLabel.frame = NSRect(x: leftMargin, y: yOffset, width: labelWidth, height: 20)
        contentView.addSubview(opacityLabel)

        let opacitySlider = NSSlider(value: Double(prompterController.backgroundOpacity), minValue: 0.1, maxValue: 1.0, target: self, action: #selector(opacityChanged(_:)))
        opacitySlider.frame = NSRect(x: controlX, y: yOffset, width: controlWidth - 60, height: 20)
        contentView.addSubview(opacitySlider)
        self.opacitySlider = opacitySlider

        let opacityValueLabel = NSTextField(labelWithString: "\(Int(prompterController.backgroundOpacity * 100))%")
        opacityValueLabel.frame = NSRect(x: controlX + controlWidth - 55, y: yOffset, width: 50, height: 20)
        contentView.addSubview(opacityValueLabel)
        self.opacityValueLabel = opacityValueLabel
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
        yOffset -= 45

        // 행간
        let lineHeightLabel = NSTextField(labelWithString: "행간:")
        lineHeightLabel.frame = NSRect(x: leftMargin, y: yOffset, width: labelWidth, height: 20)
        contentView.addSubview(lineHeightLabel)

        let lineHeightSlider = NSSlider(value: Double(prompterController.prompterView.lineHeight),
                                        minValue: 1.0, maxValue: 2.5,
                                        target: self, action: #selector(lineHeightChanged(_:)))
        lineHeightSlider.frame = NSRect(x: controlX, y: yOffset, width: controlWidth - 60, height: 20)
        contentView.addSubview(lineHeightSlider)

        let lineHeightValue = NSTextField(labelWithString: String(format: "%.2f", prompterController.prompterView.lineHeight))
        lineHeightValue.frame = NSRect(x: controlX + controlWidth - 55, y: yOffset, width: 50, height: 20)
        contentView.addSubview(lineHeightValue)
        self.lineHeightValueLabel = lineHeightValue
        yOffset -= 30

        // 자간
        let kernLabel = NSTextField(labelWithString: "자간:")
        kernLabel.frame = NSRect(x: leftMargin, y: yOffset, width: labelWidth, height: 20)
        contentView.addSubview(kernLabel)

        let kernSlider = NSSlider(value: Double(prompterController.prompterView.kern),
                                  minValue: -1, maxValue: 4,
                                  target: self, action: #selector(kernChanged(_:)))
        kernSlider.frame = NSRect(x: controlX, y: yOffset, width: controlWidth - 60, height: 20)
        contentView.addSubview(kernSlider)

        let kernValue = NSTextField(labelWithString: String(format: "%.1f", prompterController.prompterView.kern))
        kernValue.frame = NSRect(x: controlX + controlWidth - 55, y: yOffset, width: 50, height: 20)
        contentView.addSubview(kernValue)
        self.kernValueLabel = kernValue
        yOffset -= 30

        // 최대 줄 너비 — 프롬프터 가독성에서 가장 큰 변수
        let widthLabel = NSTextField(labelWithString: "최대 줄 너비:")
        widthLabel.frame = NSRect(x: leftMargin, y: yOffset, width: labelWidth, height: 20)
        contentView.addSubview(widthLabel)

        let widthSlider = NSSlider(value: Double(prompterController.prompterView.maxLineWidth),
                                   minValue: 0, maxValue: 1400,
                                   target: self, action: #selector(maxLineWidthChanged(_:)))
        widthSlider.frame = NSRect(x: controlX, y: yOffset, width: controlWidth - 60, height: 20)
        contentView.addSubview(widthSlider)

        let widthValue = NSTextField(labelWithString: Self.lineWidthText(prompterController.prompterView.maxLineWidth))
        widthValue.frame = NSRect(x: controlX + controlWidth - 60, y: yOffset, width: 60, height: 20)
        contentView.addSubview(widthValue)
        self.maxLineWidthValueLabel = widthValue
        yOffset -= 30

        // 폰트
        let fontFamilyLabel = NSTextField(labelWithString: "폰트:")
        fontFamilyLabel.frame = NSRect(x: leftMargin, y: yOffset, width: labelWidth, height: 20)
        contentView.addSubview(fontFamilyLabel)

        let fontPopup = NSPopUpButton(frame: NSRect(x: controlX, y: yOffset - 2, width: controlWidth - 5, height: 25))
        fontPopup.addItem(withTitle: "시스템 기본")
        fontPopup.item(at: 0)?.representedObject = ""
        for family in Self.koreanCapableFontFamilies() {
            fontPopup.addItem(withTitle: family)
            fontPopup.lastItem?.representedObject = family
        }
        if let current = prompterController.prompterView.fontName,
           let index = fontPopup.itemTitles.firstIndex(of: current) {
            fontPopup.selectItem(at: index)
        }
        fontPopup.target = self
        fontPopup.action = #selector(fontFamilyChanged(_:))
        contentView.addSubview(fontPopup)
        yOffset -= 35

        // 읽기 보조 토글
        let bandCheckbox = NSButton(checkboxWithTitle: "시선 밴드 표시", target: self,
                                    action: #selector(focusBandToggled(_:)))
        bandCheckbox.state = prompterController.prompterView.overlay.showsFocusBand ? .on : .off
        bandCheckbox.frame = NSRect(x: leftMargin, y: yOffset, width: 150, height: 20)
        contentView.addSubview(bandCheckbox)

        let countdownCheckbox = NSButton(checkboxWithTitle: "재생 전 3초 카운트다운", target: self,
                                         action: #selector(countdownToggled(_:)))
        countdownCheckbox.state = prompterController.countdownEnabled ? .on : .off
        countdownCheckbox.frame = NSRect(x: leftMargin + 160, y: yOffset, width: 220, height: 20)
        contentView.addSubview(countdownCheckbox)
        yOffset -= 28

        // 유리 프롬프터(반사 리그)용 반전
        let mirrorH = NSButton(checkboxWithTitle: "좌우 반전 (유리 프롬프터)", target: self,
                               action: #selector(mirrorHorizontalToggled(_:)))
        mirrorH.state = prompterController.prompterView.mirrorHorizontal ? .on : .off
        mirrorH.frame = NSRect(x: leftMargin, y: yOffset, width: 200, height: 20)
        contentView.addSubview(mirrorH)

        let mirrorV = NSButton(checkboxWithTitle: "상하 반전", target: self,
                               action: #selector(mirrorVerticalToggled(_:)))
        mirrorV.state = prompterController.prompterView.mirrorVertical ? .on : .off
        mirrorV.frame = NSRect(x: leftMargin + 210, y: yOffset, width: 160, height: 20)
        contentView.addSubview(mirrorV)
        yOffset -= 35

        // 목표 시간 -> 속도 역산
        let targetLabel = NSTextField(labelWithString: "목표 시간:")
        targetLabel.frame = NSRect(x: leftMargin, y: yOffset, width: labelWidth, height: 20)
        contentView.addSubview(targetLabel)

        let targetField = NSTextField(frame: NSRect(x: controlX, y: yOffset - 2, width: 60, height: 22))
        targetField.placeholderString = "분"
        targetField.alignment = .right
        contentView.addSubview(targetField)
        self.targetMinutesField = targetField

        let targetUnit = NSTextField(labelWithString: "분에 맞추기")
        targetUnit.frame = NSRect(x: controlX + 66, y: yOffset, width: 90, height: 20)
        contentView.addSubview(targetUnit)

        let targetButton = NSButton(title: "속도 계산", target: self, action: #selector(applyTargetDuration(_:)))
        targetButton.frame = NSRect(x: controlX + 160, y: yOffset - 4, width: 90, height: 26)
        targetButton.bezelStyle = .rounded
        contentView.addSubview(targetButton)
        yOffset -= 45

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

        // 내용이 고정 높이를 넘으면 아래쪽 컨트롤이 잘려 나간다.
        // (단축키 행이 7개에서 11개로 늘면서 실제로 넘쳤다)
        // 부족한 만큼 컨테이너를 키우고 전체를 위로 밀어 항상 들어맞게 한다.
        let bottomPadding: CGFloat = 20
        if yOffset < bottomPadding {
            let deficit = bottomPadding - yOffset
            contentView.frame.size.height += deficit
            for subview in contentView.subviews {
                subview.frame.origin.y += deficit
            }
        }

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

        // 주의: RegisterEventHotKey 는 시스템/타앱이 이미 점유한 조합에도 noErr 을 돌려준다
        // (⌘Space·⌘Tab 등으로 실측). 즉 여기서 false 가 되는 경우는 사실상 앱 내부 중복뿐이며,
        // 시스템 충돌은 이 반환값으로 알 수 없다.
        let success = HotkeyManager.shared.updateHotkey(action: action, keyCode: keyCode, modifiers: modifiers)
        return success
    }

    @objc func resetHotkeys(_ sender: NSButton) {
        let defaultModifiers = HotkeyAction.defaultModifiers

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
        HotkeyManager.shared.persist()
        SettingsStore.shared.flushNow()
        (NSApp.delegate as? AppDelegate)?.refreshHotkeyFailureIndicator()
    }

    /// 부팅 시 등록에 실패한 단축키를 해당 행에 표시한다(현재는 앱 내부 중복이 주 원인).
    func showRegistrationFailures() {
        for action in HotkeyManager.shared.failedActions {
            hotkeyRecorders[action]?.statusLabel?.stringValue = "✗ 다른 앱이 사용 중"
            hotkeyRecorders[action]?.statusLabel?.textColor = .systemRed
        }
    }

    @objc func applyText(_ sender: NSButton) {
        guard let textView = prompterTextView, let controller = prompterController else { return }
        controller.updateScript(textView.string, immediate: true)
        if !controller.flushScript() {
            // 조용히 삼키면 사용자는 저장된 줄 안다.
            let alert = NSAlert()
            alert.messageText = "대본을 저장하지 못했습니다"
            alert.informativeText = "화면에는 반영됐지만 파일 쓰기에 실패했습니다.\n\n\(ScriptStore.baseURL.path)"
            alert.alertStyle = .warning
            alert.window.sharingType = .none
            alert.runModal()
        }
    }

    // MARK: NSTextViewDelegate — 실시간 반영

    func textDidChange(_ notification: Notification) {
        guard let textView = prompterTextView, notification.object as? NSTextView === textView else { return }
        // 화면 반영은 0.3초, 파일 쓰기는 updateScript 안에서 다시 1.5초로 묶인다.
        livePreviewWorkItem?.cancel()
        let snapshot = textView.string
        let work = DispatchWorkItem { [weak self] in
            self?.prompterController?.updateScript(snapshot)
        }
        livePreviewWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    @objc func fontSizeChanged(_ sender: NSSlider) {
        prompterController?.prompterView.fontSize = CGFloat(sender.doubleValue)
        fontValueLabel?.stringValue = "\(Int(sender.doubleValue))pt"
    }

    @objc func opacityChanged(_ sender: NSSlider) {
        // 화면 반영과 저장은 backgroundOpacity 의 didSet 이 함께 처리한다.
        prompterController?.backgroundOpacity = CGFloat(sender.doubleValue)
        opacityValueLabel?.stringValue = "\(Int(sender.doubleValue * 100))%"
    }

    @objc func speedChanged(_ sender: NSSlider) {
        prompterController?.scrollSpeed = CGFloat(sender.doubleValue)
        speedValueLabel?.stringValue = "\(Int(sender.doubleValue))"
    }

    @objc func lineHeightChanged(_ sender: NSSlider) {
        prompterController?.prompterView.lineHeight = CGFloat(sender.doubleValue)
        lineHeightValueLabel?.stringValue = String(format: "%.2f", sender.doubleValue)
    }

    @objc func kernChanged(_ sender: NSSlider) {
        prompterController?.prompterView.kern = CGFloat(sender.doubleValue)
        kernValueLabel?.stringValue = String(format: "%.1f", sender.doubleValue)
    }

    @objc func maxLineWidthChanged(_ sender: NSSlider) {
        // 400pt 미만은 너무 좁아 오히려 읽기 나쁘므로 그 구간은 '제한 없음'으로 뭉갠다.
        let value = sender.doubleValue < 400 ? 0 : sender.doubleValue
        prompterController?.prompterView.maxLineWidth = CGFloat(value)
        maxLineWidthValueLabel?.stringValue = Self.lineWidthText(CGFloat(value))
    }

    static func lineWidthText(_ width: CGFloat) -> String {
        width <= 0 ? "제한 없음" : "\(Int(width))pt"
    }

    @objc func fontFamilyChanged(_ sender: NSPopUpButton) {
        let family = sender.selectedItem?.representedObject as? String
        prompterController?.prompterView.fontName = (family?.isEmpty ?? true) ? nil : family
    }

    @objc func focusBandToggled(_ sender: NSButton) {
        let on = sender.state == .on
        prompterController?.prompterView.overlay.showsFocusBand = on
        SettingsStore.shared.update { $0.showFocusBand = on }
    }

    @objc func countdownToggled(_ sender: NSButton) {
        prompterController?.countdownEnabled = (sender.state == .on)
    }

    @objc func mirrorHorizontalToggled(_ sender: NSButton) {
        prompterController?.prompterView.mirrorHorizontal = (sender.state == .on)
    }

    @objc func mirrorVerticalToggled(_ sender: NSButton) {
        prompterController?.prompterView.mirrorVertical = (sender.state == .on)
    }

    /// "이 대본을 N분에 읽는다"에서 스크롤 속도를 거꾸로 구한다.
    /// 강의·영상은 분량이 정해져 있어서, 속도를 감으로 맞추는 것보다 이쪽이 훨씬 빠르다.
    @objc func applyTargetDuration(_ sender: NSButton) {
        guard let controller = prompterController else { return }
        let minutes = targetMinutesField?.doubleValue ?? 0
        guard minutes > 0 else {
            controller.prompterView.overlay.showToast("목표 시간을 입력하세요")
            return
        }
        let distance = Double(controller.prompterView.maxScrollOffset)
        guard distance > 1 else {
            controller.prompterView.overlay.showToast("대본이 화면보다 짧습니다")
            return
        }
        let speed = distance / (minutes * 60)
        let clamped = min(200, max(10, speed))
        controller.scrollSpeed = CGFloat(clamped)
        updateSpeedDisplay(CGFloat(clamped))

        if abs(clamped - speed) > 0.5 {
            let actual = distance / clamped / 60
            controller.prompterView.overlay.showToast(String(format: "속도 한계 — 약 %.1f분", actual))
        } else {
            controller.prompterView.overlay.showToast("속도 \(Int(clamped)) (\(Int(minutes))분)")
        }
    }

    /// 한글이 깨지지 않는 폰트만 고른다(라틴 전용 폰트를 고르면 대본이 네모로 보인다).
    static func koreanCapableFontFamilies() -> [String] {
        let probe = "한글"
        return NSFontManager.shared.availableFontFamilies.filter { family in
            guard let font = NSFont(name: family, size: 12) else { return false }
            let set = font.coveredCharacterSet
            return probe.unicodeScalars.allSatisfy { set.contains($0) }
        }.sorted()
    }

    @objc func textColorChanged(_ sender: NSColorWell) {
        prompterController?.prompterView.textColor = sender.color
    }

    @objc func bgColorChanged(_ sender: NSColorWell) {
        prompterController?.backgroundColor = sender.color
    }

    func updateSpeedDisplay(_ speed: CGFloat) {
        speedSlider?.doubleValue = Double(speed)
        speedValueLabel?.stringValue = "\(Int(speed))"
    }

    /// 프롬프터 조작 바에서 값을 바꿨을 때 설정 창의 컨트롤도 따라가게 한다.
    func syncAppearanceControls() {
        guard let controller = prompterController else { return }
        let size = controller.prompterView.fontSize
        fontSlider?.doubleValue = Double(size)
        fontValueLabel?.stringValue = "\(Int(size))pt"
    }
}

// MARK: - Prompter Window Controller
class PrompterWindowController: NSWindowController, NSWindowDelegate {
    var prompterView: PrompterView!
    var scrollTimer: Timer?
    private var lastTick: CFTimeInterval = 0
    private var snapWorkItem: DispatchWorkItem?
    var isPlaying = false

    var scrollSpeed: CGFloat = 50 {  // pixels per second
        didSet {
            guard scrollSpeed != oldValue else { return }
            SettingsStore.shared.update { $0.scrollSpeed = Double(scrollSpeed) }
        }
    }

    /// 상태 뱃지가 생겼으므로 이제 복원해도 안전하다(해제 방법이 화면에 항상 보인다).
    var isClickThrough = false {
        didSet {
            guard isClickThrough != oldValue else { return }
            applyWindowChrome()
            SettingsStore.shared.update { $0.isClickThrough = isClickThrough }
        }
    }

    var backgroundColor: NSColor = .black {
        didSet {
            guard backgroundColor != oldValue else { return }
            applyWindowChrome()
            if let rgba = RGBA(backgroundColor) {
                SettingsStore.shared.update { $0.backgroundColor = rgba }
            }
        }
    }

    var backgroundOpacity: CGFloat = 0.7 {
        didSet {
            guard backgroundOpacity != oldValue else { return }
            applyWindowChrome()
            SettingsStore.shared.update { $0.backgroundOpacity = Double(backgroundOpacity) }
        }
    }

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

        window.minSize = NSSize(width: 240, height: 140)

        // 닫기 버튼을 숨긴다. 이 창은 캡처에 안 보이므로, 실수로 닫으면 사용자는
        // "앱이 사라졌다"고 느낀다. 숨김(⌃⌥H)으로만 치우게 한다.
        // (styleMask 의 .closable 을 빼면 타이틀바 레이아웃이 달라져 버튼만 감춘다)
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.isReleasedWhenClosed = false

        self.init(window: window)

        window.delegate = self   // NSWindowController 가 자동으로 잡아주지 않는다
        setupPrompterView()
        setupScrollWheel()
        wireControlStrip()
    }

    private func wireControlStrip() {
        let strip = prompterView.controlStrip
        strip.onTogglePlay = { [weak self] in self?.togglePlay() }
        strip.onSlower = { [weak self] in self?.speedDown() }
        strip.onFaster = { [weak self] in self?.speedUp() }
        strip.onSmaller = { [weak self] in self?.adjustFontSize(by: -2) }
        strip.onBigger = { [weak self] in self?.adjustFontSize(by: 2) }
        strip.onTop = { [weak self] in self?.scrollToTop() }
        strip.onSettings = { [weak self] in self?.showSettings() }
    }

    func adjustFontSize(by delta: CGFloat) {
        let newSize = min(72, max(16, prompterView.fontSize + delta))
        guard newSize != prompterView.fontSize else { return }
        prompterView.fontSize = newSize
        settingsController?.syncAppearanceControls()
        prompterView.overlay.showToast("글자 \(Int(newSize))pt")
    }

    // MARK: 설정 복원

    /// 저장된 설정을 화면에 적용한다.
    /// 순서가 중요하다 — 대본 텍스트 대입이 전체 재파싱을 유발하므로 **가장 마지막**이다.
    func applyLoadedSettings(_ settings: Settings) {
        Self.debugFrame("before-apply", window?.frame ?? .zero)
        if let frame = Self.resolvedWindowFrame(from: settings.windowFrame) {
            Self.debugFrame("stored", frame)
            window?.setFrame(frame, display: false)
            Self.debugFrame("after-setFrame", window?.frame ?? .zero)
        } else {
            Self.debugFrame("stored-rejected", .zero)
        }
        backgroundColor = settings.backgroundColor.nsColor
        backgroundOpacity = CGFloat(settings.backgroundOpacity)
        applyWindowChrome()

        prompterView.fontName = settings.fontName
        prompterView.kern = CGFloat(settings.kern)
        prompterView.maxLineWidth = CGFloat(settings.maxLineWidth)
        prompterView.fontSize = CGFloat(settings.fontSize)
        prompterView.lineHeight = CGFloat(settings.lineHeight)
        prompterView.textColor = settings.textColor.nsColor
        prompterView.overlay.showsFocusBand = settings.showFocusBand
        prompterView.mirrorHorizontal = settings.mirrorHorizontal
        prompterView.mirrorVertical = settings.mirrorVertical
        scrollSpeed = CGFloat(settings.scrollSpeed)
        countdownEnabled = settings.countdownEnabled

        isClickThrough = settings.isClickThrough
        applyClickThroughState()
    }

    /// 저장된 창 위치가 지금도 쓸 수 있는지 검증한다.
    ///
    /// 외부 모니터에 창을 두고 케이블을 뽑은 채 재실행하면 화면 밖으로 복원되는데,
    /// 이 앱은 캡처에 안 보이는 창이라 사용자에게는 "앱이 안 켜졌다"로 보인다.
    /// **반드시 applicationDidFinishLaunching 이후에 호출할 것** — 그 전에는 NSScreen.screens 가
    /// 비어 있어 멀쩡한 위치까지 버려진다.
    static func resolvedWindowFrame(from stored: [Double]?) -> NSRect? {
        guard let values = stored, values.count == 4, values.allSatisfy({ $0.isFinite }) else { return nil }
        let rect = NSRect(x: values[0], y: values[1], width: values[2], height: values[3])
        guard rect.width >= 200, rect.height >= 120 else { return nil }
        let visibleEnough = NSScreen.screens.contains { screen in
            let overlap = screen.visibleFrame.intersection(rect)
            return overlap.width >= 120 && overlap.height >= 60
        }
        return visibleEnough ? rect : nil
    }

    private func saveWindowFrame() {
        guard let frame = window?.frame else { return }
        Self.debugFrame("save", frame)
        SettingsStore.shared.update {
            $0.windowFrame = [Double(frame.origin.x), Double(frame.origin.y),
                              Double(frame.width), Double(frame.height)]
        }
    }

    /// SHADOWCUE_DEBUG_FRAME=1 일 때만 창 프레임 변화를 표준출력에 찍는다(진단용).
    static func debugFrame(_ label: String, _ frame: NSRect) {
        guard ProcessInfo.processInfo.environment["SHADOWCUE_DEBUG_FRAME"] == "1" else { return }
        // stdout 은 파이프에서 버퍼링되어 실행 중에는 안 보인다 -> 버퍼 없는 stderr 로.
        let line = "[frame] \(label): \(Int(frame.origin.x)),\(Int(frame.origin.y)) "
            + "\(Int(frame.width))x\(Int(frame.height))\n"
        FileHandle.standardError.write(Data(line.utf8))
    }

    private func setupPrompterView() {
        guard let window = window else { return }

        prompterView = PrompterView(frame: window.contentView!.bounds)
        prompterView.autoresizingMask = [.width, .height]
        // 대본은 AppDelegate 가 ScriptStore 에서 읽어 마지막에 넣는다(재파싱이 한 번만 일어나도록).
        window.contentView?.addSubview(prompterView)
    }

    // MARK: 대본

    private(set) var activeScriptID: String?
    private var scriptWriteWorkItem: DispatchWorkItem?

    /// 저장된 대본을 불러와 화면에 올린다. 없으면 데모 대본을 만들어 준다.
    func loadActiveScript() {
        let script = ScriptStore.ensureActiveScript()
        activeScriptID = script.id
        prompterView.setText(script.text, preserveScroll: false)

        // 이어읽기: 텍스트 레이아웃이 끝난 뒤에 적용해야 클램프에 걸리지 않는다.
        restoreReadingPosition(for: script.id, announce: true)
    }

    /// 화면에는 즉시 반영하고, 파일 쓰기만 묶는다.
    /// (134KB 대본을 무디바운스로 쓰면 타이핑 3초에 수십 MB 를 쓰게 된다)
    func updateScript(_ text: String, immediate: Bool = false) {
        // 편집 중에는 읽던 자리를 지킨다(타이핑할 때마다 맨 위로 튀면 못 쓴다).
        prompterView.setText(text, preserveScroll: true)
        scriptWriteWorkItem?.cancel()
        guard let id = activeScriptID else { return }
        let work = DispatchWorkItem {
            ScriptStore.write(id: id, text: text)
            ScriptStore.touch(id: id)
        }
        scriptWriteWorkItem = work
        if immediate {
            work.perform()
            scriptWriteWorkItem = nil
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
        }
    }

    /// 다른 대본으로 전환한다. 현재 대본은 먼저 확정 저장한다.
    func switchToScript(id: String) {
        guard id != activeScriptID else { return }
        flushScript()
        guard let text = ScriptStore.read(id: id) else {
            prompterView.overlay.showToast("대본 파일을 찾을 수 없습니다")
            return
        }
        activeScriptID = id
        SettingsStore.shared.update { $0.activeScriptID = id }
        SettingsStore.shared.flushNow()
        prompterView.setText(text, preserveScroll: false)
        restoreReadingPosition(for: id, announce: false)

        let title = ScriptStore.loadLibrary().scripts.first { $0.id == id }?.title ?? "대본"
        prompterView.overlay.showToast(title)
        settingsController?.reloadScriptText()
    }

    func createNewScript() {
        flushScript()
        let existing = ScriptStore.loadLibrary().scripts.count
        let id = UUID().uuidString
        ScriptStore.write(id: id, text: "")
        ScriptStore.touch(id: id, title: "새 대본 \(existing + 1)")
        activeScriptID = nil          // switchToScript 의 동일 ID 가드를 통과시키기 위해
        switchToScript(id: id)
    }

    /// 촬영 직전 ChatGPT·노션에서 뽑은 대본을 창 하나 안 열고 바로 넣는 최단 경로.
    func replaceScriptFromClipboard() {
        guard let text = NSPasteboard.general.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            prompterView.overlay.showToast("클립보드가 비어 있습니다")
            return
        }
        prompterView.setText(text, preserveScroll: false)
        updateScript(text, immediate: true)
        prompterView.overlay.showToast("클립보드에서 대본 교체")
        settingsController?.reloadScriptText()
    }

    private func restoreReadingPosition(for id: String, announce: Bool) {
        let saved = ScriptStore.scrollOffset(id: id)
        guard saved > 1 else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.prompterView.scrollOffset = CGFloat(saved)
            if announce, self.prompterView.scrollOffset > 1 {
                self.prompterView.overlay.showToast("읽던 위치에서 계속")
            }
        }
    }

    /// 종료·비활성 시점에 대기 중인 대본 쓰기를 확정한다.
    @discardableResult
    func flushScript() -> Bool {
        guard let id = activeScriptID else { return true }
        scriptWriteWorkItem?.cancel()
        scriptWriteWorkItem = nil
        let ok = ScriptStore.write(id: id, text: prompterView.text)
        if ok { ScriptStore.touch(id: id) }
        ScriptStore.saveScrollOffset(id: id, offset: Double(prompterView.scrollOffset))
        return ok
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
        prompterView.maxScrollOffset
    }

    /// 재생 전 3-2-1 카운트다운. 카메라 앞에서 자세를 잡을 시간이 필요할 때.
    var countdownEnabled = false {
        didSet {
            guard countdownEnabled != oldValue else { return }
            SettingsStore.shared.update { $0.countdownEnabled = countdownEnabled }
        }
    }
    private var countdownWork: [DispatchWorkItem] = []

    private func cancelCountdown() {
        countdownWork.forEach { $0.cancel() }
        countdownWork.removeAll()
    }

    private func runCountdownThenStart() {
        cancelCountdown()
        for step in [3, 2, 1] {
            let delay = Double(3 - step)
            let work = DispatchWorkItem { [weak self] in
                self?.prompterView.overlay.showToast("\(step)")
            }
            countdownWork.append(work)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }
        let go = DispatchWorkItem { [weak self] in
            guard let self = self, self.isPlaying else { return }
            self.startScrolling()
            self.prompterView.overlay.showToast("▶︎ 시작")
        }
        countdownWork.append(go)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: go)
    }

    func togglePlay() {
        isPlaying.toggle()
        if isPlaying {
            if countdownEnabled {
                prompterView.controlStrip.setPlaying(true)
                runCountdownThenStart()
                return
            }
            startScrolling()
            prompterView.overlay.showToast("▶︎ 재생")
        } else {
            cancelCountdown()
            stopScrolling()
            prompterView.overlay.remainingSeconds = nil
            prompterView.overlay.showToast("⏸ 일시정지")
        }
        prompterView.controlStrip.setPlaying(isPlaying)
    }

    /// 남은 분량을 현재 속도로 나눈 값. 자동 스크롤이 균일 속도이므로 정확하다.
    private func updateRemainingTime() {
        let remaining = maxScrollOffset - prompterView.scrollOffset
        guard isPlaying, scrollSpeed > 0, remaining > 0 else {
            prompterView.overlay.remainingSeconds = nil
            return
        }
        prompterView.overlay.remainingSeconds = Double(remaining / scrollSpeed)
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
            prompterView.controlStrip.setPlaying(false)
            prompterView.overlay.remainingSeconds = nil
            prompterView.overlay.showToast("대본 끝")
        } else {
            updateRemainingTime()
        }
    }

    func scrollUp() {
        prompterView.scrollOffset -= prompterView.lineScrollStep
        prompterView.scrollOffset = max(0, prompterView.scrollOffset)
        prompterView.showScrollerTemporarily()
    }

    func scrollDown() {
        prompterView.scrollOffset += prompterView.lineScrollStep
        prompterView.showScrollerTemporarily()
    }

    /// 재촬영할 때 매번 위로 끌어올리는 수고를 없앤다.
    func scrollToTop() {
        prompterView.scrollOffset = 0
        prompterView.overlay.showToast("처음으로")
    }

    /// 현재 설정된 단축키 전체를 화면에 띄운다(8초 후 자동으로 사라짐).
    func toggleCheatSheet() {
        let lines = HotkeyAction.allCases.map { action -> (String, String) in
            let key = HotkeyManager.shared.hotkeyConfigs[action]?.displayString ?? "-"
            let failed = HotkeyManager.shared.failedActions.contains(action)
            return (key, action.name + (failed ? "  ⚠ 등록 실패" : ""))
        }
        prompterView.overlay.toggleCheatSheet(lines)
    }

    /// 대본의 제목(#, ##, …) 단위로 건너뛴다. 긴 대본에서 원하는 대목을 찾는 가장 빠른 길.
    func jumpSection(forward: Bool) {
        guard let moved = prompterView.jumpToSection(forward: forward) else {
            let reason = prompterView.sectionAnchors.isEmpty
                ? "섹션 없음 (제목 줄 # 을 쓰면 생깁니다)"
                : (forward ? "마지막 섹션" : "첫 섹션")
            prompterView.overlay.showToast(reason)
            return
        }
        prompterView.overlay.showToast("섹션 \(moved.index)/\(moved.total)")
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
        applyClickThroughState()
        prompterView.overlay.showToast(isClickThrough ? "클릭 통과 ON" : "클릭 통과 OFF")
    }

    /// 창의 마우스 통과 여부와 상태 뱃지를 현재 값에 맞춘다.
    /// 클릭 통과가 켜지면 창을 클릭할 수도 휠로 스크롤할 수도 없어 탈출 수단이 단축키뿐이므로,
    /// 해제 방법을 **상시** 보여 준다. (배경 어둡기는 didSet -> applyWindowChrome 이 처리)
    func applyClickThroughState() {
        window?.ignoresMouseEvents = isClickThrough
        let key = HotkeyManager.shared.hotkeyConfigs[.toggleClickThrough]?.displayString ?? ""
        prompterView.overlay.badgeText = isClickThrough ? "클릭 통과 중 · \(key) 로 해제" : nil
    }

    func speedUp() {
        scrollSpeed = min(200, scrollSpeed + 20)
        settingsController?.updateSpeedDisplay(scrollSpeed)
        // 설정 창을 닫아 둔 상태에서도 바뀐 걸 알 수 있어야 한다(예전엔 알 방법이 없었다).
        prompterView.overlay.showToast("속도 \(Int(scrollSpeed))")
        updateRemainingTime()
    }

    func speedDown() {
        scrollSpeed = max(10, scrollSpeed - 20)
        settingsController?.updateSpeedDisplay(scrollSpeed)
        prompterView.overlay.showToast("속도 \(Int(scrollSpeed))")
        updateRemainingTime()
    }

    /// 배경색·투명도·클릭스루를 한 곳에서 계산한다.
    /// 예전에는 두 경로가 나뉘어 있어, 클릭스루 ON 상태에서 투명도를 만지면
    /// "입력이 통과 중"이라는 유일한 시각 신호(어두워짐)가 사라졌다.
    func applyWindowChrome() {
        let alpha = isClickThrough ? backgroundOpacity * 0.5 : backgroundOpacity
        window?.backgroundColor = backgroundColor.withAlphaComponent(alpha)
    }

    // MARK: NSWindowDelegate

    func windowDidMove(_ notification: Notification) {
        saveWindowFrame()
        scheduleEdgeSnap()
    }

    func windowDidResize(_ notification: Notification) { saveWindowFrame() }

    // MARK: 창 배치

    /// 화면 가장자리에 가까우면 딱 붙인다.
    ///
    /// windowDidMove 는 드래그 내내 연속으로 오므로 그 자리에서 프레임을 고치면 사용자의 드래그와
    /// 싸우게 된다. 움직임이 멈춘 뒤(150ms)에만 스냅하도록 디바운스한다.
    private func scheduleEdgeSnap() {
        snapWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.snapToEdges() }
        snapWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }

    private func snapToEdges() {
        guard let window = window, let screen = window.screen ?? NSScreen.main else { return }
        let threshold: CGFloat = 20
        let visible = screen.visibleFrame
        var frame = window.frame

        if abs(frame.minX - visible.minX) < threshold { frame.origin.x = visible.minX }
        if abs(frame.maxX - visible.maxX) < threshold { frame.origin.x = visible.maxX - frame.width }
        if abs(frame.minY - visible.minY) < threshold { frame.origin.y = visible.minY }
        if abs(frame.maxY - visible.maxY) < threshold { frame.origin.y = visible.maxY - frame.height }

        guard frame != window.frame else { return }
        window.setFrame(frame, display: true, animate: false)
    }

    enum WindowPreset: String, CaseIterable {
        case small = "작게"
        case medium = "보통"
        case large = "크게"
        case bottomStrip = "하단 띠"
        case center = "화면 중앙"

        var size: NSSize? {
            switch self {
            case .small: return NSSize(width: 480, height: 280)
            case .medium: return NSSize(width: 720, height: 420)
            case .large: return NSSize(width: 1024, height: 560)
            case .bottomStrip, .center: return nil   // 화면에 따라 계산
            }
        }
    }

    /// 촬영 세팅마다 창 크기를 손으로 맞추는 수고를 없앤다.
    /// 특히 '하단 띠'는 카메라를 보면서 화면 아래쪽만 훑는 배치라 시선 이동이 가장 적다.
    func applyWindowPreset(_ preset: WindowPreset) {
        guard let window = window, let screen = window.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        var frame = window.frame

        switch preset {
        case .bottomStrip:
            frame.size = NSSize(width: visible.width * 0.8, height: 240)
            frame.origin = NSPoint(x: visible.minX + (visible.width - frame.width) / 2,
                                   y: visible.minY + 40)
        case .center:
            frame.origin = NSPoint(x: visible.midX - frame.width / 2,
                                   y: visible.midY - frame.height / 2)
        default:
            if let size = preset.size {
                frame.size = size
                frame.origin = NSPoint(x: visible.midX - size.width / 2,
                                       y: visible.midY - size.height / 2)
            }
        }

        window.setFrame(frame, display: true, animate: true)
        saveWindowFrame()
        prompterView.overlay.showToast(preset.rawValue)
    }

    func showSettings() {
        if settingsController == nil {
            settingsController = SettingsWindowController(prompterController: self)
        }
        // .accessory 앱은 자동 활성화되지 않으므로 명시적으로 올려야 키 입력을 받는다.
        NSApp.activate(ignoringOtherApps: true)
        settingsController?.showWindow(nil)
        settingsController?.window?.makeKeyAndOrderFront(nil)
        settingsController?.showRegistrationFailures()
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var prompterController: PrompterWindowController!
    var statusItem: NSStatusItem?
    private var stealthObserver: Any?
    private var resignObserver: Any?
    private var hotkeyFailureMenuItem: NSMenuItem?
    private var visibilityMenuItem: NSMenuItem?
    private var playMenuItem: NSMenuItem?
    private var clickThroughMenuItem: NSMenuItem?
    private var scriptMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 스텔스 가드를 창 생성보다 먼저 건다.
        installStealthGuard()

        // Create prompter window
        prompterController = PrompterWindowController()

        // 저장된 설정 복원. NSScreen 을 만지므로 반드시 여기(앱 기동 완료 후)에서 한다.
        prompterController.applyLoadedSettings(SettingsStore.shared.settings)
        // 대본은 전체 재파싱을 유발하므로 마지막에.
        prompterController.loadActiveScript()
        PrompterWindowController.debugFrame("after-script", prompterController.window?.frame ?? .zero)

        prompterController.showWindow(nil)
        PrompterWindowController.debugFrame("after-showWindow", prompterController.window?.frame ?? .zero)

        // Setup global hotkeys
        setupHotkeys()

        // Create menu bar item
        setupStatusItem()

        // Setup main menu
        setupMainMenu()

        installSaveTriggers()
    }

    /// 디바운스된 저장이 유실되지 않도록 확정 시점마다 즉시 기록한다.
    /// 특히 `willResignActive` — 촬영 직전 OBS/Zoom 으로 전환하는 순간이 사실상 "작업 확정"이다.
    private func installSaveTriggers() {
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willResignActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            SettingsStore.shared.flushNow()
            self?.prompterController?.flushScript()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        SettingsStore.shared.flushNow()
        prompterController?.flushScript()
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

        hotkeyManager.onScrollToTop = { [weak self] in
            self?.prompterController.scrollToTop()
        }

        hotkeyManager.onPreviousSection = { [weak self] in
            self?.prompterController.jumpSection(forward: false)
        }

        hotkeyManager.onNextSection = { [weak self] in
            self?.prompterController.jumpSection(forward: true)
        }

        hotkeyManager.onPasteClipboard = { [weak self] in
            self?.prompterController.replaceScriptFromClipboard()
        }

        hotkeyManager.onCheatSheet = { [weak self] in
            self?.prompterController.toggleCheatSheet()
        }

        hotkeyManager.registerHotkeys()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "☷"

        let menu = NSMenu()
        menu.delegate = self   // 열릴 때마다 실제 상태로 갱신

        visibilityMenuItem = NSMenuItem(title: "프롬프터 보이기", action: #selector(togglePrompter), keyEquivalent: "")
        playMenuItem = NSMenuItem(title: "재생", action: #selector(togglePlay), keyEquivalent: "")
        clickThroughMenuItem = NSMenuItem(title: "클릭 통과", action: #selector(toggleClickThrough), keyEquivalent: "")

        menu.addItem(visibilityMenuItem!)
        menu.addItem(playMenuItem!)
        menu.addItem(clickThroughMenuItem!)
        menu.addItem(NSMenuItem(title: "처음으로", action: #selector(scrollToTop), keyEquivalent: ""))

        let presetItem = NSMenuItem(title: "창 크기", action: nil, keyEquivalent: "")
        let presetMenu = NSMenu()
        for preset in PrompterWindowController.WindowPreset.allCases {
            let item = NSMenuItem(title: preset.rawValue, action: #selector(applyPreset(_:)), keyEquivalent: "")
            item.representedObject = preset.rawValue
            item.target = self
            presetMenu.addItem(item)
        }
        presetItem.submenu = presetMenu
        menu.addItem(presetItem)
        menu.addItem(NSMenuItem.separator())

        scriptMenuItem = NSMenuItem(title: "대본", action: nil, keyEquivalent: "")
        scriptMenuItem?.submenu = NSMenu()
        menu.addItem(scriptMenuItem!)
        menu.addItem(NSMenuItem(title: "클립보드를 대본으로", action: #selector(pasteClipboardAsScript), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "설정...", action: #selector(showSettings), keyEquivalent: ","))

        let maintenance = NSMenuItem(title: "설정 관리", action: nil, keyEquivalent: "")
        let maintenanceMenu = NSMenu()
        maintenanceMenu.addItem(NSMenuItem(title: "설정 내보내기...", action: #selector(exportSettings), keyEquivalent: ""))
        maintenanceMenu.addItem(NSMenuItem(title: "설정 가져오기...", action: #selector(importSettings), keyEquivalent: ""))
        maintenanceMenu.addItem(NSMenuItem.separator())
        maintenanceMenu.addItem(NSMenuItem(title: "모든 설정 초기화...", action: #selector(resetSettings), keyEquivalent: ""))
        maintenance.submenu = maintenanceMenu
        menu.addItem(maintenance)

        menu.addItem(NSMenuItem(title: "업데이트 확인...", action: #selector(checkForUpdates), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem?.menu = menu
        hotkeyFailureMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        hotkeyFailureMenuItem?.isEnabled = false
        refreshHotkeyFailureIndicator()
    }

    // MARK: NSMenuDelegate

    /// 메뉴를 열 때마다 현재 상태를 반영한다. 상태를 바꾸는 경로가 여럿(단축키·메뉴·설정창)이라
    /// 각 경로에서 메뉴를 갱신하려 들면 반드시 빠지는 곳이 생긴다.
    func menuWillOpen(_ menu: NSMenu) {
        guard let controller = prompterController else { return }
        let visible = controller.window?.isVisible ?? false
        visibilityMenuItem?.title = visible ? "프롬프터 숨기기" : "프롬프터 보이기"
        playMenuItem?.title = controller.isPlaying ? "일시정지" : "재생"
        playMenuItem?.state = controller.isPlaying ? .on : .off
        clickThroughMenuItem?.state = controller.isClickThrough ? .on : .off
        rebuildScriptMenu()
    }

    /// 대본 목록을 서브메뉴로 노출한다. 촬영 중에는 파일 열기 패널을 쓸 수 없으므로
    /// (별도 프로세스라 캡처에서 숨길 수 없다) 이 경로가 라이브 전환의 정식 수단이다.
    private func rebuildScriptMenu() {
        guard let submenu = scriptMenuItem?.submenu else { return }
        submenu.removeAllItems()

        let library = ScriptStore.loadLibrary()
        let activeID = prompterController?.activeScriptID
        if library.scripts.isEmpty {
            let empty = NSMenuItem(title: "(없음)", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            submenu.addItem(empty)
        }
        for meta in library.scripts.sorted(by: { $0.updatedAt > $1.updatedAt }) {
            let item = NSMenuItem(title: meta.title, action: #selector(switchScript(_:)), keyEquivalent: "")
            item.representedObject = meta.id
            item.state = (meta.id == activeID) ? .on : .off
            item.target = self
            submenu.addItem(item)
        }
        submenu.addItem(NSMenuItem.separator())
        let newItem = NSMenuItem(title: "새 대본", action: #selector(createScript), keyEquivalent: "")
        newItem.target = self
        submenu.addItem(newItem)
    }

    @objc func switchScript(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        prompterController?.switchToScript(id: id)
    }

    @objc func createScript() {
        prompterController?.createNewScript()
    }

    @objc func pasteClipboardAsScript() {
        prompterController?.replaceScriptFromClipboard()
    }

    /// 파일 패널은 별도 프로세스가 그려 sharingType 을 강제할 수 없다(= 캡처에 찍힌다).
    /// 그래서 이 기능들은 준비 단계 전용이며, 라이브 중에는 쓰지 않도록 안내한다.
    @objc func exportSettings() {
        guard let data = SettingsStore.shared.exportData() else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "ShadowCue-설정.json"
        panel.allowedContentTypes = [.json]
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try data.write(to: url, options: .atomic)
            prompterController?.prompterView.overlay.showToast("설정을 내보냈습니다")
        } catch {
            showWarning("설정을 저장하지 못했습니다", error.localizedDescription)
        }
    }

    @objc func importSettings() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url,
              let data = try? Data(contentsOf: url) else { return }

        guard SettingsStore.shared.importData(data) else {
            showWarning("가져오지 못했습니다", "이 파일은 ShadowCue 설정 형식이 아닙니다.")
            return
        }
        reapplySettingsEverywhere()
        prompterController?.prompterView.overlay.showToast("설정을 가져왔습니다")
    }

    @objc func resetSettings() {
        let alert = NSAlert()
        alert.messageText = "모든 설정을 초기화할까요?"
        alert.informativeText = "글자 크기·색상·속도·단축키·창 위치가 기본값으로 돌아갑니다.\n대본은 지워지지 않습니다."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "초기화")
        alert.addButton(withTitle: "취소")
        alert.window.sharingType = .none
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        SettingsStore.shared.resetAll()
        HotkeyManager.shared.applyStoredHotkeys([])
        for action in HotkeyAction.allCases {
            HotkeyManager.shared.hotkeyConfigs[action] =
                HotkeyConfig(keyCode: action.defaultKeyCode, modifiers: HotkeyAction.defaultModifiers)
        }
        HotkeyManager.shared.registerHotkeys()
        refreshHotkeyFailureIndicator()
        reapplySettingsEverywhere()
        prompterController?.prompterView.overlay.showToast("설정을 초기화했습니다")
    }

    /// 설정이 통째로 바뀌었을 때(가져오기·초기화) 화면과 설정 창을 다시 맞춘다.
    /// 설정 창은 컨트롤이 많아 개별 갱신보다 다시 만드는 편이 확실하다.
    private func reapplySettingsEverywhere() {
        guard let controller = prompterController else { return }
        controller.applyLoadedSettings(SettingsStore.shared.settings)
        let wasOpen = controller.settingsController?.window?.isVisible ?? false
        controller.settingsController?.close()
        controller.settingsController = nil
        if wasOpen { controller.showSettings() }
    }

    private func showWarning(_ title: String, _ detail: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = detail
        alert.alertStyle = .warning
        alert.window.sharingType = .none
        alert.runModal()
    }

    @objc func applyPreset(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let preset = PrompterWindowController.WindowPreset(rawValue: raw) else { return }
        prompterController?.applyWindowPreset(preset)
    }

    /// 단축키가 안 먹는 이유를 사용자가 알 수 있게 한다.
    /// 예전에는 등록 실패를 그냥 버려서, 아무 반응 없는 앱처럼 보였다.
    func refreshHotkeyFailureIndicator() {
        let failures = HotkeyManager.shared.failedActions
        statusItem?.button?.title = failures.isEmpty ? "☷" : "☷⚠"

        guard let menu = statusItem?.menu, let item = hotkeyFailureMenuItem else { return }
        let index = menu.index(of: item)
        if failures.isEmpty {
            if index >= 0 { menu.removeItem(item) }
        } else {
            item.title = "⚠ 단축키 \(failures.count)개 등록 실패 — 설정에서 변경"
            if index < 0 { menu.insertItem(item, at: 0) }
        }
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

    @objc func scrollToTop() {
        prompterController.scrollToTop()
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

/// 영속성의 두 가지 치명적 전제를 검사한다.
/// 1) 기본 색(.white/.black)에서 성분 접근이 크래시하지 않을 것
/// 2) 필드가 빠지거나 타입이 깨진 옛 블롭이 **통째로** 실패하지 않을 것
func runPersistenceSelfTest() -> Bool {
    var pass = true
    func check(_ label: String, _ condition: Bool) {
        print("\(condition ? "PASS" : "FAIL") \(label)")
        if !condition { pass = false }
    }

    // (1) 기본 색 — 예전 방식(redComponent 직접 접근)이면 여기서 프로세스가 죽는다.
    let white = RGBA(NSColor.white)
    let black = RGBA(NSColor.black)
    check("RGBA(.white) 변환", white != nil && white!.r == 1 && white!.a == 1)
    check("RGBA(.black) 변환", black != nil && black!.r == 0)
    check("RGBA 왕복", RGBA(NSColor.white)?.nsColor.usingColorSpace(.sRGB)?.redComponent == 1)

    // (2) 전방호환 — 필드 2개짜리 구버전 블롭
    let legacy = #"{"schema":1,"fontSize":48}"#.data(using: .utf8)!
    if let decoded = try? JSONDecoder().decode(Settings.self, from: legacy) {
        check("구버전 블롭 디코드 성공", true)
        check("있는 필드 유지 (fontSize=48)", decoded.fontSize == 48)
        check("없는 필드 기본값 (scrollSpeed=50)", decoded.scrollSpeed == 50)
        check("없는 필드 기본값 (textColor=white)", decoded.textColor == .white)
        check("없는 옵셔널 nil (windowFrame)", decoded.windowFrame == nil)
    } else {
        check("구버전 블롭 디코드 성공", false)
    }

    // (3) 타입이 깨진 값은 그 필드만 버린다
    let corrupt = #"{"fontSize":"엄청큼","scrollSpeed":120}"#.data(using: .utf8)!
    if let decoded = try? JSONDecoder().decode(Settings.self, from: corrupt) {
        check("깨진 필드만 폴백 (fontSize=32)", decoded.fontSize == 32)
        check("멀쩡한 필드는 유지 (scrollSpeed=120)", decoded.scrollSpeed == 120)
    } else {
        check("깨진 블롭에서도 디코드 성공", false)
    }

    // (4) 전체 왕복
    var original = Settings()
    original.fontSize = 44
    original.windowFrame = [10, 20, 800, 600]
    original.hotkeys = [HotkeyRecord(action: 1, keyCode: 36, modifiers: 4096)]
    if let data = try? JSONEncoder().encode(original),
       let back = try? JSONDecoder().decode(Settings.self, from: data) {
        check("전체 왕복 동일", back == original)
    } else {
        check("전체 왕복 동일", false)
    }

    // (5) 실제 UserDefaults 왕복 — SHADOWCUE_DEFAULTS_SUITE 가 지정된 경우에만.
    //     (지정 안 하면 사용자의 실제 환경설정을 건드리게 되므로 건너뛴다)
    if ProcessInfo.processInfo.environment["SHADOWCUE_DEFAULTS_SUITE"] != nil {
        let store = SettingsStore.shared
        check("최초 실행으로 인식", store.isFirstLaunch)
        store.update { $0.fontSize = 61; $0.scrollSpeed = 137 }
        store.flushNow()
        check("디스크 기록됨", UserDefaults(suiteName: ProcessInfo.processInfo.environment["SHADOWCUE_DEFAULTS_SUITE"]!)?
            .data(forKey: "settings.v1") != nil)
        // 같은 값 재대입은 재저장을 유발하지 않아야 한다(Equatable 가드)
        let before = store.settings
        store.update { $0.fontSize = 61 }
        check("같은 값 재대입은 무시", store.settings == before)

        // 내보내기 -> 초기화 -> 가져오기 왕복
        store.update { $0.fontSize = 55; $0.mirrorHorizontal = true; $0.maxLineWidth = 800 }
        let exported = store.exportData()
        check("내보내기 성공", exported != nil)
        store.resetAll()
        check("초기화되어 기본값", store.settings.fontSize == 32 && !store.settings.mirrorHorizontal)
        if let exported {
            check("가져오기 성공", store.importData(exported))
            check("가져온 값 복원", store.settings.fontSize == 55
                  && store.settings.mirrorHorizontal
                  && store.settings.maxLineWidth == 800)
        }
        check("깨진 파일 거부", !store.importData(Data("이건 JSON 이 아니다".utf8)))
    }
    return pass
}

/// 설정 창이 모든 컨트롤을 담고 있는지(잘리지 않는지) 검사한다.
/// 단축키 행이 7개에서 11개로 늘면서 고정 높이(850)를 넘겨 아래쪽이 잘렸었다.
func runSettingsLayoutSelfTest() -> Bool {
    let controller = PrompterWindowController()
    let settings = SettingsWindowController(prompterController: controller)
    guard let scrollView = settings.window?.contentView as? NSScrollView,
          let document = scrollView.documentView else {
        print("FAIL 설정 창 구성")
        return false
    }
    let lowest = document.subviews.map { $0.frame.minY }.min() ?? 0
    let highest = document.subviews.map { $0.frame.maxY }.max() ?? 0
    let ok = lowest >= 0 && highest <= document.frame.height + 0.5
    print("\(ok ? "PASS" : "FAIL") 설정 창 레이아웃 "
          + "(높이 \(Int(document.frame.height)), 컨트롤 \(document.subviews.count)개, "
          + "최하단 y=\(Int(lowest)), 최상단 y=\(Int(highest)))")
    return ok
}

/// 미러 반전이 실제로 좌표를 뒤집는지 검사한다.
/// 반전 ON 이면 컨테이너의 (0,0) 이 부모 좌표계의 오른쪽 끝으로 가야 한다.
func runMirrorSelfTest() -> Bool {
    let view = PrompterView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
    view.layoutSubtreeIfNeeded()

    guard let normal = view.mirrorProbe() else {
        print("FAIL 미러 프로브 없음")
        return false
    }
    let normalOK = abs(normal.topLeftMapsTo.x - 0) < 1

    view.mirrorHorizontal = true
    guard let mirrored = view.mirrorProbe() else { return false }
    let mirroredOK = abs(mirrored.topLeftMapsTo.x - mirrored.size.width) < 1

    view.mirrorHorizontal = false
    guard let restored = view.mirrorProbe() else { return false }
    let restoredOK = abs(restored.topLeftMapsTo.x - 0) < 1

    let ok = normalOK && mirroredOK && restoredOK
    print("\(ok ? "PASS" : "FAIL") 미러 반전 "
          + "(기본 x=\(Int(normal.topLeftMapsTo.x)), "
          + "반전 x=\(Int(mirrored.topLeftMapsTo.x))/폭 \(Int(mirrored.size.width)), "
          + "복귀 x=\(Int(restored.topLeftMapsTo.x)))")
    return ok
}

// MARK: - Main
if CommandLine.arguments.contains("--selftest") {
    _ = NSApplication.shared   // AppKit 뷰 생성에 필요
    runInlineMarkdownSelfTest()
    print("")
    for action in HotkeyAction.allCases {
        print("HOTKEY \(action.name): \(action.defaultDisplayString)")
    }
    print("")
    let persistenceOK = runPersistenceSelfTest()
    let layoutOK = runSettingsLayoutSelfTest()
    let mirrorOK = runMirrorSelfTest()
    exit(persistenceOK && layoutOK && mirrorOK ? 0 : 1)
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
