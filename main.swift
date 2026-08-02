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
    // 새 액션을 추가할 때 고칠 곳: 이 enum / `name` / `defaultKeyCode` /
    // HotkeyManager 의 콜백 프로퍼티 + `callback(for:)` / AppDelegate 배선.
    //
    // 앞의 넷은 **컴파일러가 강제한다**(전부 enum 위 exhaustive switch다).
    // 예전에는 Carbon 콜백 안에서 UInt32 를 switch 해서 한 곳을 빠뜨려도 컴파일이 통과했고,
    // 그러면 등록은 되는데 눌러도 아무 일이 없었다. 그 switch 를 없앴다.
    // 컴파일러가 못 잡는 건 AppDelegate 배선 하나뿐이다 — 새 액션을 넣고 눌러 보라.
    case scrollToTop = 8
    case previousSection = 9
    case nextSection = 10
    case pasteClipboard = 11
    case cheatSheet = 12
    case showLibrary = 13

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
        case .showLibrary: return "대본 라이브러리"
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
        // L = Library. 남아 있는 글자 중 니모닉이 가장 분명하고, 한국어 macOS 의
        // 공장 기본 단축키와도 겹치지 않는다.
        case .showLibrary: return UInt32(kVK_ANSI_L)
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

    // 대본 라이브러리 창 — 문서가 아니라 UI 상태이므로 library.json 이 아니라 여기에 둔다.
    var libraryWindowFrame: [Double]?
    var librarySidebarWidth: Double = 260
    var libraryExpandedFolderIDs: [String] = []
    /// 사이드바 선택 복원용. **`activeScriptID` 와 의도적으로 별개다** —
    /// 라이브러리에서 대본을 골라 보는 것과 그 대본을 프롬프터에 올리는 것은 다른 행동이다.
    var libraryLastSelectedID: String?

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
        libraryWindowFrame       = value(.libraryWindowFrame, fallback.libraryWindowFrame)
        librarySidebarWidth      = value(.librarySidebarWidth, fallback.librarySidebarWidth)
        libraryExpandedFolderIDs = value(.libraryExpandedFolderIDs, fallback.libraryExpandedFolderIDs)
        libraryLastSelectedID    = value(.libraryLastSelectedID, fallback.libraryLastSelectedID)
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

/// 배열 원소 하나가 깨져도 나머지를 살리는 래퍼.
///
/// `[ScriptMeta].self` 로 한 번에 디코드하면 원소 하나 때문에 배열 전체가 throw 되고,
/// 그러면 대본 300개짜리 라이브러리가 메타 하나 깨졌다고 통째로 사라진다.
private struct Lenient<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws { value = try? T(from: decoder) }
}

/// 모델 타입들은 **전부 손으로 쓴 `init(from:)`** 을 갖는다.
///
/// 합성 디코더는 프로퍼티 기본값을 쓰지 않아서, 필드를 하나만 추가해도 그 키가 없는 기존 파일이
/// `keyNotFound` 로 통째로 디코드 실패한다. `Settings`(위쪽)가 같은 이유로 이미 손으로 쓴
/// 디코더를 갖고 있는데, 대본 쪽은 합성 디코더라 v2 필드를 추가하는 순간 v1 파일이 전부
/// "읽기 실패 → 빈 라이브러리" 로 떨어졌을 것이다. 그 경로의 끝은 색인 전소다(ScriptStore 주석 참조).
struct ScriptMeta: Codable, Equatable {
    var id: String
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var lastScrollOffset: Double = 0
    /// nil = 최상위. **없는 폴더를 가리켜도 버리지 않는다** — 트리 빌더가 최상위로 승격시킨다.
    var folderID: String? = nil
    /// 같은 부모 안에서의 순서. 이동·삭제 후 형제끼리 0..n-1 로 재정규화한다.
    var sortIndex: Int = 0

    init(id: String, title: String, createdAt: Date, updatedAt: Date,
         lastScrollOffset: Double = 0, folderID: String? = nil, sortIndex: Int = 0) {
        self.id = id; self.title = title
        self.createdAt = createdAt; self.updatedAt = updatedAt
        self.lastScrollOffset = lastScrollOffset
        self.folderID = folderID; self.sortIndex = sortIndex
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // id 와 title 은 없으면 이 항목을 살릴 수 없다 — 여기서만 throw 하고(= Lenient 가 이 원소만 버림),
        // 나머지 필드는 개별 폴백한다.
        id = try c.decode(String.self, forKey: .id)
        title = ((try? c.decodeIfPresent(String.self, forKey: .title)) ?? nil) ?? "제목 없음"
        createdAt = ((try? c.decodeIfPresent(Date.self, forKey: .createdAt)) ?? nil) ?? Date()
        updatedAt = ((try? c.decodeIfPresent(Date.self, forKey: .updatedAt)) ?? nil) ?? createdAt
        lastScrollOffset = ((try? c.decodeIfPresent(Double.self, forKey: .lastScrollOffset)) ?? nil) ?? 0
        folderID = (try? c.decodeIfPresent(String.self, forKey: .folderID)) ?? nil
        sortIndex = ((try? c.decodeIfPresent(Int.self, forKey: .sortIndex)) ?? nil) ?? 0
    }
}

/// 폴더 = 대본 분류(중첩 가능).
///
/// **파일시스템 디렉터리와 대응시키지 않는다.** 본문은 계속 `scripts/<uuid>.md` 평면 구조로 두고
/// 폴더는 색인에만 존재한다. 실제 디렉터리로 만들면 이름 변경·이동마다 파일 이동이 따라붙고,
/// 그 도중에 프로세스가 죽으면 색인과 디스크가 어긋나 복구가 어려워진다.
struct ScriptFolder: Codable, Equatable {
    var id: String
    var name: String
    var parentID: String? = nil
    var sortIndex: Int = 0
    var createdAt: Date
    var updatedAt: Date

    init(id: String, name: String, parentID: String? = nil, sortIndex: Int = 0,
         createdAt: Date, updatedAt: Date) {
        self.id = id; self.name = name; self.parentID = parentID
        self.sortIndex = sortIndex; self.createdAt = createdAt; self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = ((try? c.decodeIfPresent(String.self, forKey: .name)) ?? nil) ?? "이름 없는 폴더"
        parentID = (try? c.decodeIfPresent(String.self, forKey: .parentID)) ?? nil
        sortIndex = ((try? c.decodeIfPresent(Int.self, forKey: .sortIndex)) ?? nil) ?? 0
        createdAt = ((try? c.decodeIfPresent(Date.self, forKey: .createdAt)) ?? nil) ?? Date()
        updatedAt = ((try? c.decodeIfPresent(Date.self, forKey: .updatedAt)) ?? nil) ?? createdAt
    }
}

/// 보드 = 촬영용 묶음(대본 여러 개를 순서대로). **이 버전에는 UI 도 CRUD API 도 없다.**
///
/// 그런데도 지금 필드를 넣는 이유는 하나다: 이 버전 코드가 `library.json` 을 디코드-재인코드 하는
/// 순간, 모르는 최상위 키는 조용히 사라진다. 지금 자리를 비워 두어야 다음 버전에서 만든 보드가
/// 이 버전으로 한 번 되돌아가도 살아남고, 마이그레이션을 v3 로 또 하지 않아도 된다.
///
/// `scriptIDs` 가 소유가 아니라 **참조**인 것도 의도다 — 같은 대본이 여러 보드에 들어갈 수 있다.
struct ScriptBoard: Codable, Equatable {
    var id: String
    var name: String
    var scriptIDs: [String] = []
    var sortIndex: Int = 0
    var createdAt: Date
    var updatedAt: Date
    var notes: String = ""

    init(id: String, name: String, scriptIDs: [String] = [], sortIndex: Int = 0,
         createdAt: Date, updatedAt: Date, notes: String = "") {
        self.id = id; self.name = name; self.scriptIDs = scriptIDs
        self.sortIndex = sortIndex; self.createdAt = createdAt
        self.updatedAt = updatedAt; self.notes = notes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = ((try? c.decodeIfPresent(String.self, forKey: .name)) ?? nil) ?? "이름 없는 보드"
        scriptIDs = ((try? c.decodeIfPresent([String].self, forKey: .scriptIDs)) ?? nil) ?? []
        sortIndex = ((try? c.decodeIfPresent(Int.self, forKey: .sortIndex)) ?? nil) ?? 0
        createdAt = ((try? c.decodeIfPresent(Date.self, forKey: .createdAt)) ?? nil) ?? Date()
        updatedAt = ((try? c.decodeIfPresent(Date.self, forKey: .updatedAt)) ?? nil) ?? createdAt
        notes = ((try? c.decodeIfPresent(String.self, forKey: .notes)) ?? nil) ?? ""
    }
}

struct ScriptLibrary: Codable, Equatable {
    /// v1: scripts 만. v2: folders/boards + ScriptMeta.folderID/sortIndex.
    static let currentVersion = 2

    var version: Int = ScriptLibrary.currentVersion
    var scripts: [ScriptMeta] = []
    var folders: [ScriptFolder] = []
    var boards: [ScriptBoard] = []

    init() {}

    init(version: Int, scripts: [ScriptMeta], folders: [ScriptFolder] = [], boards: [ScriptBoard] = []) {
        self.version = version; self.scripts = scripts
        self.folders = folders; self.boards = boards
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // 버전 키가 없으면 v1 이다(v1 파일에는 version 이 있지만, 없어도 v1 로 보는 게 안전하다).
        version = ((try? c.decodeIfPresent(Int.self, forKey: .version)) ?? nil) ?? 1
        scripts = (((try? c.decodeIfPresent([Lenient<ScriptMeta>].self, forKey: .scripts)) ?? nil) ?? [])
            .compactMap(\.value)
        folders = (((try? c.decodeIfPresent([Lenient<ScriptFolder>].self, forKey: .folders)) ?? nil) ?? [])
            .compactMap(\.value)
        boards = (((try? c.decodeIfPresent([Lenient<ScriptBoard>].self, forKey: .boards)) ?? nil) ?? [])
            .compactMap(\.value)
    }
}

/// `library.json` 을 읽은 결과의 신뢰도.
///
/// **최초 실행과 로드 실패를 반드시 구분해야 한다.** 둘 다 "빈 라이브러리" 로 보이지만,
/// 전자는 써도 되고 후자는 쓰면 안 된다. 구분은 파일 존재 여부로만 한다
/// (`ensureActiveScript()` 가 이미 같은 원칙을 쓴다).
enum LibraryLoadState: Equatable {
    case fresh                                  // 파일 없음 = 진짜 최초 실행. 쓰기 허용
    case ok
    case repaired(dropped: Int)                 // 원소 일부만 버림. 쓰기 허용
    case corruptTopLevel(preserved: URL?)       // 통째로 못 읽음. 쓰기 차단
    case futureVersion(Int)                     // 이 빌드보다 새 포맷. 쓰기 차단

    /// 이 상태에서 색인을 덮어쓰면 데이터가 사라지는가.
    var blocksWrites: Bool {
        switch self {
        case .corruptTopLevel, .futureVersion: return true
        case .fresh, .ok, .repaired: return false
        }
    }
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

> \(HotkeyAction.showLibrary.defaultDisplayString) 로 대본 라이브러리를 열어 편집하세요.
> 입력하면 바로 반영됩니다.
"""

    /// `SHADOWCUE_SUPPORT_DIR` 는 테스트가 **사용자의 진짜 대본 라이브러리를 건드리지 않게** 하는 훅이다.
    ///
    /// `SHADOWCUE_DEFAULTS_SUITE` 로 설정만 격리하면 부족했다: 격리된 도메인에는 `activeScriptID` 가
    /// 없으니 `ensureActiveScript()` 가 매 실행마다 새 UUID 로 "기본 대본" 을 만들어 **공용 경로**에
    /// 쌓았다. 실제로 검증 몇 번에 내용이 똑같은 "기본 대본" 이 다섯 개 생겼다(2026-08-02).
    /// 격리는 설정과 문서 **양쪽**에 걸어야 한다.
    static var baseURL: URL {
        if let override = ProcessInfo.processInfo.environment["SHADOWCUE_SUPPORT_DIR"],
           !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return root.appendingPathComponent("ShadowCue", isDirectory: true)
    }
    static var scriptsURL: URL { baseURL.appendingPathComponent("scripts", isDirectory: true) }
    static var libraryURL: URL { baseURL.appendingPathComponent("library.json") }
    /// 삭제한 대본이 잠시 머무는 곳. 지우는 게 아니라 옮기는 것이라 되돌릴 수 있다.
    static var trashURL: URL { baseURL.appendingPathComponent("trash", isDirectory: true) }

    static func prepare() {
        try? FileManager.default.createDirectory(at: scriptsURL, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: trashURL, withIntermediateDirectories: true)
    }

    // MARK: 색인 신뢰도

    /// 색인을 신뢰할 수 없을 때 래치된다. 한 번 켜지면 어떤 경로로도 `library.json` 을 쓰지 않는다.
    ///
    /// **이 래치가 없으면 "대본을 열어 보기만 해도" 목록이 날아간다.** 경로는 이렇다:
    ///   디코드 실패 → 빈 라이브러리 → `saveScrollOffset`(스크롤 1pt만 움직여도 불린다)의
    ///   read-modify-write → `saveLibrary(빈 것)` → 색인 전소.
    /// `.md` 본문은 남지만 목록에서 전부 사라지므로 사용자 입장에선 대본을 잃은 것과 같다.
    private(set) static var isWriteBlocked = false
    private(set) static var lastLoadState: LibraryLoadState = .fresh

    /// 셀프테스트 전용 — 격리 디렉터리를 갈아엎은 뒤 래치를 푼다.
    static func resetWriteBlockForTest() {
        isWriteBlocked = false
        lastLoadState = .fresh
    }

    /// 사용자가 "디스크에서 복구" 를 선택했을 때만 부른다.
    static func unblockWritesAfterRecovery() { isWriteBlocked = false }

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

    /// 색인을 읽고 **얼마나 믿을 수 있는지까지** 돌려준다. 부작용으로 쓰기 래치를 갱신한다.
    @discardableResult
    static func loadLibraryDetailed() -> (library: ScriptLibrary, state: LibraryLoadState) {
        func finish(_ library: ScriptLibrary, _ state: LibraryLoadState) -> (ScriptLibrary, LibraryLoadState) {
            lastLoadState = state
            // 래치는 켜지기만 하고 스스로 꺼지지 않는다. 한 번 의심스러운 파일을 본 실행에서는
            // 이후 어떤 로드가 성공해도 쓰지 않는다(부분 성공에 속아 덮어쓰는 걸 막는다).
            if state.blocksWrites { isWriteBlocked = true }
            return (library, state)
        }

        guard FileManager.default.fileExists(atPath: libraryURL.path) else {
            return finish(ScriptLibrary(), .fresh)      // 최초 실행 — 쓰기 허용
        }
        guard let data = try? Data(contentsOf: libraryURL) else {
            return finish(ScriptLibrary(), .corruptTopLevel(preserved: preserveCorruptLibrary()))
        }
        guard let library = try? JSONDecoder().decode(ScriptLibrary.self, from: data) else {
            return finish(ScriptLibrary(), .corruptTopLevel(preserved: preserveCorruptLibrary()))
        }
        if library.version > ScriptLibrary.currentVersion {
            // 최신 버전에서 만든 파일이다. 이 빌드가 모르는 키(보드 등)를 지우지 않도록 쓰지 않는다.
            return finish(library, .futureVersion(library.version))
        }

        // 최상위는 읽혔지만 원소가 버려졌는지 본다. 모델에 개수를 담지 않고 여기서 원본과 대조한다
        // (모델을 순수하게 유지하려고 — Equatable/Codable 에 진단용 필드가 섞이면 왕복 비교가 깨진다).
        let dropped = droppedElementCount(rawData: data, decoded: library)
        if dropped > 0 {
            _ = preserveCorruptLibrary()                // 버려진 원소를 되살릴 수 있게 원본 보존
            return finish(library, .repaired(dropped: dropped))
        }
        return finish(library, .ok)
    }

    /// 기존 호출부를 그대로 두기 위해 시그니처를 유지한다.
    static func loadLibrary() -> ScriptLibrary { loadLibraryDetailed().library }

    /// 원본 JSON 의 배열 길이와 디코드 결과 길이를 비교해 버려진 원소 수를 센다.
    private static func droppedElementCount(rawData: Data, decoded: ScriptLibrary) -> Int {
        guard let root = try? JSONSerialization.jsonObject(with: rawData) as? [String: Any] else { return 0 }
        func rawCount(_ key: String) -> Int { (root[key] as? [Any])?.count ?? 0 }
        let d = (rawCount("scripts") - decoded.scripts.count)
              + (rawCount("folders") - decoded.folders.count)
              + (rawCount("boards")  - decoded.boards.count)
        return max(0, d)
    }

    /// 의심스러운 색인을 타임스탬프 붙여 **복사**한다(원본은 그대로 둔다 — 손으로 고칠 수 있게).
    @discardableResult
    private static func preserveCorruptLibrary() -> URL? {
        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let dest = baseURL.appendingPathComponent("library.corrupt-\(stamp).json")
        guard !FileManager.default.fileExists(atPath: dest.path) else { return dest }
        do {
            try FileManager.default.copyItem(at: libraryURL, to: dest)
            return dest
        } catch { return nil }
    }

    @discardableResult
    static func saveLibrary(_ library: ScriptLibrary) -> Bool {
        guard !isWriteBlocked else { return false }     // ← 색인 소실을 막는 단 하나의 가드
        prepare()
        // 본문(`write(id:text:)`)과 같은 규칙으로 직전 세대를 하나 남긴다.
        if FileManager.default.fileExists(atPath: libraryURL.path) {
            let backup = libraryURL.appendingPathExtension("bak")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.copyItem(at: libraryURL, to: backup)
        }
        guard let data = try? JSONEncoder().encode(library) else { return false }
        do {
            try data.write(to: libraryURL, options: .atomic)
            return true
        } catch { return false }
    }

    /// 최종 안전망 — `scripts/*.md` 를 훑어 색인을 재구성한다.
    ///
    /// 폴더 구조는 잃지만 **대본은 하나도 잃지 않는다.** 이 함수가 있기 때문에
    /// 마이그레이션이 `.md` 를 건드리지 않는 한, 최악의 경우에도 되돌릴 수 있다.
    static func rebuildLibraryFromDisk() -> ScriptLibrary {
        prepare()
        let fm = FileManager.default
        let urls = (try? fm.contentsOfDirectory(at: scriptsURL,
                                                includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey]))
            ?? []
        var metas: [ScriptMeta] = []
        for url in urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
        where url.pathExtension == "md" {
            let id = url.deletingPathExtension().lastPathComponent
            let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            let values = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
            let created = values?.creationDate ?? Date()
            metas.append(ScriptMeta(id: id,
                                    title: derivedTitle(from: text, fallbackIndex: metas.count + 1),
                                    createdAt: created,
                                    updatedAt: values?.contentModificationDate ?? created,
                                    sortIndex: metas.count))
        }
        return ScriptLibrary(version: ScriptLibrary.currentVersion, scripts: metas)
    }

    /// 본문에서 제목을 유추한다: 첫 `# ` 헤딩 → 첫 비어 있지 않은 줄 → "복구된 대본 N".
    static func derivedTitle(from text: String, fallbackIndex: Int) -> String {
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            if line.hasPrefix("#") {
                let stripped = line.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
                if !stripped.isEmpty { return String(stripped.prefix(40)) }
            }
            return String(line.prefix(40))
        }
        return "복구된 대본 \(fallbackIndex)"
    }

    // MARK: 구조 변경 (폴더·대본 CRUD)

    /// **모든 구조 변경은 이 한 곳을 통과한다.**
    ///
    /// - 쓰기 차단 상태에서 조용히 성공하지 않는다(false 를 돌려준다).
    /// - `body` 가 false 를 돌려주면 아무것도 쓰지 않는다(검증 실패 = 무변경).
    /// - 성공 시 형제끼리 sortIndex 를 0..n-1 로 재정규화한다. 순서가 항상 정칙이라
    ///   테스트가 `[1,2,0]` 같은 기대값을 그대로 쓸 수 있고, 중복 인덱스가 쌓이지 않는다.
    @discardableResult
    private static func mutate(_ body: (inout ScriptLibrary) -> Bool) -> Bool {
        guard !isWriteBlocked else { return false }
        var library = loadLibrary()
        guard body(&library) else { return false }
        normalizeOrder(&library)
        return saveLibrary(library)
    }

    private static func normalizeOrder(_ library: inout ScriptLibrary) {
        // 폴더와 대본은 같은 부모 안에서 각각 0..n-1 을 갖는다(트리 빌더가 폴더를 앞에 놓는다).
        func renumberFolders(parent: String?) {
            let ids = library.folders
                .filter { $0.parentID == parent }
                .sorted { $0.sortIndex < $1.sortIndex }
                .map(\.id)
            for (order, id) in ids.enumerated() {
                if let i = library.folders.firstIndex(where: { $0.id == id }) {
                    library.folders[i].sortIndex = order
                }
            }
        }
        func renumberScripts(folder: String?) {
            let ids = library.scripts
                .filter { $0.folderID == folder }
                .sorted { $0.sortIndex < $1.sortIndex }
                .map(\.id)
            for (order, id) in ids.enumerated() {
                if let i = library.scripts.firstIndex(where: { $0.id == id }) {
                    library.scripts[i].sortIndex = order
                }
            }
        }
        var parents: [String?] = [nil]
        parents.append(contentsOf: library.folders.map { Optional($0.id) })
        for parent in parents { renumberFolders(parent: parent); renumberScripts(folder: parent) }
    }

    /// 같은 부모 안에서 뒤쪽으로 옮길 때의 인덱스 보정.
    ///
    /// **`at:` 은 "최종 위치" 가 아니라 "원래 목록 기준 삽입 지점" 이다** —
    /// `NSOutlineView` 의 `acceptDrop(item:childIndex:)` 이 주는 좌표계에 맞춘 것이다.
    /// `[A,B,C]` 에서 A 를 `at: 2` 로 옮기면 "B 와 C 사이" 라는 뜻이므로 `[B,A,C]` 가 되고,
    /// 맨 끝은 `at: 3` 이다. 두 규약을 헷갈리면 드래그가 항상 한 칸씩 어긋난다.
    ///
    /// 보정이 필요한 이유: 옮길 원소를 목록에서 먼저 빼면, 그 원소보다 뒤에 있던 삽입 지점이
    /// 한 칸 당겨진다. 앞쪽으로 옮길 때(`target <= old`)는 당겨지지 않으므로 보정하지 않는다.
    private static func adjustedIndex(_ target: Int, movingFrom old: Int, sameParent: Bool) -> Int {
        (sameParent && target > old) ? target - 1 : target
    }

    /// 대상 폴더의 조상 사슬에 `id` 가 있는지. 순환 이동을 막는다.
    private static func isDescendant(_ candidate: String?, of ancestorID: String,
                                     in library: ScriptLibrary) -> Bool {
        var cursor = candidate
        var guardCount = 0
        while let current = cursor, guardCount < 1000 {
            if current == ancestorID { return true }
            cursor = library.folders.first(where: { $0.id == current })?.parentID
            guardCount += 1
        }
        return false
    }

    // ── 폴더 ────────────────────────────────────────────────────────

    @discardableResult
    static func createFolder(name: String, parentID: String? = nil) -> ScriptFolder? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var created: ScriptFolder?
        let ok = mutate { library in
            if let parent = parentID,
               !library.folders.contains(where: { $0.id == parent }) { return false }
            let now = Date()
            let next = library.folders.filter { $0.parentID == parentID }.count
            let folder = ScriptFolder(id: UUID().uuidString, name: trimmed, parentID: parentID,
                                      sortIndex: next, createdAt: now, updatedAt: now)
            library.folders.append(folder)
            created = folder
            return true
        }
        return ok ? created : nil
    }

    @discardableResult
    static func renameFolder(id: String, to name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }       // 빈 이름은 목록에서 사라진 것처럼 보인다
        return mutate { library in
            guard let i = library.folders.firstIndex(where: { $0.id == id }) else { return false }
            library.folders[i].name = trimmed
            library.folders[i].updatedAt = Date()
            return true
        }
    }

    /// `at` 이 nil 이면 맨 끝.
    @discardableResult
    static func moveFolder(id: String, toParent parentID: String?, at index: Int? = nil) -> Bool {
        mutate { library in
            guard let current = library.folders.first(where: { $0.id == id }) else { return false }
            if let parent = parentID,
               !library.folders.contains(where: { $0.id == parent }) { return false }
            // 자기 자신이나 자손 안으로 넣으면 트리가 끊겨 대본이 통째로 사라진 것처럼 보인다.
            guard !isDescendant(parentID, of: id, in: library) else { return false }

            let sameParent = current.parentID == parentID
            let siblings = library.folders
                .filter { $0.parentID == parentID && $0.id != id }
                .sorted { $0.sortIndex < $1.sortIndex }
                .map(\.id)
            let oldIndex = library.folders
                .filter { $0.parentID == parentID }
                .sorted { $0.sortIndex < $1.sortIndex }
                .firstIndex(of: current) ?? siblings.count
            var order = siblings
            let target = min(max(0, adjustedIndex(index ?? order.count, movingFrom: oldIndex,
                                                  sameParent: sameParent)), order.count)
            order.insert(id, at: target)

            guard let i = library.folders.firstIndex(where: { $0.id == id }) else { return false }
            library.folders[i].parentID = parentID
            library.folders[i].updatedAt = Date()
            for (position, folderID) in order.enumerated() {
                if let j = library.folders.firstIndex(where: { $0.id == folderID }) {
                    library.folders[j].sortIndex = position
                }
            }
            return true
        }
    }

    enum FolderDeleteStrategy {
        /// 안에 있던 것을 부모로 끌어올린다(기본 — 실수로 지워도 내용은 남는다).
        case promoteChildren
        /// 안에 있던 대본까지 휴지통으로.
        case deleteContents
    }

    @discardableResult
    static func deleteFolder(id: String, strategy: FolderDeleteStrategy = .promoteChildren) -> DeletedBundle? {
        var bundle: DeletedBundle?
        let ok = mutate { library in
            guard let target = library.folders.first(where: { $0.id == id }) else { return false }
            let descendants = descendantFolderIDs(of: id, in: library)
            let affected = descendants.union([id])

            switch strategy {
            case .promoteChildren:
                for i in library.folders.indices where library.folders[i].parentID == id {
                    library.folders[i].parentID = target.parentID
                }
                for i in library.scripts.indices where library.scripts[i].folderID == id {
                    library.scripts[i].folderID = target.parentID
                }
                library.folders.removeAll { $0.id == id }
                bundle = DeletedBundle(folders: [target], scripts: [], deletedAt: Date())

            case .deleteContents:
                let doomedFolders = library.folders.filter { affected.contains($0.id) }
                let doomedScripts = library.scripts.filter { affected.contains($0.folderID ?? "") }
                var moved: [(ScriptMeta, URL?)] = []
                for meta in doomedScripts {
                    moved.append((meta, moveToTrash(id: meta.id)))
                }
                library.folders.removeAll { affected.contains($0.id) }
                library.scripts.removeAll { affected.contains($0.folderID ?? "") }
                bundle = DeletedBundle(folders: doomedFolders, scripts: moved, deletedAt: Date())
            }
            return true
        }
        if !ok, let pending = bundle {
            // 색인 저장이 실패했으면 옮긴 파일을 되돌린다(파일과 색인이 어긋나면 안 된다).
            for (_, url) in pending.scripts { restoreFromTrash(url) }
            return nil
        }
        return ok ? bundle : nil
    }

    private static func descendantFolderIDs(of id: String, in library: ScriptLibrary) -> Set<String> {
        var result: Set<String> = []
        var queue = [id]
        while let current = queue.popLast() {
            for child in library.folders where child.parentID == current && !result.contains(child.id) {
                result.insert(child.id)
                queue.append(child.id)
            }
        }
        return result
    }

    // ── 대본 ────────────────────────────────────────────────────────

    @discardableResult
    static func createScript(title: String, in folderID: String? = nil, text: String = "") -> String? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let id = UUID().uuidString
        guard write(id: id, text: text) else { return nil }
        let ok = mutate { library in
            if let folder = folderID,
               !library.folders.contains(where: { $0.id == folder }) { return false }
            let now = Date()
            let next = library.scripts.filter { $0.folderID == folderID }.count
            library.scripts.append(ScriptMeta(id: id, title: trimmed.isEmpty ? "새 대본" : trimmed,
                                              createdAt: now, updatedAt: now,
                                              folderID: folderID, sortIndex: next))
            return true
        }
        if !ok {
            // 색인에 못 넣었으면 방금 만든 파일을 남기지 않는다(목록에 없는 유령 파일 방지).
            try? FileManager.default.removeItem(at: url(for: id))
            return nil
        }
        return id
    }

    @discardableResult
    static func renameScript(id: String, to title: String) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return mutate { library in
            guard let i = library.scripts.firstIndex(where: { $0.id == id }) else { return false }
            library.scripts[i].title = trimmed
            library.scripts[i].updatedAt = Date()
            return true
        }
    }

    @discardableResult
    static func moveScript(id: String, toFolder folderID: String?, at index: Int? = nil) -> Bool {
        mutate { library in
            guard let current = library.scripts.first(where: { $0.id == id }) else { return false }
            if let folder = folderID,
               !library.folders.contains(where: { $0.id == folder }) { return false }

            let sameParent = current.folderID == folderID
            let siblings = library.scripts
                .filter { $0.folderID == folderID && $0.id != id }
                .sorted { $0.sortIndex < $1.sortIndex }
                .map(\.id)
            let oldIndex = library.scripts
                .filter { $0.folderID == folderID }
                .sorted { $0.sortIndex < $1.sortIndex }
                .firstIndex(where: { $0.id == id }) ?? siblings.count
            var order = siblings
            let target = min(max(0, adjustedIndex(index ?? order.count, movingFrom: oldIndex,
                                                  sameParent: sameParent)), order.count)
            order.insert(id, at: target)

            guard let i = library.scripts.firstIndex(where: { $0.id == id }) else { return false }
            library.scripts[i].folderID = folderID
            library.scripts[i].updatedAt = Date()
            for (position, scriptID) in order.enumerated() {
                if let j = library.scripts.firstIndex(where: { $0.id == scriptID }) {
                    library.scripts[j].sortIndex = position
                }
            }
            return true
        }
    }

    @discardableResult
    static func deleteScript(id: String) -> DeletedBundle? {
        guard !isWriteBlocked else { return nil }
        var meta: ScriptMeta?
        var trashed: URL?
        // 파일을 먼저 옮기고 색인을 고친다. 순서가 반대면 색인에서 사라진 뒤 파일 이동이 실패해
        // 목록에 없는 유령 파일이 남는다.
        guard let existing = loadLibrary().scripts.first(where: { $0.id == id }) else { return nil }
        meta = existing
        trashed = moveToTrash(id: id)

        let ok = mutate { library in
            library.scripts.removeAll { $0.id == id }
            return true
        }
        guard ok, let m = meta else {
            restoreFromTrash(trashed)      // 색인 저장 실패 → 파일 원위치
            return nil
        }
        return DeletedBundle(folders: [], scripts: [(m, trashed)], deletedAt: Date())
    }

    @discardableResult
    static func duplicateScript(id: String) -> String? {
        guard let source = loadLibrary().scripts.first(where: { $0.id == id }) else { return nil }
        return createScript(title: source.title + " 사본", in: source.folderID,
                            text: read(id: id) ?? "")
    }

    @discardableResult
    static func restore(_ bundle: DeletedBundle) -> Bool {
        guard !isWriteBlocked else { return false }
        let library = loadLibrary()
        // 같은 id 가 이미 있으면 되살리지 않는다(중복 생성 방지).
        guard !bundle.scripts.contains(where: { entry in
            library.scripts.contains { $0.id == entry.meta.id }
        }) else { return false }

        for (_, url) in bundle.scripts { restoreFromTrash(url) }
        return mutate { lib in
            for folder in bundle.folders where !lib.folders.contains(where: { $0.id == folder.id }) {
                lib.folders.append(folder)
            }
            for (meta, _) in bundle.scripts where !lib.scripts.contains(where: { $0.id == meta.id }) {
                lib.scripts.append(meta)
            }
            return true
        }
    }

    /// 되돌리기 스냅샷. 본문을 메모리에 들고 있지 않고 **휴지통 파일 URL 만** 들고 있는다.
    struct DeletedBundle {
        var folders: [ScriptFolder]
        var scripts: [(meta: ScriptMeta, trashedFile: URL?)]
        var deletedAt: Date
    }

    /// 지우지 않고 옮긴다(rename 이라 원자적이고, 복사와 달리 중간 상태가 없다).
    private static func moveToTrash(id: String) -> URL? {
        prepare()
        let source = url(for: id)
        guard FileManager.default.fileExists(atPath: source.path) else { return nil }
        let stamp = Int(Date().timeIntervalSince1970)
        let dest = trashURL.appendingPathComponent("\(id)-\(stamp).md")
        try? FileManager.default.removeItem(at: dest)
        do {
            try FileManager.default.moveItem(at: source, to: dest)
            try? FileManager.default.removeItem(at: source.appendingPathExtension("bak"))
            return dest
        } catch { return nil }
    }

    private static func restoreFromTrash(_ trashed: URL?) {
        guard let trashed, FileManager.default.fileExists(atPath: trashed.path) else { return }
        // 파일명이 <id>-<epoch>.md 이므로 마지막 하이픈 앞이 id 다.
        let base = trashed.deletingPathExtension().lastPathComponent
        guard let cut = base.lastIndex(of: "-") else { return }
        let id = String(base[base.startIndex..<cut])
        prepare()
        let dest = url(for: id)
        try? FileManager.default.removeItem(at: dest)
        try? FileManager.default.moveItem(at: trashed, to: dest)
    }

    /// 휴지통이 무한히 커지지 않게 기동 때 한 번 솎는다.
    /// 되돌리기는 며칠 안에 하는 행동이므로 30일이면 넉넉하고, 개수 상한을 함께 두어
    /// 하루에 수십 개를 지운 경우에도 디스크가 계속 불어나지 않게 한다.
    static func pruneTrash(keepDays: Int = 30, keepCount: Int = 50) {
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(at: trashURL,
                                                     includingPropertiesForKeys: [.contentModificationDateKey])
        else { return }
        let dated = urls.map { url -> (URL, Date) in
            let d = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            return (url, d ?? .distantPast)
        }.sorted { $0.1 > $1.1 }        // 최신 먼저

        let cutoff = Date().addingTimeInterval(-Double(keepDays) * 86_400)
        for (index, entry) in dated.enumerated() where index >= keepCount || entry.1 < cutoff {
            try? fm.removeItem(at: entry.0)
        }
    }

    // MARK: 마이그레이션

    /// v1 → v2. **`library.json` 에만 손댄다. `scripts/*.md` 는 읽지도 쓰지도 않는다.**
    ///
    /// 반드시 `loadActiveScript()` 보다 **먼저** 불러야 한다. 그 경로가
    /// `ensureActiveScript → touch → saveLibrary` 로 이어져 v1 파일 위에 v2 를 얹어 버리기 때문이다.
    @discardableResult
    static func migrateIfNeeded() -> Bool {
        let (library, state) = loadLibraryDetailed()
        // 의심스러운 파일은 건드리지 않는다. 마이그레이션이야말로 덮어쓰기이므로 가장 위험하다.
        guard !state.blocksWrites else { return false }
        guard state != .fresh else { return false }         // 쓸 게 없다
        guard library.version < ScriptLibrary.currentVersion else { return false }   // 멱등

        // v1 원본을 한 번만 남긴다(이미 있으면 덮어쓰지 않는다 — 두 번째 실행이 첫 백업을 지우면 안 된다).
        let v1Backup = baseURL.appendingPathComponent("library.v\(library.version).json")
        if !FileManager.default.fileExists(atPath: v1Backup.path) {
            try? FileManager.default.copyItem(at: libraryURL, to: v1Backup)
        }

        var migrated = library
        migrated.version = ScriptLibrary.currentVersion
        migrated.folders = []
        migrated.boards = []
        // 기존 배열 순서를 그대로 순서로 굳힌다(그 전엔 순서 개념 자체가 없었다).
        for index in migrated.scripts.indices {
            migrated.scripts[index].folderID = nil
            migrated.scripts[index].sortIndex = index
        }
        // 실패해도 차단하지 않는다 — v1 파일이 그대로 남아 있고 v2 디코더가 v1 을 읽을 수 있어
        // 기능적 손실이 없다. 다음 실행에 다시 시도한다.
        return saveLibrary(migrated)
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

        // ① 저장된 대본이 아직 있으면 그것
        if let id = storedID, exists(id: id) {
            return (id, read(id: id) ?? "")
        }

        // ② 없으면 **남아 있는 대본 중 최신**으로 넘어간다.
        //    라이브러리에서 활성 대본을 지우면 여기로 오는데, 곧장 ③으로 가면 멀쩡한 대본 옆에
        //    데모 대본이 새로 생긴다. 격리 도메인으로 테스트를 돌릴 때마다 내용이 똑같은
        //    "기본 대본" 이 다섯 개 쌓였던 것과 같은 종류의 사고다(build.sh 주석 참조).
        let survivors = loadLibrary().scripts
            .filter { exists(id: $0.id) }
            .sorted { $0.updatedAt > $1.updatedAt }
        if let next = survivors.first {
            SettingsStore.shared.update { $0.activeScriptID = next.id }
            return (next.id, read(id: next.id) ?? "")
        }

        // ③ 하나도 없을 때만 새로 만든다
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
    var onShowLibrary: (() -> Void)?

    /// 부팅 시 등록에 실패한 액션(다른 앱이 이미 그 조합을 잡고 있는 경우 등).
    private(set) var failedActions: Set<HotkeyAction> = []

    /// 액션 → 콜백. **이 switch 는 enum 위에서 돌기 때문에 case 를 빠뜨리면 컴파일이 실패한다.**
    ///
    /// 예전에는 Carbon 콜백 안에서 `hotKeyID.id`(UInt32)를 switch 했다. 숫자 위 switch 라
    /// `default: break` 가 있어야 하고, 그러면 **case 를 안 넣어도 컴파일이 통과한다** —
    /// 단축키는 등록되는데 눌러도 아무 일이 없고 원인을 찾기 어렵다.
    /// (enum 정의부 주석이 "4곳을 함께 고쳐야 한다" 고 경고하던 자리 중 하나다)
    func callback(for action: HotkeyAction) -> (() -> Void)? {
        switch action {
        case .togglePlay: return onTogglePlay
        case .scrollUp: return onScrollUp
        case .scrollDown: return onScrollDown
        case .toggleVisibility: return onToggleVisibility
        case .toggleClickThrough: return onToggleClickThrough
        case .speedUp: return onSpeedUp
        case .speedDown: return onSpeedDown
        case .scrollToTop: return onScrollToTop
        case .previousSection: return onPreviousSection
        case .nextSection: return onNextSection
        case .pasteClipboard: return onPasteClipboard
        case .cheatSheet: return onCheatSheet
        case .showLibrary: return onShowLibrary
        }
    }

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
                    // 분기는 여기서 하지 않는다 — callback(for:) 하나만 두어야 액션을 추가할 때
                    // 컴파일러가 누락을 잡아 준다(위 주석 참조).
                    guard let action = HotkeyAction(rawValue: Int(hotKeyID.id)) else { return }
                    HotkeyManager.shared.callback(for: action)?()
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
    /// 치트시트 외형. 셀프테스트가 이 값들을 그대로 검사하므로 상수로 둔다.
    static let cheatSheetFontSize: CGFloat = 15
    static let cheatSheetPadding: CGFloat = 14
    /// 뒤의 대본이 비치지 않을 만큼 불투명해야 한다.
    static let cheatSheetBackgroundAlpha: CGFloat = 0.96

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

        // 배경이 반투명하면 뒤의 대본(32~72pt)이 그대로 비쳐 목록을 못 읽는다.
        // 이건 잠깐 띄웠다 지우는 패널이라 불투명해도 대본을 가리는 손해가 없다.
        cheatSheetLabel.font = NSFont.monospacedSystemFont(ofSize: Self.cheatSheetFontSize, weight: .regular)
        cheatSheetLabel.alignment = .left
        cheatSheetLabel.maximumNumberOfLines = 0
        cheatSheetLabel.wantsLayer = true
        cheatSheetLabel.layer?.cornerRadius = 10
        cheatSheetLabel.layer?.borderWidth = 1
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
        cheatSheetLabel.layer?.backgroundColor = NSColor.black.withAlphaComponent(Self.cheatSheetBackgroundAlpha).cgColor
        cheatSheetLabel.layer?.borderColor = base.withAlphaComponent(0.28).cgColor
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
            // size 에는 왼쪽 들여쓰기가 이미 포함되므로 오른쪽 몫만 더한다.
            let boxWidth = min(width - 32, size.width + Self.cheatSheetPadding)
            let boxHeight = min(height - 32, size.height + Self.cheatSheetPadding)
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

        // NSTextField 는 내부 여백이 없어 글자가 패널 모서리에 붙는다. 들여쓰기로 여백을 만든다.
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        paragraph.firstLineHeadIndent = Self.cheatSheetPadding
        paragraph.headIndent = Self.cheatSheetPadding
        cheatSheetLabel.attributedStringValue = NSAttributedString(string: body, attributes: [
            .font: cheatSheetLabel.font ?? NSFont.monospacedSystemFont(ofSize: Self.cheatSheetFontSize,
                                                                       weight: .regular),
            .foregroundColor: cheatSheetLabel.textColor ?? NSColor.white,
            .paragraphStyle: paragraph,
        ])
        cheatSheetLabel.isHidden = false
        needsLayout = true

        cheatSheetHideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.hideCheatSheet() }
        cheatSheetHideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: work)
    }

    /// 셀프테스트용 — 치트시트가 떠 있으면 그 프레임, 아니면 nil.
    var cheatSheetFrameForTest: NSRect? {
        cheatSheetLabel.isHidden ? nil : cheatSheetLabel.frame
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
    var onLibrary: (() -> Void)?

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
        // 창이 좁으면 스트립이 fittingWidth 보다 작게 잘리는데, 그때 버튼이 둥근 배경 밖으로
        // 삐져나가 대본 위에 떠다닌다. 버튼이 하나 늘 때마다 이 경계는 더 자주 걸린다.
        layer?.masksToBounds = true
        alphaValue = 0

        playButton = addButton("▶︎") { [weak self] in self?.onTogglePlay?() }
        _ = addButton("느리게") { [weak self] in self?.onSlower?() }
        _ = addButton("빠르게") { [weak self] in self?.onFaster?() }
        _ = addButton("가")     { [weak self] in self?.onSmaller?() }
        _ = addButton("가+")    { [weak self] in self?.onBigger?() }
        _ = addButton("처음")   { [weak self] in self?.onTop?() }
        _ = addButton("대본")   { [weak self] in self?.onLibrary?() }
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
    ///
    /// **레이아웃 패스마다 다시 걸어야 한다.** AppKit 은 관리 대상 레이어의 지오메트리를
    /// 뷰 기준으로 되돌리는데(실측: anchorPoint→(0,0), position→(0,0), transform→identity),
    /// 그때 반전이 통째로 사라진다. 한 번 걸어두는 것으로는 유지되지 않아 `layout()` 에서 다시 건다.
    private func applyMirrorTransform() {
        guard let layer = flipContainer.layer else { return }
        let size = flipContainer.bounds.size
        guard size.width > 0, size.height > 0 else { return }

        // 레이아웃 패스에서 불리므로 암묵적 애니메이션을 끈다(끄지 않으면 창을 움직일 때마다
        // 대본이 0.25초씩 흐물거린다).
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        layer.transform = CATransform3DIdentity
        layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        layer.bounds = CGRect(origin: .zero, size: size)
        layer.position = CGPoint(x: flipContainer.frame.midX, y: flipContainer.frame.midY)

        guard mirrorHorizontal || mirrorVertical else { return }
        layer.transform = CATransform3DMakeScale(mirrorHorizontal ? -1 : 1,
                                                 mirrorVertical ? -1 : 1, 1)
    }

    /// 레이아웃 패스가 일어나지 않는 경로(대표적으로 창 이동)에서 반전을 다시 걸기 위한 진입점.
    func reapplyMirror() { applyMirrorTransform() }

    /// 셀프테스트용 — AppKit 이 레이어 지오메트리를 뷰 기준으로 되돌리는 상황을 재현한다.
    ///
    /// 실기기 계측(2026-08-02)에서 확인한 실제 값이다: AppKit 은 관리 대상 레이어의
    /// `anchorPoint`·`position`·`transform` 을 통째로 초기화한다. `layer.frame` 만 되쓰는 게
    /// 아니라서(frame 대입은 transform 을 보존한다) 그것만으로는 이 버그가 재현되지 않는다.
    /// 미러가 이 되돌림 뒤에 스스로 복구되는지가 회귀 테스트의 핵심이다.
    func simulateAppKitGeometrySync() {
        guard let layer = flipContainer.layer else { return }
        layer.transform = CATransform3DIdentity
        layer.anchorPoint = CGPoint(x: 0, y: 0)
        layer.position = .zero
        layer.bounds = CGRect(origin: .zero, size: flipContainer.frame.size)
        layout()   // AppKit 의 레이아웃 패스가 뒤따르는 지점
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

    /// 미러 transform 은 **여기서** 다시 건다.
    ///
    /// `setFrameSize` 에서만 걸었더니 저장된 미러 설정이 첫 실행에 적용되지 않았다(v1.2 버그):
    /// 복원은 `applicationDidFinishLaunching` 의 `applyLoadedSettings` → `showWindow` 순서인데,
    /// showWindow 는 크기를 바꾸지 않으므로 setFrameSize 가 안 불리고, 그 사이 AppKit 이
    /// 레이어 지오메트리를 되돌려 transform 만 조용히 사라졌다.
    /// (그래서 "창을 한 번 리사이즈하면 그제서야 반전되는" 증상이었다)
    ///
    /// 창 **이동**은 크기가 안 바뀌어 여기로 오지 않으므로 `windowDidMove` 에서 따로 다시 건다.
    override func layout() {
        super.layout()
        applyMirrorTransform()
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

/// `.accessory` 앱은 메뉴바를 띄우지 않아 Edit 메뉴의 키 등가물(⌘C/V/X/A/Z)이 동작하지 않을 수 있다.
///
/// 대본을 붙여넣는 창에서 ⌘V 가 안 먹으면 앱이 통째로 쓸모없어지므로, 우리 창이 키 윈도우일 때만
/// 도는 로컬 모니터로 폴백한다. **설정 창과 라이브러리 창이 공용으로 쓴다** — 복붙하면 두 벌이 되고,
/// 한쪽만 고치는 사고가 난다.
final class EditKeyFallback {
    private var monitor: Any?

    /// `window` 를 클로저로 받는 이유: 컨트롤러가 창을 나중에 만들거나 교체해도 따라가야 한다.
    init(window: @escaping () -> NSWindow?) {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard let target = window(), target.isKeyWindow,
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
        if let monitor { NSEvent.removeMonitor(monitor) }
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
    private var editKeyFallback: EditKeyFallback?
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
        editKeyFallback = EditKeyFallback(window: { [weak self] in self?.window })
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

// MARK: - Script Library Window Controller

/// 대본을 폴더로 정리하고 큰 편집기에서 고치는 창.
///
/// **이 창은 촬영 중에 열린다.** 그래서 프롬프터 창과 같은 급으로 다룬다 —
/// 캡처 제외, 전체화면 위로 뜨는 창 레벨, 최소화 차단.
///
/// 한 가지 규칙이 UI 전체를 지배한다: **선택은 전환이 아니다.**
/// 사이드바에서 대본을 클릭하는 것이 라이브 프롬퍼터를 바꿔 버리면 카메라 앞에서 사고가 난다.
/// 전환은 더블클릭 / ⌘Return / 명시적 버튼으로만 일어난다.
final class ScriptLibraryWindowController: NSWindowController, NSWindowDelegate, NSSplitViewDelegate,
                                           NSOutlineViewDataSource, NSOutlineViewDelegate,
                                           NSTextViewDelegate, NSTextFieldDelegate, NSMenuDelegate {
    /// **weak 이어야 한다.** 프롬프터가 settingsController 를 strong 으로 잡고 있어 이미 순환이 있고
    /// (AppDelegate 가 프롬프터를 영구 보유해서 증상이 안 났을 뿐이다), 라이브러리 창은 닫혔다
    /// 열렸다 하므로 같은 실수를 반복하면 실제로 샌다.
    weak var prompterController: PrompterWindowController?

    private var splitView: NSSplitView!
    private var outlineView: NSOutlineView!
    private var editorTextView: FineUndoTextView!
    private var editorScrollView: NSScrollView!
    private var titleField: NSTextField!
    private var loadButton: NSButton!
    private var statusLabel: NSTextField!
    private var warningLabel: NSTextField!

    private var roots: [LibraryNode] = []
    private var editingScriptID: String?
    /// 프로그램적으로 텍스트를 대입하는 구간. 이 사이의 textDidChange 는 사용자 입력이 아니다.
    private var isApplyingExternalChange = false
    private var previewWork: DispatchWorkItem?
    private var inactiveWriteWork: DispatchWorkItem?
    private var editKeyFallback: EditKeyFallback?
    /// 컨텍스트 메뉴에서 "새 …" 를 만들 위치. menuNeedsUpdate 가 정하고 액션이 읽는다.
    private var newItemDestination: String?

    private static let sidebarColumnID = NSUserInterfaceItemIdentifier("name")

    // MARK: 생성

    convenience init(prompterController: PrompterWindowController) {
        let stored = SettingsStore.shared.settings.libraryWindowFrame
        let frame = (stored?.count == 4)
            ? NSRect(x: stored![0], y: stored![1], width: stored![2], height: stored![3])
            : NSRect(x: 0, y: 0, width: 960, height: 640)

        let window = NSWindow(contentRect: frame,
                              styleMask: [.titled, .closable, .resizable],
                              backing: .buffered, defer: false)
        window.title = "대본 라이브러리"
        window.minSize = NSSize(width: 640, height: 420)

        // 촬영 중에 여는 창이다. 스텔스는 여기서 직접 건다 —
        // installStealthGuard 의 didUpdate 감시는 창이 처음 표시된 **뒤에** 오므로 백스톱일 뿐이다.
        window.sharingType = .none

        // 일반 레벨이면 전체화면 Zoom/OBS 뒤로 숨어 "단축키를 눌렀는데 아무 일도 안 일어난다" 로 보인다.
        // 프롬프터(statusWindow+1000)보다는 낮게 둬서 대본을 가리지 않는다.
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false

        // 최소화는 styleMask 에 `.miniaturizable` 을 **넣지 않는 것**으로 막는다(버튼은 흐리게 남는다).
        // 막아야 하는 이유는 둘이다: `.accessory` 앱이라 Dock 에 되돌릴 자리가 없고,
        // Dock 축소판은 sharingType 보호를 못 받아 녹화에 대본 제목이 찍힌다.
        //
        // ⚠️ 버튼을 `isHidden` 으로 감추면 안 된다 — 그 자리가 비면서 macOS 26 의 좌측 정렬
        // 창 제목이 확대 버튼 위로 겹쳐 그려진다(실기기 확인, 2026-08-02).
        // 프롬프터 창은 창 자체가 안 보이므로 감춰도 되지만 여기는 보이는 창이다.

        if stored == nil { window.center() }

        self.init(window: window)
        self.prompterController = prompterController
        window.delegate = self
        setupUI()
        editKeyFallback = EditKeyFallback(window: { [weak self] in self?.window })
        refreshTree()
        restoreSelection()
    }

    // MARK: 레이아웃 (오토레이아웃을 쓰지 않는다 — 파일 전체가 스프링&스트럿이다)

    private func setupUI() {
        guard let window = window, let content = window.contentView else { return }

        splitView = NSSplitView(frame: content.bounds)
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.autoresizingMask = [.width, .height]
        splitView.delegate = self

        // ── 좌: 폴더 트리 ──────────────────────────────
        let sidebarWidth = CGFloat(SettingsStore.shared.settings.librarySidebarWidth)
        let outlineScroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: sidebarWidth,
                                                       height: content.bounds.height))
        outlineScroll.hasVerticalScroller = true
        outlineScroll.autohidesScrollers = true
        outlineScroll.borderType = .noBorder

        outlineView = NSOutlineView(frame: outlineScroll.bounds)
        let column = NSTableColumn(identifier: Self.sidebarColumnID)
        column.width = sidebarWidth - 8
        column.resizingMask = .autoresizingMask
        outlineView.addTableColumn(column)
        // ⚠️ 이 대입을 빠뜨리면 화면이 통째로 비어 보인다(데이터 소스는 정상인데 아무것도 안 그림).
        outlineView.outlineTableColumn = column
        outlineView.headerView = nil
        outlineView.rowSizeStyle = .default
        outlineView.style = .sourceList
        outlineView.allowsMultipleSelection = true
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.target = self
        outlineView.doubleAction = #selector(loadSelectedIntoPrompter)
        let contextMenu = NSMenu()
        contextMenu.delegate = self       // 열릴 때마다 재구성(선택 상태에 따라 항목이 달라진다)
        outlineView.menu = contextMenu
        outlineScroll.documentView = outlineView

        // ── 우: 헤더 + 편집기 + 상태줄 ──────────────────
        let rightWidth = content.bounds.width - sidebarWidth - splitView.dividerThickness
        let right = NSView(frame: NSRect(x: 0, y: 0, width: rightWidth, height: content.bounds.height))

        let headerHeight: CGFloat = 44
        let footerHeight: CGFloat = 28

        titleField = NSTextField(frame: NSRect(x: 12, y: right.bounds.height - headerHeight + 10,
                                               width: rightWidth - 160, height: 24))
        titleField.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        titleField.isBordered = false
        titleField.drawsBackground = false
        titleField.isEditable = false          // 이름 변경은 커밋 5에서
        titleField.stringValue = ""
        titleField.autoresizingMask = [.width, .minYMargin]
        right.addSubview(titleField)

        loadButton = NSButton(title: "프롬프터에 올리기", target: self,
                              action: #selector(loadSelectedIntoPrompter))
        loadButton.bezelStyle = .rounded
        loadButton.frame = NSRect(x: rightWidth - 148, y: right.bounds.height - headerHeight + 8,
                                  width: 136, height: 26)
        loadButton.keyEquivalent = "\r"
        loadButton.keyEquivalentModifierMask = [.command]
        loadButton.autoresizingMask = [.minXMargin, .minYMargin]
        right.addSubview(loadButton)

        warningLabel = NSTextField(labelWithString: "")
        warningLabel.frame = NSRect(x: 12, y: right.bounds.height - headerHeight - 2,
                                    width: rightWidth - 24, height: 16)
        warningLabel.font = NSFont.systemFont(ofSize: 11)
        warningLabel.textColor = .systemOrange
        warningLabel.autoresizingMask = [.width, .minYMargin]
        warningLabel.isHidden = true
        right.addSubview(warningLabel)

        editorScrollView = NSScrollView(frame: NSRect(x: 0, y: footerHeight,
                                                      width: rightWidth,
                                                      height: right.bounds.height - headerHeight - footerHeight))
        editorScrollView.hasVerticalScroller = true
        editorScrollView.borderType = .noBorder
        editorScrollView.autoresizingMask = [.width, .height]

        editorTextView = FineUndoTextView(frame: editorScrollView.bounds)
        editorTextView.minSize = NSSize(width: 0, height: 0)
        editorTextView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                        height: CGFloat.greatestFiniteMagnitude)
        editorTextView.isVerticallyResizable = true
        editorTextView.isHorizontallyResizable = false
        editorTextView.autoresizingMask = [.width]
        editorTextView.isEditable = false        // 선택 전에는 비활성
        editorTextView.isRichText = false
        editorTextView.allowsUndo = true
        editorTextView.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        editorTextView.textContainerInset = NSSize(width: 12, height: 12)
        // 스마트 따옴표가 들어가면 마크다운 파서가 흔들린다(`**굵게**` 의 별표와 달리 눈에 안 띈다).
        editorTextView.isAutomaticQuoteSubstitutionEnabled = false
        editorTextView.isAutomaticDashSubstitutionEnabled = false
        editorTextView.isAutomaticTextReplacementEnabled = false
        editorTextView.delegate = self
        editorScrollView.documentView = editorTextView
        right.addSubview(editorScrollView)

        statusLabel = NSTextField(labelWithString: "대본을 선택하세요")
        statusLabel.frame = NSRect(x: 12, y: 6, width: rightWidth - 24, height: 16)
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.autoresizingMask = [.width, .maxYMargin]
        right.addSubview(statusLabel)

        splitView.addSubview(outlineScroll)
        splitView.addSubview(right)
        content.addSubview(splitView)

        updateWarningBar()
    }

    /// 색인을 못 써서 저장이 안 되는 상태를 상시 표시한다. 조용히 넘어가면
    /// 사용자는 "고쳤는데 다음에 열면 원래대로" 를 반복하게 된다.
    private func updateWarningBar() {
        guard ScriptStore.isWriteBlocked else {
            warningLabel.isHidden = true
            return
        }
        warningLabel.stringValue = "⚠︎ 대본 목록이 손상되어 저장이 잠겨 있습니다. 편집 내용이 유지되지 않습니다."
        warningLabel.isHidden = false
    }

    // MARK: NSSplitViewDelegate

    /// 기본 비례 분배면 창을 키울 때 사이드바도 같이 넓어진다. 사이드바는 고정, 편집기가 흡수한다.
    func splitView(_ sv: NSSplitView, resizeSubviewsWithOldSize oldSize: NSSize) {
        guard sv.subviews.count == 2 else { return }
        let width = max(0, min(sv.subviews[0].frame.width, sv.bounds.width - 200))
        let divider = sv.dividerThickness
        sv.subviews[0].frame = NSRect(x: 0, y: 0, width: width, height: sv.bounds.height)
        sv.subviews[1].frame = NSRect(x: width + divider, y: 0,
                                      width: max(0, sv.bounds.width - width - divider),
                                      height: sv.bounds.height)
    }

    func splitView(_ sv: NSSplitView, constrainMinCoordinate proposed: CGFloat,
                   ofSubviewAt index: Int) -> CGFloat { 180 }
    func splitView(_ sv: NSSplitView, constrainMaxCoordinate proposed: CGFloat,
                   ofSubviewAt index: Int) -> CGFloat { 420 }

    func splitViewDidResizeSubviews(_ notification: Notification) {
        guard let first = splitView?.subviews.first else { return }
        SettingsStore.shared.update { $0.librarySidebarWidth = Double(first.frame.width) }
    }

    // MARK: 트리 갱신

    /// 펼침/선택을 보존하며 통째로 다시 그린다.
    ///
    /// 증분 갱신을 쓰지 않는 이유는 `LibraryNode` 주석 참조 — 매번 새 객체라 증분 API 와
    /// 조합하면 "이미 지운 항목 참조" 크래시가 나기 쉽다.
    func refreshTree() {
        // 창을 막 만든 시점에는 아웃라인에 행이 하나도 없어서 "지금 펼쳐진 폴더" 를 물어봐야 답이 없다.
        // 그 빈 답을 그대로 저장하면 **지난 실행의 펼침 상태가 통째로 지워지고**,
        // 폴더가 다 접힌 채로 뜨니 그 안의 대본은 행 자체가 없어 선택 복원까지 조용히 실패한다.
        // 그래서 첫 빌드에서는 반드시 설정에 남아 있는 값을 씨앗으로 삼는다.
        let expanded = outlineView.numberOfRows > 0
            ? expandedFolderIDs()
            : SettingsStore.shared.settings.libraryExpandedFolderIDs
        let selected = selectedNodeIDs()

        roots = LibraryTree.build(from: ScriptStore.loadLibrary())
        outlineView.reloadData()

        var byID: [String: LibraryNode] = [:]
        func index(_ nodes: [LibraryNode]) {
            for node in nodes { byID[node.id] = node; index(node.children) }
        }
        index(roots)

        for id in expanded {
            if let node = byID[id] { outlineView.expandItem(node) }
        }
        let rows = selected.compactMap { byID[$0] }.map { outlineView.row(forItem: $0) }.filter { $0 >= 0 }
        outlineView.selectRowIndexes(IndexSet(rows), byExtendingSelection: false)

        SettingsStore.shared.update { $0.libraryExpandedFolderIDs = expandedFolderIDs() }
        updateWarningBar()
    }

    /// **화면에 지금 펼쳐져 있는** 폴더. 아웃라인이 비어 있으면 빈 배열이다(설정값이 아니다) —
    /// 호출부가 그 차이를 알고 써야 한다.
    private func expandedFolderIDs() -> [String] {
        guard outlineView != nil else { return [] }
        var result: [String] = []
        for row in 0..<outlineView.numberOfRows {
            if let node = outlineView.item(atRow: row) as? LibraryNode,
               node.isFolder, outlineView.isItemExpanded(node) {
                result.append(node.id)
            }
        }
        return result
    }

    private func selectedNodeIDs() -> [String] {
        outlineView.selectedRowIndexes.compactMap {
            (outlineView.item(atRow: $0) as? LibraryNode)?.id
        }
    }

    private func restoreSelection() {
        // 저장된 선택이 없으면 활성 대본을 고른다 — 창을 열면 지금 쓰는 대본이 바로 보이게.
        let wanted = SettingsStore.shared.settings.libraryLastSelectedID
            ?? prompterController?.activeScriptID
        guard let wanted else { return }
        for row in 0..<outlineView.numberOfRows {
            if let node = outlineView.item(atRow: row) as? LibraryNode, node.id == wanted {
                outlineView.selectRowIndexes([row], byExtendingSelection: false)
                return
            }
        }
    }

    // MARK: NSOutlineViewDataSource

    func outlineView(_ ov: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        (item as? LibraryNode)?.children.count ?? roots.count
    }

    func outlineView(_ ov: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        (item as? LibraryNode)?.children[index] ?? roots[index]
    }

    func outlineView(_ ov: NSOutlineView, isItemExpandable item: Any) -> Bool {
        (item as? LibraryNode)?.isFolder ?? false
    }

    // MARK: NSOutlineViewDelegate

    func outlineView(_ ov: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? LibraryNode else { return nil }

        let cell = NSTableCellView()
        let image = NSImageView(frame: NSRect(x: 2, y: 2, width: 16, height: 16))
        image.imageScaling = .scaleProportionallyDown
        let symbol = node.isFolder ? "folder" : "doc.plaintext"
        image.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        image.contentTintColor = node.isFolder ? .secondaryLabelColor : .tertiaryLabelColor
        cell.addSubview(image)
        cell.imageView = image

        let isActive = !node.isFolder && node.id == prompterController?.activeScriptID
        let label = NSTextField(labelWithString: (isActive ? "● " : "") + node.title)
        label.frame = NSRect(x: 22, y: 1, width: 400, height: 18)
        label.lineBreakMode = .byTruncatingTail
        label.autoresizingMask = [.width]
        // 지금 카메라에 나가는 대본을 구분하는 유일한 신호다.
        label.font = isActive ? NSFont.boldSystemFont(ofSize: 13) : NSFont.systemFont(ofSize: 13)
        // 이름 변경이 어떤 항목인지 알아야 하는데, 편집이 끝나는 시점엔 클릭한 행이 이미 없을 수 있다.
        // 그래서 뷰 자체에 id 를 실어 둔다.
        label.identifier = NSUserInterfaceItemIdentifier(node.id)
        label.delegate = self
        label.isEditable = false          // 이름 변경 명령을 받았을 때만 켠다
        cell.addSubview(label)
        cell.textField = label
        return cell
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        // 선택이 바뀌기 전에 예약된 쓰기를 확정한다 — 안 그러면 1.5초 뒤 디바운스가
        // 이미 떠난 대본에 지금 편집기 내용을 쓴다.
        flushPendingEdits()

        let selected = outlineView.selectedRowIndexes.compactMap {
            outlineView.item(atRow: $0) as? LibraryNode
        }
        guard selected.count == 1, let node = selected.first, !node.isFolder else {
            showEditor(for: nil)
            return
        }
        showEditor(for: node.id)
        SettingsStore.shared.update { $0.libraryLastSelectedID = node.id }
    }

    func outlineViewItemDidExpand(_ notification: Notification) {
        SettingsStore.shared.update { $0.libraryExpandedFolderIDs = expandedFolderIDs() }
    }

    func outlineViewItemDidCollapse(_ notification: Notification) {
        SettingsStore.shared.update { $0.libraryExpandedFolderIDs = expandedFolderIDs() }
    }

    // MARK: 편집기

    private func showEditor(for id: String?) {
        editingScriptID = id
        isApplyingExternalChange = true
        defer { isApplyingExternalChange = false }

        guard let id, let meta = ScriptStore.loadLibrary().scripts.first(where: { $0.id == id }) else {
            editorTextView.setupInitialText("")
            editorTextView.isEditable = false
            titleField.stringValue = ""
            statusLabel.stringValue = "대본을 선택하세요"
            loadButton.isEnabled = false
            return
        }
        let text = ScriptStore.read(id: id) ?? ""
        editorTextView.setupInitialText(text)
        editorTextView.isEditable = true
        titleField.stringValue = meta.title
        loadButton.isEnabled = true
        updateStatus(charCount: text.count, saved: nil)
    }

    private func updateStatus(charCount: Int, saved: Date?) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let savedText = saved.map { " · 저장 \(formatter.string(from: $0))" } ?? ""
        let active = editingScriptID == prompterController?.activeScriptID ? " · 프롬프터에 표시 중" : ""
        statusLabel.stringValue = "\(charCount)자\(savedText)\(active)"
    }

    func textDidChange(_ notification: Notification) {
        guard !isApplyingExternalChange, let id = editingScriptID else { return }
        let snapshot = editorTextView.string
        previewWork?.cancel()
        inactiveWriteWork?.cancel()

        if id == prompterController?.activeScriptID {
            // 활성 대본 — 설정 창이 하던 것과 완전히 같은 경로.
            // 0.3초 뒤 화면 반영, updateScript 안에서 다시 1.5초 뒤 파일 쓰기.
            let work = DispatchWorkItem { [weak self] in
                self?.prompterController?.updateScript(snapshot)
                self?.updateStatus(charCount: snapshot.count, saved: Date())
            }
            previewWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
        } else {
            // 비활성 대본 — 미리보기 대상이 없으므로 0.3초 단계가 무의미하다. 한 단계만.
            // **id 를 캡처**해야 쓰기 직전에 선택이 바뀌어도 엉뚱한 대본에 쓰지 않는다.
            let work = DispatchWorkItem { [weak self] in
                ScriptStore.write(id: id, text: snapshot)
                ScriptStore.touch(id: id)
                self?.updateStatus(charCount: snapshot.count, saved: Date())
            }
            inactiveWriteWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
        }
        updateStatus(charCount: snapshot.count, saved: nil)
    }

    /// 예약된 쓰기를 즉시 확정한다. 선택 변경·창 닫기·앱 전환·삭제 직전에 부른다.
    func flushPendingEdits() {
        if let work = previewWork { work.cancel(); previewWork = nil; work.perform() }
        if let work = inactiveWriteWork { work.cancel(); inactiveWriteWork = nil; work.perform() }
        prompterController?.flushScript()
    }

    // MARK: 컨텍스트 메뉴

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        // ⚠️ 선택에 없는 행을 우클릭했으면 **먼저 그 행을 선택한다.**
        // 안 하면 눈으로 겨눈 항목이 아니라 아까 선택해 둔 다른 항목이 지워진다.
        //
        // clickedRow 가 -1 인 경로도 있다(키보드로 메뉴를 열거나 빈 곳을 눌렀을 때).
        // 그때 target 을 nil 로 두면 선택된 대본이 멀쩡히 있는데도 "새 대본/새 폴더" 만 나온다.
        // → currentTargetNode() 와 같은 규칙(클릭 우선, 없으면 선택)을 쓴다.
        let clicked = outlineView.clickedRow
        if clicked >= 0 && !outlineView.selectedRowIndexes.contains(clicked) {
            outlineView.selectRowIndexes([clicked], byExtendingSelection: false)
        }
        let target = currentTargetNode()

        // 새로 만들 위치: 폴더를 눌렀으면 그 안, 대본을 눌렀으면 그 대본이 있는 폴더, 빈 곳이면 최상위.
        let destination: String? = target.flatMap { $0.isFolder ? $0.id : $0.parent?.id }

        func add(_ title: String, _ selector: Selector, enabled: Bool = true) {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
            item.target = self
            item.isEnabled = enabled
            item.representedObject = target
            menu.addItem(item)
        }

        let writable = !ScriptStore.isWriteBlocked
        newItemDestination = destination
        add("새 대본", #selector(createScriptHere), enabled: writable)
        add("새 폴더", #selector(createFolderHere), enabled: writable)

        // ⌘Z 는 편집기의 텍스트 되돌리기가 가져가므로, 삭제 되돌리기는 메뉴에만 둔다.
        // (같은 키에 두 의미를 얹으면 어느 쪽이 동작할지 사용자가 예측할 수 없다)
        if !lastDeleted.isEmpty {
            add("삭제 취소", #selector(undoLastDelete), enabled: writable)
        }

        guard let target else { return }
        menu.addItem(.separator())
        add("이름 변경", #selector(renameSelected), enabled: writable)
        if !target.isFolder {
            add("복제", #selector(duplicateSelected), enabled: writable)
            add("프롬프터에 올리기", #selector(loadSelectedIntoPrompter))
        }

        // 이동 ▸ — 드래그를 못 쓰는 상황(긴 트리, 트랙패드)을 위한 정식 경로.
        let moveItem = NSMenuItem(title: "이동", action: nil, keyEquivalent: "")
        moveItem.submenu = buildMoveMenu(for: target)
        moveItem.isEnabled = writable
        menu.addItem(moveItem)

        menu.addItem(.separator())
        add("Finder 에서 보기", #selector(revealSelectedInFinder), enabled: !target.isFolder)
        menu.addItem(.separator())
        add("삭제", #selector(deleteSelected), enabled: writable)
    }

    private func buildMoveMenu(for node: LibraryNode) -> NSMenu {
        let menu = NSMenu()
        let root = NSMenuItem(title: "최상위로", action: #selector(moveSelected(_:)), keyEquivalent: "")
        root.target = self
        root.representedObject = nil as String?
        menu.addItem(root)
        menu.addItem(.separator())

        // 자기 자신과 자손은 넣지 않는다(넣으면 트리가 끊긴다 — 저장 계층도 거부하지만
        // 고를 수 있게 두면 "눌렀는데 아무 일도 없다" 가 된다).
        let library = ScriptStore.loadLibrary()
        var blocked: Set<String> = []
        if node.isFolder {
            blocked.insert(node.id)
            var queue = [node.id]
            while let current = queue.popLast() {
                for child in library.folders where child.parentID == current {
                    blocked.insert(child.id); queue.append(child.id)
                }
            }
        }

        func addLevel(_ parent: String?, depth: Int) {
            let siblings = library.folders
                .filter { $0.parentID == parent }
                .sorted { $0.sortIndex < $1.sortIndex }
            for folder in siblings {
                let item = NSMenuItem(title: String(repeating: "    ", count: depth) + folder.name,
                                      action: #selector(moveSelected(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = folder.id
                item.isEnabled = !blocked.contains(folder.id)
                menu.addItem(item)
                addLevel(folder.id, depth: depth + 1)
            }
        }
        addLevel(nil, depth: 0)
        return menu
    }

    // MARK: 구조 변경 액션

    @objc func createScriptHere() {
        guard let id = ScriptStore.createScript(title: "새 대본", in: newItemDestination) else {
            reportWriteFailure(); return
        }
        refreshTree()
        selectAndBeginRename(id)
    }

    @objc func createFolderHere() {
        guard let folder = ScriptStore.createFolder(name: "새 폴더", parentID: newItemDestination) else {
            reportWriteFailure(); return
        }
        refreshTree()
        selectAndBeginRename(folder.id)
    }

    @objc func duplicateSelected() {
        guard let node = currentTargetNode(), !node.isFolder else { return }
        flushPendingEdits()
        guard let copy = ScriptStore.duplicateScript(id: node.id) else { reportWriteFailure(); return }
        refreshTree()
        selectAndBeginRename(copy)
    }

    @objc func renameSelected() {
        guard let node = currentTargetNode() else { return }
        selectAndBeginRename(node.id)
    }

    @objc func moveSelected(_ sender: NSMenuItem) {
        guard let node = currentTargetNode() else { return }
        let destination = sender.representedObject as? String
        let ok = node.isFolder
            ? ScriptStore.moveFolder(id: node.id, toParent: destination)
            : ScriptStore.moveScript(id: node.id, toFolder: destination)
        if !ok { reportWriteFailure(); return }
        refreshTree()
    }

    @objc func revealSelectedInFinder() {
        guard let node = currentTargetNode(), !node.isFolder else { return }
        // Finder 는 별도 프로세스라 캡처에 찍힌다. 촬영 중에는 쓰면 안 된다.
        NSWorkspace.shared.activateFileViewerSelecting([ScriptStore.url(for: node.id)])
    }

    /// 삭제 — 이 순서가 계약이다. 어기면 유령 파일이 남거나 활성 대본이 사라진 채로 남는다.
    @objc func deleteSelected() {
        let nodes = outlineView.selectedRowIndexes.compactMap {
            outlineView.item(atRow: $0) as? LibraryNode
        }
        guard !nodes.isEmpty else { return }

        let scriptIDs = Set(nodes.filter { !$0.isFolder }.map(\.id))
        let folders = nodes.filter { $0.isFolder }

        if let confirm = deleteConfirmation(scripts: scriptIDs.count, folders: folders.count),
           confirm != .alertFirstButtonReturn { return }

        // ① 예약된 쓰기부터 정리한다(순서 중요 — 아래 주석 참조)
        flushPendingEdits()
        prompterController?.prepareForDeletion(of: scriptIDs)

        // ② 삭제
        var bundles: [ScriptStore.DeletedBundle] = []
        for id in scriptIDs {
            if let bundle = ScriptStore.deleteScript(id: id) { bundles.append(bundle) }
        }
        for folder in folders {
            if let bundle = ScriptStore.deleteFolder(id: folder.id, strategy: .promoteChildren) {
                bundles.append(bundle)
            }
        }

        // ③ 활성 대본이 사라졌으면 프롬프터가 스스로 다음 대본을 고른다
        prompterController?.libraryDidChange(deleted: scriptIDs)

        lastDeleted = bundles
        refreshTree()
        showEditor(for: nil)
    }

    private func deleteConfirmation(scripts: Int, folders: Int) -> NSApplication.ModalResponse? {
        // 대본이 없고 빈 폴더만 지우는 건 되돌리기 쉬우므로 묻지 않는다.
        guard scripts > 0 else { return nil }
        let alert = NSAlert()
        alert.window.sharingType = .none        // 촬영 중에 뜰 수 있다
        alert.messageText = scripts == 1 ? "대본을 삭제할까요?" : "대본 \(scripts)개를 삭제할까요?"
        alert.informativeText = "지우지 않고 휴지통으로 옮깁니다. 우클릭 메뉴의 '삭제 취소' 로 되돌리거나, "
            + "30일 안에는 \(ScriptStore.baseURL.appendingPathComponent("trash").path) 에서 직접 꺼낼 수 있습니다."
        alert.addButton(withTitle: "삭제")
        alert.addButton(withTitle: "취소")
        return alert.runModal()
    }

    /// 직전 삭제 1회분. 되돌리기용.
    private var lastDeleted: [ScriptStore.DeletedBundle] = []

    @objc func undoLastDelete() {
        guard !lastDeleted.isEmpty else { return }
        for bundle in lastDeleted { ScriptStore.restore(bundle) }
        lastDeleted = []
        refreshTree()
    }

    private func currentTargetNode() -> LibraryNode? {
        let row = outlineView.clickedRow >= 0 ? outlineView.clickedRow : outlineView.selectedRow
        guard row >= 0 else { return nil }
        return outlineView.item(atRow: row) as? LibraryNode
    }

    private func selectAndBeginRename(_ id: String) {
        for row in 0..<outlineView.numberOfRows {
            guard let node = outlineView.item(atRow: row) as? LibraryNode, node.id == id else { continue }
            outlineView.selectRowIndexes([row], byExtendingSelection: false)
            outlineView.scrollRowToVisible(row)
            // 만들자마자 이름을 고칠 수 있게 편집 상태로 들어간다("새 대본" 이 쌓이지 않게).
            if let cell = outlineView.view(atColumn: 0, row: row, makeIfNecessary: true) as? NSTableCellView {
                cell.textField?.isEditable = true
                outlineView.window?.makeFirstResponder(cell.textField)
            }
            return
        }
    }

    private func reportWriteFailure() {
        let alert = NSAlert()
        alert.window.sharingType = .none
        alert.messageText = "대본 목록을 저장하지 못했습니다"
        alert.informativeText = ScriptStore.isWriteBlocked
            ? "목록 파일이 손상되어 저장이 잠겨 있습니다. 앱을 다시 실행하면 복구를 안내합니다."
            : "저장 경로에 쓸 수 없습니다:\n\(ScriptStore.baseURL.path)"
        alert.runModal()
        updateWarningBar()
    }

    // MARK: 인라인 이름 변경

    func controlTextDidEndEditing(_ notification: Notification) {
        guard let field = notification.object as? NSTextField,
              let id = field.identifier?.rawValue else { return }
        field.isEditable = false

        let typed = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        // ● 활성 표시가 붙어 있으면 벗겨 낸다(표시는 이름의 일부가 아니다).
        let cleaned = typed.hasPrefix("● ") ? String(typed.dropFirst(2)) : typed

        let library = ScriptStore.loadLibrary()
        let isFolder = library.folders.contains { $0.id == id }
        let currentName = isFolder
            ? library.folders.first { $0.id == id }?.name
            : library.scripts.first { $0.id == id }?.title

        // ⚠️ **바뀐 게 없으면 아무것도 하지 않는다.**
        //
        // 편집을 "끝내는" 경로는 사용자가 Return 을 친 것 말고도 많다 — 선택이 바뀌거나
        // 트리를 다시 그리기만 해도 편집 세션이 닫히며 이 델리게이트가 불린다.
        // 그때마다 저장을 시도하면, 저장이 잠긴 상태에서는 **행을 클릭하는 것만으로 모달이 뜬다.**
        // (셀프테스트가 이 지점에서 영구히 멈춰 발견했다 — 스택이 selectRowIndexes →
        //  controlTextDidEndEditing → reportWriteFailure → NSAlert.runModal 이었다)
        guard !cleaned.isEmpty, cleaned != currentName else {
            refreshTree()       // 표시를 원래대로 되돌린다(빈 입력·● 접두사 등)
            return
        }

        let ok = isFolder
            ? ScriptStore.renameFolder(id: id, to: cleaned)
            : ScriptStore.renameScript(id: id, to: cleaned)
        refreshTree()
        if !ok { reportWriteFailure() }
        if id == editingScriptID { showEditor(for: id) }
    }

    // MARK: 액션

    @objc func loadSelectedIntoPrompter() {
        guard let node = outlineView.item(atRow: outlineView.selectedRow) as? LibraryNode,
              !node.isFolder else { return }
        flushPendingEdits()
        prompterController?.switchToScript(id: node.id)
        refreshTree()       // 활성 표시(볼드 + ●) 갱신
    }

    // MARK: 프롬퍼터 → 라이브러리 (한 방향)

    /// 프롬프터 쪽에서 대본이 바뀌었다. **선택은 건드리지 않는다** — 사용자가 보고 있던 자리를
    /// 뺏지 않기 위해서다. 활성 표시만 갱신하고, 같은 대본을 편집 중이면 텍스트를 다시 읽는다.
    func prompterDidSwitchScript(to id: String?) {
        refreshTree()
        guard let id, id == editingScriptID else { return }
        let incoming = ScriptStore.read(id: id) ?? ""
        // 실제로 루프를 끊는 건 이 동등성 검사다.
        guard editorTextView.string != incoming else { return }
        isApplyingExternalChange = true
        editorTextView.setupInitialText(incoming)
        isApplyingExternalChange = false
        updateStatus(charCount: incoming.count, saved: nil)
    }

    // MARK: NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        flushPendingEdits()
        saveWindowFrame()
        SettingsStore.shared.flushNow()
    }

    func windowDidMove(_ notification: Notification) { saveWindowFrame() }
    func windowDidResize(_ notification: Notification) { saveWindowFrame() }

    private func saveWindowFrame() {
        guard let frame = window?.frame else { return }
        SettingsStore.shared.update {
            $0.libraryWindowFrame = [Double(frame.origin.x), Double(frame.origin.y),
                                     Double(frame.width), Double(frame.height)]
        }
    }

    // MARK: 셀프테스트 프로브

    /// 창을 띄우지 않고 핵심 뷰를 꺼낸다. 중첩 뷰를 재귀 탐색하는 방식은 취약해서 쓰지 않는다.
    var layoutProbeForTest: (split: NSSplitView, outline: NSOutlineView, editor: NSTextView)? {
        guard let splitView, let outlineView, let editorTextView else { return nil }
        return (splitView, outlineView, editorTextView)
    }

    var editorScrollFrameForTest: NSRect { editorScrollView?.frame ?? .zero }

    /// 셀프테스트용 — 특정 행을 우클릭했을 때의 컨텍스트 메뉴를 만든다.
    ///
    /// GUI 로 검증하기 어려운 부분이라(합성 클릭은 NSMenu 의 추적 루프에서 잘 먹지 않는다)
    /// 메뉴 구성과 액션 배선을 여기서 직접 확인한다.
    func contextMenuForTest(selecting id: String) -> NSMenu? {
        for row in 0..<outlineView.numberOfRows {
            guard let node = outlineView.item(atRow: row) as? LibraryNode, node.id == id else { continue }
            outlineView.selectRowIndexes([row], byExtendingSelection: false)
            guard let menu = outlineView.menu else { return nil }
            menuNeedsUpdate(menu)
            return menu
        }
        return nil
    }

    /// 메뉴 항목을 실제로 눌렀을 때와 같은 경로로 실행한다.
    func performMenuItemForTest(_ item: NSMenuItem) {
        guard let action = item.action else { return }
        _ = (item.target as AnyObject).perform(action, with: item)
    }

    /// 셀프테스트용 — 셀의 이름 편집이 끝난 상황을 재현한다.
    func simulateEndEditingForTest(id: String, text: String) {
        let field = NSTextField(string: text)
        field.identifier = NSUserInterfaceItemIdentifier(id)
        controlTextDidEndEditing(Notification(name: NSControl.textDidEndEditingNotification,
                                              object: field))
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
    var libraryController: ScriptLibraryWindowController?

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

        // 신호등 버튼 셋을 전부 숨긴다. 이 창은 캡처에 안 보이므로 어느 걸 눌러도
        // 사용자에게는 "앱이 사라졌다"로 보인다. 치우는 건 숨김(⌃⌥H)으로만 한다.
        //
        // 최소화가 특히 나쁘다 — 이 앱은 `.accessory` 라 Dock 아이콘이 없어서, 최소화하면
        // 되돌릴 표면이 아무 데도 없다(닫기보다 복구가 어렵다).
        // 확대는 프롬프터를 화면 가득 채워 촬영 구도를 망친다.
        // (styleMask 에서 .closable 을 빼면 타이틀바 레이아웃이 달라지므로 버튼만 감춘다)
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            window.standardWindowButton(button)?.isHidden = true
        }
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
        strip.onLibrary = { [weak self] in self?.showLibrary() }
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

    /// 셀프테스트 프로브 — 파일 쓰기가 예약된 상태인가.
    var hasPendingScriptWriteForTest: Bool { scriptWriteWorkItem != nil }

    /// 삭제 직전에 부른다. 삭제 대상이 활성 대본이면 예약된 쓰기를 **취소**한다.
    ///
    /// 안 하면 1.5초 뒤 디바운스가 방금 지운 id 로 파일을 되살려, **목록에는 없는데
    /// 디스크에는 있는 유령 대본**이 남는다. 그 파일은 어떤 UI 로도 지울 수 없다.
    /// 대상이 아니면 반대로 확정 저장한다(지우는 김에 다른 대본까지 잃을 이유는 없다).
    func prepareForDeletion(of ids: Set<String>) {
        guard let active = activeScriptID else { return }
        if ids.contains(active) {
            scriptWriteWorkItem?.cancel()
            scriptWriteWorkItem = nil
        } else {
            flushScript()
        }
    }

    /// 라이브러리에서 구조가 바뀌었다. 활성 대본이 사라졌으면 다음 대본으로 넘어간다.
    func libraryDidChange(deleted: Set<String>) {
        guard let active = activeScriptID, deleted.contains(active) else { return }
        // activeScriptID 를 비워야 ensureActiveScript 가 "저장된 대본이 없다" 로 보고
        // 남은 것 중 최신을 고른다. 하나도 없으면 거기서 새로 만든다.
        activeScriptID = nil
        SettingsStore.shared.update { $0.activeScriptID = nil }
        loadActiveScript()
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
        libraryController?.prompterDidSwitchScript(to: id)
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
        libraryController?.prompterDidSwitchScript(to: activeScriptID)
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
        // 이동은 크기를 바꾸지 않아 레이아웃 패스가 일어나지 않는다 = `layout()` 의 미러 재적용도
        // 안 걸린다. 그런데 이동 중에도 AppKit 이 레이어 지오메트리를 되돌릴 수 있어, 여기서
        // 직접 다시 걸지 않으면 창을 한 번 옮긴 뒤 반전이 조용히 풀린다.
        prompterView.reapplyMirror()
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

    /// 대본 라이브러리를 연다. 이미 떠 있으면 앞으로 가져오고 트리를 최신으로 맞춘다
    /// (창을 닫아 두는 동안 다른 경로로 대본이 바뀌었을 수 있다).
    func showLibrary() {
        if libraryController == nil {
            libraryController = ScriptLibraryWindowController(prompterController: self)
        } else {
            libraryController?.refreshTree()
        }
        NSApp.activate(ignoringOtherApps: true)
        libraryController?.showWindow(nil)
        libraryController?.window?.makeKeyAndOrderFront(nil)
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

        // 대본 색인을 v2 로 올린다. **반드시 loadActiveScript() 보다 먼저.**
        // 그 경로가 ensureActiveScript → touch → saveLibrary 로 이어져,
        // 정규화되지 않은 v1 파일 위에 v2 를 얹어 버린다.
        ScriptStore.migrateIfNeeded()
        ScriptStore.pruneTrash()
        reportLibraryProblemIfNeeded()

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

    /// 색인을 신뢰할 수 없을 때만 사용자에게 알린다.
    ///
    /// 조용히 넘어가면 안 된다 — 쓰기가 차단된 상태에서는 새 대본을 만들어도, 이름을 바꿔도
    /// 다음 실행에 사라진다. "저장이 안 되는데 아무 말도 없는" 상태가 가장 나쁘다.
    private func reportLibraryProblemIfNeeded() {
        switch ScriptStore.lastLoadState {
        case .fresh, .ok, .repaired:
            return      // repaired 는 이미 살릴 건 다 살렸고 쓰기도 열려 있다
        case .futureVersion(let version):
            let alert = NSAlert()
            alert.window.sharingType = .none
            alert.messageText = "대본 목록이 더 새로운 버전에서 만들어졌습니다"
            alert.informativeText = """
                목록 형식 v\(version) 은 이 버전(v\(ScriptLibrary.currentVersion))이 모릅니다.
                여기서 저장하면 새 버전이 기록한 정보가 지워지므로, 대본 목록을 읽기 전용으로 둡니다.
                최신 ShadowCue 로 여시면 정상 동작합니다.
                """
            alert.addButton(withTitle: "읽기 전용으로 계속")
            alert.runModal()
        case .corruptTopLevel(let preserved):
            let alert = NSAlert()
            alert.window.sharingType = .none
            alert.messageText = "대본 목록 파일을 읽지 못했습니다"
            alert.informativeText = """
                대본 본문(\(ScriptStore.scriptsURL.path))은 그대로 있습니다. 목록만 손상됐습니다.
                덮어쓰지 않도록 저장을 잠가 두었습니다.

                '목록 다시 만들기' 를 누르면 대본 파일을 훑어 목록을 새로 만듭니다.
                폴더 구성은 사라지지만 대본은 하나도 잃지 않습니다.
                \(preserved.map { "\n손상된 원본은 \($0.lastPathComponent) 로 남겨 두었습니다." } ?? "")
                """
            alert.addButton(withTitle: "목록 다시 만들기")
            alert.addButton(withTitle: "읽기 전용으로 계속")
            if alert.runModal() == .alertFirstButtonReturn {
                let rebuilt = ScriptStore.rebuildLibraryFromDisk()
                ScriptStore.unblockWritesAfterRecovery()
                _ = ScriptStore.saveLibrary(rebuilt)
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

        hotkeyManager.onShowLibrary = { [weak self] in
            self?.prompterController.showLibrary()
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

        // 대본 서브메뉴 안이 아니라 **최상위**에 둔다. 상태아이템 자체가 잘 안 보이는데
        // (메뉴바가 꽉 찬 맥에서는 아예 가려진다) 어렵게 열었을 때 한 단계 더 들어가게 하면 안 된다.
        menu.addItem(NSMenuItem(title: "대본 라이브러리...", action: #selector(showLibrary), keyEquivalent: "l"))

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
        windowMenu.addItem(NSMenuItem(title: "대본 라이브러리", action: #selector(showLibrary), keyEquivalent: "3"))

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

    @objc func showLibrary() {
        prompterController.showLibrary()
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

/// 미러 반전이 **AppKit 의 레이어 지오메트리 되돌림 뒤에도 살아남는지** 검사한다.
///
/// 위 `runMirrorSelfTest` 는 프로퍼티를 세팅한 직후에만 확인해서 v1.2 의 실제 버그를 놓쳤다.
/// 첫 실행 경로는 설정 복원 → showWindow → AppKit 첫 레이아웃 순인데, 마지막 단계가
/// transform 을 지우고 setFrameSize 는 크기가 안 바뀌어 불리지 않아서, 저장된 미러 설정이
/// 화면에 반영되지 않았다(창을 한 번 리사이즈해야 그제서야 반전됨).
/// 실기기 캡처로 증상을, 레이어 상태 계측으로 원인을 확인하고 추가한 테스트다.
func runMirrorPersistsLayoutSelfTest() -> Bool {
    var allOK = true

    for (h, v, label) in [(true, false, "좌우"), (false, true, "상하"), (true, true, "좌우+상하")] {
        let view = PrompterView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        view.layoutSubtreeIfNeeded()
        view.mirrorHorizontal = h
        view.mirrorVertical = v

        // AppKit 이 레이어 지오메트리를 되돌리는 지점 재현 — 여기서 반전이 사라졌다.
        view.simulateAppKitGeometrySync()

        guard let p = view.mirrorProbe() else {
            print("FAIL 미러 레이아웃 생존(\(label)) — 프로브 없음")
            allOK = false
            continue
        }
        // 반전 축의 원점은 반대편 끝으로 가야 한다.
        let expectedX = h ? p.size.width : 0
        let expectedY = v ? p.size.height : 0
        let ok = abs(p.topLeftMapsTo.x - expectedX) < 1 && abs(p.topLeftMapsTo.y - expectedY) < 1
        print("\(ok ? "PASS" : "FAIL") 미러 레이아웃 생존(\(label)) "
              + "(원점 → \(Int(p.topLeftMapsTo.x)),\(Int(p.topLeftMapsTo.y)) / "
              + "기대 \(Int(expectedX)),\(Int(expectedY)))")
        allOK = allOK && ok
    }
    return allOK
}

/// 신호등 버튼이 전부 감춰졌는지 검사한다.
///
/// 이 창은 캡처에 안 보이므로 어느 버튼을 눌러도 "앱이 사라졌다"로 보인다.
/// 특히 최소화는 `.accessory` 앱이라 Dock 에 되돌릴 표면조차 없다.
func runWindowButtonsSelfTest() -> Bool {
    let controller = PrompterWindowController()
    guard let window = controller.window else {
        print("FAIL 신호등 버튼 — 창 없음")
        return false
    }
    let checks: [(NSWindow.ButtonType, String)] = [
        (.closeButton, "닫기"), (.miniaturizeButton, "최소화"), (.zoomButton, "확대"),
    ]
    var allOK = true
    var visible: [String] = []
    for (type, name) in checks {
        // 버튼 자체가 없으면(스타일마스크에 없음) 그것도 "안 보임" 이므로 통과다.
        if let button = window.standardWindowButton(type), !button.isHidden {
            visible.append(name)
            allOK = false
        }
    }
    print("\(allOK ? "PASS" : "FAIL") 신호등 버튼 전부 숨김"
          + (visible.isEmpty ? "" : " (노출: \(visible.joined(separator: ", ")))"))
    return allOK
}

/// 치트시트가 **읽히는 상태로** 뜨는지 검사한다.
///
/// v1.2 에서는 배경이 0.78 이라 뒤의 대본(32~72pt)이 그대로 비쳐 목록을 읽기 어려웠다.
/// 패널이 창 밖으로 넘치지 않는지도 함께 본다.
func runCheatSheetSelfTest() -> Bool {
    let overlay = PrompterOverlayView(frame: NSRect(x: 0, y: 0, width: 1000, height: 700))
    let lines = HotkeyAction.allCases.map { ($0.defaultDisplayString, $0.name) }
    overlay.toggleCheatSheet(lines)
    overlay.layoutSubtreeIfNeeded()
    overlay.layout()

    guard let frame = overlay.cheatSheetFrameForTest else {
        print("FAIL 치트시트 — 표시되지 않음")
        return false
    }
    let fits = frame.minX >= 0 && frame.minY >= 0
        && frame.maxX <= overlay.bounds.width + 0.5
        && frame.maxY <= overlay.bounds.height + 0.5
    let opaque = PrompterOverlayView.cheatSheetBackgroundAlpha >= 0.9
    let readable = PrompterOverlayView.cheatSheetFontSize >= 14

    let ok = fits && opaque && readable
    let box = "\(Int(frame.width))x\(Int(frame.height)) @\(Int(frame.minX)),\(Int(frame.minY))"
    let alpha = PrompterOverlayView.cheatSheetBackgroundAlpha
    let pt = Int(PrompterOverlayView.cheatSheetFontSize)
    print("\(ok ? "PASS" : "FAIL") 치트시트 가독성 (\(box), 배경 \(alpha), \(pt)pt, 창 안=\(fits))")
    return ok
}

/// 대본 저장 경로가 env 로 격리되는지 검사한다.
/// 이게 없으면 테스트 실행마다 사용자의 진짜 라이브러리에 "기본 대본" 이 쌓인다.
func runSupportDirIsolationSelfTest() -> Bool {
    let override = ProcessInfo.processInfo.environment["SHADOWCUE_SUPPORT_DIR"]
    let base = ScriptStore.baseURL.path
    let home = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("ShadowCue").path

    let ok: Bool
    let detail: String
    if let override = override, !override.isEmpty {
        ok = base == URL(fileURLWithPath: override, isDirectory: true).path && base != home
        detail = "격리됨 → \(base)"
    } else {
        // 훅이 없으면 기본 경로여야 한다(= 훅 부재가 경로를 망가뜨리지 않는지 확인).
        ok = base == home
        detail = "훅 없음, 기본 경로 사용"
    }
    print("\(ok ? "PASS" : "FAIL") 대본 경로 격리 (\(detail))")
    return ok
}

// MARK: - 라이브러리 트리

/// 아웃라인 뷰 전용 참조 래퍼.
///
/// `NSOutlineView` 는 항목을 **객체 동일성**으로 추적하므로 값 타입 배열을 그대로 줄 수 없다.
/// 색인을 읽을 때마다 새로 만들고 전체 `reloadData` 로 간다 — 증분 API(`insertItems`)는
/// 매번 새 객체라 "이미 지운 항목을 참조" 크래시가 나기 쉽고, 수십~수백 규모에서
/// 전체 리로드 비용은 무시할 만하다.
final class LibraryNode {
    enum Kind { case folder(ScriptFolder), script(ScriptMeta) }
    let kind: Kind
    var children: [LibraryNode] = []
    weak var parent: LibraryNode?

    init(_ kind: Kind) { self.kind = kind }

    var id: String {
        switch kind {
        case .folder(let f): return f.id
        case .script(let s): return s.id
        }
    }
    var title: String {
        switch kind {
        case .folder(let f): return f.name
        case .script(let s): return s.title
        }
    }
    var isFolder: Bool { if case .folder = kind { return true }; return false }
    var sortIndex: Int {
        switch kind {
        case .folder(let f): return f.sortIndex
        case .script(let s): return s.sortIndex
        }
    }
}

enum LibraryTree {
    /// 색인을 트리로 만든다. **순수 함수** — 창 없이 테스트할 수 있다.
    ///
    /// 세 가지를 반드시 지킨다:
    /// 1. 없는 폴더를 가리키는 항목은 **최상위로 승격**한다. 버리면 대본이 사라진 것처럼 보인다.
    /// 2. `parentID` 순환이 파일에 들어 있어도 방문 집합으로 끊어 유한 트리를 만든다.
    /// 3. 같은 부모 안에서 폴더가 대본보다 앞에 온다.
    static func build(from library: ScriptLibrary) -> [LibraryNode] {
        let validFolderIDs = Set(library.folders.map(\.id))

        // 순환 검출 — 조상 사슬을 따라가다 자기 자신을 만나면 그 폴더는 최상위로 올린다.
        func rootedParent(of folder: ScriptFolder) -> String? {
            guard let parent = folder.parentID, validFolderIDs.contains(parent) else { return nil }
            var seen: Set<String> = [folder.id]
            var cursor: String? = parent
            while let current = cursor {
                if seen.contains(current) { return nil }     // 순환 → 최상위로
                seen.insert(current)
                cursor = library.folders.first(where: { $0.id == current })?.parentID
            }
            return parent
        }

        var nodes: [String: LibraryNode] = [:]
        var effectiveParent: [String: String?] = [:]
        for folder in library.folders {
            nodes[folder.id] = LibraryNode(.folder(folder))
            effectiveParent[folder.id] = rootedParent(of: folder)
        }

        var roots: [LibraryNode] = []
        for folder in library.folders {
            guard let node = nodes[folder.id] else { continue }
            if let parentID = effectiveParent[folder.id] ?? nil, let parent = nodes[parentID] {
                node.parent = parent
                parent.children.append(node)
            } else {
                roots.append(node)
            }
        }
        for script in library.scripts {
            let node = LibraryNode(.script(script))
            // 고아 대본은 버리지 않고 최상위로 올린다.
            if let folderID = script.folderID, let parent = nodes[folderID] {
                node.parent = parent
                parent.children.append(node)
            } else {
                roots.append(node)
            }
        }

        func sort(_ list: inout [LibraryNode]) {
            list.sort { a, b in
                if a.isFolder != b.isFolder { return a.isFolder }       // 폴더 먼저
                if a.sortIndex != b.sortIndex { return a.sortIndex < b.sortIndex }
                return a.title.localizedStandardCompare(b.title) == .orderedAscending
            }
            for node in list { sort(&node.children) }
        }
        sort(&roots)
        return roots
    }

    /// 트리 전체 노드 수. 유실 검출용.
    static func count(_ roots: [LibraryNode]) -> Int {
        roots.reduce(0) { $0 + 1 + count($1.children) }
    }
}

// MARK: - 대본 라이브러리 셀프테스트

/// 지원 디렉터리를 초기 상태로 되돌린다.
///
/// **`SHADOWCUE_SUPPORT_DIR` 이 없으면 아무것도 하지 않는다.** 이 가드가 없으면 실수 한 번에
/// 사용자의 진짜 대본 라이브러리가 통째로 지워진다. build.sh 는 항상 훅을 주지만 누군가
/// 바이너리를 손으로 실행할 수 있으므로 코드에서 막는다. 훅이 없으면 호출부가 테스트를 건너뛴다.
@discardableResult
func resetSupportDirForTest() -> Bool {
    guard let dir = ProcessInfo.processInfo.environment["SHADOWCUE_SUPPORT_DIR"],
          !dir.isEmpty else { return false }
    try? FileManager.default.removeItem(atPath: dir)
    ScriptStore.resetWriteBlockForTest()
    ScriptStore.prepare()
    return true
}

private func writeLibraryJSONForTest(_ json: String) {
    ScriptStore.prepare()
    try? json.data(using: .utf8)!.write(to: ScriptStore.libraryURL, options: .atomic)
}

/// A. v1 → v2 마이그레이션.
func runLibraryMigrationSelfTest() -> Bool {
    guard resetSupportDirForTest() else {
        print("PASS 라이브러리 마이그레이션 (SHADOWCUE_SUPPORT_DIR 없음 — 건너뜀)")
        return true
    }
    var ok = true
    func check(_ label: String, _ condition: Bool) {
        if !condition { ok = false; print("FAIL 마이그레이션: \(label)") }
    }

    // 스크롤 위치까지 담긴 실제 v1 형태
    writeLibraryJSONForTest("""
    {"version":1,"scripts":[
      {"id":"aaa","title":"첫 대본","createdAt":100,"updatedAt":200,"lastScrollOffset":42.5},
      {"id":"bbb","title":"둘째 대본","createdAt":300,"updatedAt":400}
    ]}
    """)
    let before = try? Data(contentsOf: ScriptStore.libraryURL)

    check("마이그레이션 성공", ScriptStore.migrateIfNeeded())
    let lib = ScriptStore.loadLibrary()
    check("version==2", lib.version == 2)
    check("대본 2개 보존", lib.scripts.count == 2)
    check("id 순서 보존", lib.scripts.map(\.id) == ["aaa", "bbb"])
    check("title 보존", lib.scripts.map(\.title) == ["첫 대본", "둘째 대본"])
    check("스크롤 위치 보존", lib.scripts.first?.lastScrollOffset == 42.5)
    check("folderID 전부 nil", lib.scripts.allSatisfy { $0.folderID == nil })
    check("sortIndex 0..n-1", lib.scripts.map(\.sortIndex) == [0, 1])
    check("folders/boards 비어 있음", lib.folders.isEmpty && lib.boards.isEmpty)

    let backup = ScriptStore.baseURL.appendingPathComponent("library.v1.json")
    let backupData = try? Data(contentsOf: backup)
    check("v1 백업 존재", backupData != nil)
    check("v1 백업 바이트 동일", backupData == before)

    // 멱등성 — 두 번째 호출은 아무것도 하지 않고, 첫 백업을 덮어쓰지도 않는다
    check("두 번째 호출은 no-op", ScriptStore.migrateIfNeeded() == false)
    check("백업이 덮어써지지 않음", (try? Data(contentsOf: backup)) == before)
    check("재호출 후에도 대본 2개", ScriptStore.loadLibrary().scripts.count == 2)

    print("\(ok ? "PASS" : "FAIL") 라이브러리 마이그레이션 (v1→v2, 대본 \(lib.scripts.count)개, sortIndex \(lib.scripts.map(\.sortIndex)))")
    return ok
}

/// B. 손상된 색인 방어 — **이 테스트가 이번 커밋의 핵심이다.**
///
/// 수정 전 코드에서는 `loadLibrary()` 가 디코드 실패 시 조용히 빈 라이브러리를 돌려주고,
/// 그 뒤 `touch`/`saveScrollOffset` 의 read-modify-write 가 멀쩡한 색인을 덮어썼다.
func runLibraryCorruptionGuardSelfTest() -> Bool {
    guard resetSupportDirForTest() else {
        print("PASS 색인 손상 방어 (SHADOWCUE_SUPPORT_DIR 없음 — 건너뜀)")
        return true
    }
    var ok = true
    func check(_ label: String, _ condition: Bool) {
        if !condition { ok = false; print("FAIL 색인 방어: \(label)") }
    }

    // (1) 파일 없음 = 최초 실행. 쓰기 허용.
    check("파일 없음 → .fresh", ScriptStore.loadLibraryDetailed().state == .fresh)
    check(".fresh 는 쓰기 허용", ScriptStore.saveLibrary(ScriptLibrary()))

    // (2) 정상 왕복
    resetSupportDirForTest()
    var good = ScriptLibrary()
    good.scripts = [ScriptMeta(id: "x", title: "정상", createdAt: Date(), updatedAt: Date())]
    check("정상 저장", ScriptStore.saveLibrary(good))
    check("정상 → .ok", ScriptStore.loadLibraryDetailed().state == .ok)

    // (3) 최상위 손상 → 차단
    resetSupportDirForTest()
    ScriptStore.saveLibrary(good)
    writeLibraryJSONForTest("{{{ 이건 JSON 이 아니다")
    let corruptBytes = try? Data(contentsOf: ScriptStore.libraryURL)
    let corruptState = ScriptStore.loadLibraryDetailed().state
    if case .corruptTopLevel = corruptState {} else { ok = false; print("FAIL 색인 방어: 손상 판정") }
    check("쓰기 래치 켜짐", ScriptStore.isWriteBlocked)
    check("손상 원본 사본 생성", (try? FileManager.default.contentsOfDirectory(atPath: ScriptStore.baseURL.path))?
        .contains { $0.hasPrefix("library.corrupt-") } == true)

    // ★ 직접 저장이 막히는가
    check("saveLibrary 거부", ScriptStore.saveLibrary(ScriptLibrary()) == false)
    check("파일 바이트 무변경(직접)", (try? Data(contentsOf: ScriptStore.libraryURL)) == corruptBytes)

    // ★★ **간접 경로**가 막히는가 — 실제 사고 경로 재현.
    //    touch 와 saveScrollOffset 은 사용자가 대본을 열어 보기만 해도 불린다.
    ScriptStore.touch(id: "x", title: "덮어쓰기 시도")
    ScriptStore.saveScrollOffset(id: "x", offset: 999)
    check("파일 바이트 무변경(touch/scroll 경유)",
          (try? Data(contentsOf: ScriptStore.libraryURL)) == corruptBytes)
    check("마이그레이션도 거부", ScriptStore.migrateIfNeeded() == false)

    // (4) 원소 일부만 손상 → 나머지 생존 + 쓰기 허용
    resetSupportDirForTest()
    writeLibraryJSONForTest("""
    {"version":2,"scripts":[
      {"id":"ok1","title":"살아남음","createdAt":100,"updatedAt":200},
      {"title":"id 가 없어 못 살림","createdAt":100,"updatedAt":200}
    ],"folders":[],"boards":[]}
    """)
    let repaired = ScriptStore.loadLibraryDetailed()
    check("일부 손상 → .repaired(1)", repaired.state == .repaired(dropped: 1))
    check("정상 원소 생존", repaired.library.scripts.map(\.id) == ["ok1"])
    check(".repaired 는 쓰기 허용", ScriptStore.isWriteBlocked == false)

    // (5) 미래 버전 → 차단 (다운그레이드한 사용자의 보드를 날리지 않는다)
    resetSupportDirForTest()
    writeLibraryJSONForTest("""
    {"version":99,"scripts":[{"id":"z","title":"미래","createdAt":1,"updatedAt":1}]}
    """)
    check("미래 버전 판정", ScriptStore.loadLibraryDetailed().state == .futureVersion(99))
    check("미래 버전은 쓰기 차단", ScriptStore.saveLibrary(ScriptLibrary()) == false)

    // (6) 디스크에서 복구 — 최종 안전망
    resetSupportDirForTest()
    ScriptStore.write(id: "r1", text: "# 복구된 제목\n본문")
    ScriptStore.write(id: "r2", text: "헤딩 없는 첫 줄\n둘째 줄")
    ScriptStore.write(id: "r3", text: "")
    let rebuilt = ScriptStore.rebuildLibraryFromDisk()
    check("3개 전부 복구", rebuilt.scripts.count == 3)
    check("헤딩에서 제목", rebuilt.scripts.contains { $0.title == "복구된 제목" })
    check("첫 줄에서 제목", rebuilt.scripts.contains { $0.title == "헤딩 없는 첫 줄" })
    check("빈 본문도 제목 부여", rebuilt.scripts.allSatisfy { !$0.title.isEmpty })

    print("\(ok ? "PASS" : "FAIL") 색인 손상 방어 (차단 래치·간접경로·부분복구·디스크재구성)")
    resetSupportDirForTest()
    return ok
}

/// G. `Settings` 전방호환 디코더 나열 누락 자동 검출.
///
/// 필드를 추가하면서 `init(from:)` 의 나열 블록에 한 줄을 빠뜨리는 실수는 반드시 재발한다.
/// 컴파일은 되고 "저장은 되는데 다음 실행에 항상 기본값" 이 되므로 눈으로는 안 잡힌다.
/// 인코딩한 JSON 의 값을 기계적으로 바꿔 넣고 되읽어, 바뀐 값이 하나도 빠짐없이 반영되는지 본다.
func runSettingsDecoderCoverageSelfTest() -> Bool {
    guard let baseData = try? JSONEncoder().encode(Settings()),
          var root = try? JSONSerialization.jsonObject(with: baseData) as? [String: Any] else {
        print("FAIL 설정 디코더 커버리지 — 인코딩 실패")
        return false
    }

    // 기본값과 확실히 다른 값으로 전부 덮는다.
    var mutatedKeys: [String] = []
    for (key, value) in root {
        switch value {
        case let n as NSNumber:
            // Bool 과 숫자를 구분한다(NSNumber 는 둘 다 담는다).
            if CFGetTypeID(n) == CFBooleanGetTypeID() {
                root[key] = !n.boolValue
            } else {
                root[key] = n.doubleValue + 7
            }
            mutatedKeys.append(key)
        case let s as String:
            root[key] = s + "-변경"
            mutatedKeys.append(key)
        case is [Any]:
            // 배열은 타입을 몰라 안전하게 못 바꾼다. 아래 Optional 왕복에서 따로 검사한다.
            continue
        default:
            continue
        }
    }

    guard let mutatedData = try? JSONSerialization.data(withJSONObject: root),
          let decoded = try? JSONDecoder().decode(Settings.self, from: mutatedData),
          let roundTrip = try? JSONEncoder().encode(decoded),
          let after = try? JSONSerialization.jsonObject(with: roundTrip) as? [String: Any] else {
        print("FAIL 설정 디코더 커버리지 — 왕복 실패")
        return false
    }

    // 나열에서 빠진 필드는 기본값으로 남으므로, 바꾼 값과 다르게 나온다.
    var missing: [String] = []
    for key in mutatedKeys {
        let expected = root[key] as? NSObject
        let actual = after[key] as? NSObject
        if expected != actual { missing.append(key) }
    }

    // Optional 필드는 기본 인코딩에 키가 없어 위 방식으로 못 덮는다 → 값을 채워 왕복.
    var s = Settings()
    s.windowFrame = [1, 2, 3, 4]
    s.activeScriptID = "AID"
    s.fontName = "Menlo"
    s.libraryWindowFrame = [5, 6, 7, 8]
    s.libraryLastSelectedID = "LID"
    s.libraryExpandedFolderIDs = ["f1", "f2"]
    let optionalOK = (try? JSONEncoder().encode(s))
        .flatMap { try? JSONDecoder().decode(Settings.self, from: $0) } == s

    let ok = missing.isEmpty && optionalOK
    print("\(ok ? "PASS" : "FAIL") 설정 디코더 커버리지 "
          + "(검사 \(mutatedKeys.count)개"
          + (missing.isEmpty ? "" : ", 나열 누락: \(missing.sorted().joined(separator: ", "))")
          + ", 옵셔널 왕복=\(optionalOK))")
    return ok
}

/// C. 폴더·대본 CRUD.
func runFolderCRUDSelfTest() -> Bool {
    guard resetSupportDirForTest() else {
        print("PASS 폴더·대본 CRUD (SHADOWCUE_SUPPORT_DIR 없음 — 건너뜀)")
        return true
    }
    var ok = true
    func check(_ label: String, _ condition: Bool) {
        if !condition { ok = false; print("FAIL CRUD: \(label)") }
    }

    // 폴더 생성·중첩·이름 변경
    guard let a = ScriptStore.createFolder(name: "LG AX") else {
        print("FAIL CRUD: 폴더 생성"); return false
    }
    guard let b = ScriptStore.createFolder(name: "1차수", parentID: a.id) else {
        print("FAIL CRUD: 중첩 폴더 생성"); return false
    }
    guard let c = ScriptStore.createFolder(name: "손자", parentID: b.id) else {
        print("FAIL CRUD: 3단 폴더 생성"); return false
    }
    check("빈 이름 폴더 거부", ScriptStore.createFolder(name: "   ") == nil)
    check("없는 부모 거부", ScriptStore.createFolder(name: "x", parentID: "없는폴더") == nil)
    check("이름 변경", ScriptStore.renameFolder(id: a.id, to: "LG 인화원"))
    check("빈 이름 변경 거부", ScriptStore.renameFolder(id: a.id, to: "  ") == false)
    check("이름 반영", ScriptStore.loadLibrary().folders.first { $0.id == a.id }?.name == "LG 인화원")

    // ★ 순환 이동 거부 — 이걸 놓치면 트리가 끊겨 대본이 통째로 사라진 것처럼 보인다
    let snapshot = ScriptStore.loadLibrary()
    check("자기 자신을 부모로 거부", ScriptStore.moveFolder(id: a.id, toParent: a.id) == false)
    check("자식을 부모로 거부", ScriptStore.moveFolder(id: a.id, toParent: b.id) == false)
    check("손자를 부모로 거부", ScriptStore.moveFolder(id: a.id, toParent: c.id) == false)
    check("거부 시 라이브러리 무변경", ScriptStore.loadLibrary() == snapshot)
    check("정상 이동은 허용", ScriptStore.moveFolder(id: c.id, toParent: nil))

    // 대본 생성·이동
    guard let s1 = ScriptStore.createScript(title: "오프닝", in: a.id, text: "본문1"),
          let s2 = ScriptStore.createScript(title: "데모", in: a.id, text: "본문2"),
          let s3 = ScriptStore.createScript(title: "마무리", in: a.id, text: "본문3") else {
        print("FAIL CRUD: 대본 생성"); return false
    }
    func orderIn(_ folder: String?) -> [String] {
        ScriptStore.loadLibrary().scripts
            .filter { $0.folderID == folder }
            .sorted { $0.sortIndex < $1.sortIndex }
            .map(\.title)
    }
    check("생성 순서", orderIn(a.id) == ["오프닝", "데모", "마무리"])

    // ★★ 오프바이원 — at: 은 **원래 목록 기준 삽입 지점**이다(NSOutlineView 드롭 좌표계).
    //     [오프닝,데모,마무리] 에서 0번을 at:2 로= "데모와 마무리 사이" → [데모,오프닝,마무리].
    //     보정을 빼면 한 칸 밀려 [데모,마무리,오프닝] 이 된다.
    check("at:2 = 사이에 끼움", ScriptStore.moveScript(id: s1, toFolder: a.id, at: 2))
    check("결과 [데모,오프닝,마무리]", orderIn(a.id) == ["데모", "오프닝", "마무리"])
    check("sortIndex 재정규화",
          ScriptStore.loadLibrary().scripts.filter { $0.folderID == a.id }
              .map(\.sortIndex).sorted() == [0, 1, 2])

    // 맨 끝으로 = 원소 개수와 같은 인덱스
    check("at:3 = 맨 끝", ScriptStore.moveScript(id: s1, toFolder: a.id, at: 3))
    check("결과 [데모,마무리,오프닝]", orderIn(a.id) == ["데모", "마무리", "오프닝"])
    // 앞쪽으로 옮길 때는 보정하지 않는다(당겨지지 않으므로)
    check("at:0 = 맨 앞", ScriptStore.moveScript(id: s1, toFolder: a.id, at: 0))
    check("결과 [오프닝,데모,마무리]", orderIn(a.id) == ["오프닝", "데모", "마무리"])

    // 폴더 간 이동 / 루트 복귀
    check("다른 폴더로 이동", ScriptStore.moveScript(id: s2, toFolder: b.id))
    check("이동 반영", orderIn(b.id) == ["데모"])
    check("루트로 이동", ScriptStore.moveScript(id: s3, toFolder: nil))
    check("루트 반영", orderIn(nil).contains("마무리"))
    check("없는 폴더로 이동 거부", ScriptStore.moveScript(id: s3, toFolder: "없음") == false)

    // 삭제 → 복원 왕복 (본문 바이트까지)
    let bodyBefore = ScriptStore.read(id: s3)
    guard let bundle = ScriptStore.deleteScript(id: s3) else {
        print("FAIL CRUD: 대본 삭제"); return false
    }
    check("색인에서 제거", ScriptStore.loadLibrary().scripts.contains { $0.id == s3 } == false)
    check("scripts/ 에서 사라짐", ScriptStore.exists(id: s3) == false)
    check("휴지통에 존재", bundle.scripts.first?.trashedFile
        .map { FileManager.default.fileExists(atPath: $0.path) } == true)
    check("복원 성공", ScriptStore.restore(bundle))
    check("복원 후 본문 동일", ScriptStore.read(id: s3) == bodyBefore)
    check("복원 후 색인 복귀", ScriptStore.loadLibrary().scripts.contains { $0.id == s3 })
    check("중복 복원 거부", ScriptStore.restore(bundle) == false)

    // 폴더 삭제 — 승격
    let promoted = ScriptStore.deleteFolder(id: b.id, strategy: .promoteChildren)
    check("승격 삭제 성공", promoted != nil)
    check("자식 대본이 부모로 승격",
          ScriptStore.loadLibrary().scripts.first { $0.id == s2 }?.folderID == a.id)
    check("승격 시 본문 유지", ScriptStore.exists(id: s2))

    // 폴더 삭제 — 내용까지
    guard let d = ScriptStore.createFolder(name: "버릴 폴더"),
          let s4 = ScriptStore.createScript(title: "버려질 대본", in: d.id, text: "x") else {
        print("FAIL CRUD: 삭제용 폴더 구성"); return false
    }
    check("내용 삭제 성공", ScriptStore.deleteFolder(id: d.id, strategy: .deleteContents) != nil)
    check("폴더 제거", ScriptStore.loadLibrary().folders.contains { $0.id == d.id } == false)
    check("대본도 제거", ScriptStore.loadLibrary().scripts.contains { $0.id == s4 } == false)
    check("파일도 이동됨", ScriptStore.exists(id: s4) == false)

    // 복제
    let dup = ScriptStore.duplicateScript(id: s1)
    check("복제 성공", dup != nil)
    check("복제 본문 동일", dup.flatMap { ScriptStore.read(id: $0) } == ScriptStore.read(id: s1))

    // ★ 쓰기 차단 상태에서 모든 CRUD 가 거부되는가
    resetSupportDirForTest()
    _ = ScriptStore.createFolder(name: "before")
    try? "{{{".data(using: .utf8)!.write(to: ScriptStore.libraryURL, options: .atomic)
    _ = ScriptStore.loadLibraryDetailed()               // 래치 켜짐
    let frozen = try? Data(contentsOf: ScriptStore.libraryURL)
    check("차단: createFolder", ScriptStore.createFolder(name: "n") == nil)
    check("차단: createScript", ScriptStore.createScript(title: "n") == nil)
    check("차단: renameFolder", ScriptStore.renameFolder(id: "x", to: "y") == false)
    check("차단: moveScript", ScriptStore.moveScript(id: "x", toFolder: nil) == false)
    check("차단: deleteScript", ScriptStore.deleteScript(id: "x") == nil)
    check("차단: deleteFolder", ScriptStore.deleteFolder(id: "x") == nil)
    check("차단 중 파일 무변경", (try? Data(contentsOf: ScriptStore.libraryURL)) == frozen)

    print("\(ok ? "PASS" : "FAIL") 폴더·대본 CRUD (순환거부·오프바이원·삭제복원·차단)")
    resetSupportDirForTest()
    return ok
}

/// E. 트리 빌더 — 순수 함수라 파일도 창도 필요 없다.
func runLibraryTreeSelfTest() -> Bool {
    var ok = true
    func check(_ label: String, _ condition: Bool) {
        if !condition { ok = false; print("FAIL 트리: \(label)") }
    }
    let now = Date()
    func folder(_ id: String, _ parent: String?, _ order: Int = 0) -> ScriptFolder {
        ScriptFolder(id: id, name: "F-\(id)", parentID: parent, sortIndex: order,
                     createdAt: now, updatedAt: now)
    }
    func script(_ id: String, _ folder: String?, _ order: Int = 0) -> ScriptMeta {
        ScriptMeta(id: id, title: "S-\(id)", createdAt: now, updatedAt: now,
                   folderID: folder, sortIndex: order)
    }

    // 3단 중첩
    var lib = ScriptLibrary()
    lib.folders = [folder("a", nil), folder("b", "a"), folder("c", "b")]
    lib.scripts = [script("s1", "c"), script("s2", nil)]
    var roots = LibraryTree.build(from: lib)
    check("최상위 2개(a + s2)", roots.count == 2)
    check("총 노드 5개", LibraryTree.count(roots) == 5)
    check("폴더가 대본보다 앞", roots.first?.isFolder == true)
    check("3단 깊이", roots.first?.children.first?.children.first?.id == "c")

    // ★ 고아 대본 — 없는 폴더를 가리켜도 버리지 않는다
    lib = ScriptLibrary()
    lib.folders = [folder("a", nil)]
    lib.scripts = [script("orphan", "사라진폴더"), script("normal", "a")]
    roots = LibraryTree.build(from: lib)
    check("고아 대본 최상위 승격", roots.contains { $0.id == "orphan" })
    check("총 노드 수 보존(3)", LibraryTree.count(roots) == 3)

    // ★ 폴더 순환 — 파일에 A→B→A 가 들어 있어도 무한루프 없이 유한 트리
    lib = ScriptLibrary()
    lib.folders = [folder("x", "y"), folder("y", "x")]
    lib.scripts = [script("s", "x")]
    roots = LibraryTree.build(from: lib)
    check("순환에도 노드 3개 유지", LibraryTree.count(roots) == 3)
    check("순환 폴더가 최상위로", roots.contains { $0.id == "x" } || roots.contains { $0.id == "y" })

    // 정렬 규칙
    lib = ScriptLibrary()
    lib.folders = [folder("f2", nil, 1), folder("f1", nil, 0)]
    lib.scripts = [script("s2", nil, 1), script("s1", nil, 0)]
    roots = LibraryTree.build(from: lib)
    check("정렬: 폴더(순서) 뒤 대본(순서)", roots.map(\.id) == ["f1", "f2", "s1", "s2"])

    print("\(ok ? "PASS" : "FAIL") 라이브러리 트리 (중첩·고아승격·순환방어·정렬)")
    return ok
}

/// D. 라이브러리 창 — 창을 화면에 띄우지 않고 레이아웃과 창 정책을 검사한다.
func runLibraryWindowLayoutSelfTest() -> Bool {
    guard resetSupportDirForTest() else {
        print("PASS 라이브러리 창 레이아웃 (SHADOWCUE_SUPPORT_DIR 없음 — 건너뜀)")
        return true
    }
    var ok = true
    func check(_ label: String, _ condition: Bool) {
        if !condition { ok = false; print("FAIL 라이브러리 창: \(label)") }
    }

    // 창 프레임 복원이 검사를 흔들지 않도록 저장값을 비운다.
    SettingsStore.shared.update {
        $0.libraryWindowFrame = nil
        $0.librarySidebarWidth = 260
    }
    _ = ScriptStore.createScript(title: "테스트 대본", text: "본문")

    let prompter = PrompterWindowController()
    let library = ScriptLibraryWindowController(prompterController: prompter)
    guard let window = library.window else {
        print("FAIL 라이브러리 창: 창 없음"); return false
    }
    window.setFrame(NSRect(x: 0, y: 0, width: 960, height: 640), display: false)
    window.contentView?.layoutSubtreeIfNeeded()

    guard let probe = library.layoutProbeForTest else {
        print("FAIL 라이브러리 창: 프로브 없음"); return false
    }

    // ★ 스텔스 — 이 창은 촬영 중에 열린다. 회귀하면 대본이 통째로 녹화에 찍힌다.
    check("sharingType == .none", window.sharingType == .none)
    check("floating 레벨", window.level == .floating)
    check("모든 스페이스", window.collectionBehavior.contains(.canJoinAllSpaces))
    check("전체화면 보조", window.collectionBehavior.contains(.fullScreenAuxiliary))
    // 최소화 차단은 styleMask 로 한다. 버튼을 감추면 제목이 확대 버튼과 겹치므로
    // "감춰졌는지" 가 아니라 "동작하지 않는지" 를 본다.
    check("styleMask 에 miniaturizable 없음", !window.styleMask.contains(.miniaturizable))
    check("최소화 버튼 비활성",
          window.standardWindowButton(.miniaturizeButton)?.isEnabled != true)
    check("최소화 버튼을 감추지 않음(제목 겹침 방지)",
          window.standardWindowButton(.miniaturizeButton)?.isHidden != true)

    // 레이아웃
    let contentWidth = window.contentView?.bounds.width ?? 0
    check("pane 2개", probe.split.subviews.count == 2)
    let sidebarWidth = probe.split.subviews[0].frame.width
    let editorPaneWidth = probe.split.subviews[1].frame.width
    let sum = sidebarWidth + editorPaneWidth + probe.split.dividerThickness
    check("pane 폭 합 == 콘텐츠 폭", abs(sum - contentWidth) < 1.5)
    // ★ "큰 편집기" 요구의 회귀 방지 — 설정 창의 410×100 상자보다 확실히 크다는 걸 수치로 못 박는다.
    check("편집기 폭 > 500", library.editorScrollFrameForTest.width > 500)
    check("편집기 높이 > 400", library.editorScrollFrameForTest.height > 400)
    check("편집기가 FineUndoTextView", probe.editor is FineUndoTextView)
    // 셀을 실제로 만들어 내는지 본다. 데이터 소스가 멀쩡해도 viewFor 가 nil 을 돌려주면
    // 행 수만 맞고 화면은 비어 보인다 — 행 수 단정만으로는 안 잡히는 실패다.
    if let first = probe.outline.item(atRow: 0) {
        let cell = library.outlineView(probe.outline,
                                       viewFor: probe.outline.outlineTableColumn,
                                       item: first) as? NSTableCellView
        check("셀 뷰 생성됨", cell != nil)
        check("셀에 제목 표시", (cell?.textField?.stringValue.isEmpty == false))
    } else {
        check("행이 하나 이상", false)
    }

    // 리사이즈 후 — 사이드바는 고정, 편집기가 흡수해야 한다
    window.setFrame(NSRect(x: 0, y: 0, width: 1280, height: 800), display: false)
    window.contentView?.layoutSubtreeIfNeeded()
    let widerSidebar = probe.split.subviews[0].frame.width
    let widerEditor = probe.split.subviews[1].frame.width
    check("리사이즈 후 사이드바 유지", abs(widerSidebar - sidebarWidth) < 1.5)
    check("리사이즈 후 편집기 확장", widerEditor > editorPaneWidth + 200)

    // 트리에 대본이 보이는가
    check("대본이 트리에 나타남", probe.outline.numberOfRows >= 1)

    // ★ 펼침·선택 복원 — 창을 만드는 시점에 아웃라인이 비어 있어서, 거기서 읽은 빈 값을
    //   그대로 저장하면 지난 실행의 펼침이 지워지고 폴더 안 대본은 선택 복원까지 실패한다.
    //   (실기기에서 그대로 재현됐다 — 폴더가 다 접힌 채 뜨고 편집기가 비어 있었다)
    guard let folder = ScriptStore.createFolder(name: "복원폴더"),
          let nested = ScriptStore.createScript(title: "폴더 안 대본", in: folder.id, text: "안쪽") else {
        print("FAIL 라이브러리 창: 복원 테스트용 구성"); return false
    }
    SettingsStore.shared.update {
        $0.libraryExpandedFolderIDs = [folder.id]
        $0.libraryLastSelectedID = nested
    }
    let reopened = ScriptLibraryWindowController(prompterController: prompter)
    guard let reprobe = reopened.layoutProbeForTest else {
        print("FAIL 라이브러리 창: 재생성 프로브 없음"); return false
    }
    let expandedNow = (0..<reprobe.outline.numberOfRows).compactMap {
        reprobe.outline.item(atRow: $0) as? LibraryNode
    }.filter { $0.isFolder && reprobe.outline.isItemExpanded($0) }.map(\.id)
    check("폴더 펼침 복원", expandedNow.contains(folder.id))
    check("설정의 펼침 상태가 지워지지 않음",
          SettingsStore.shared.settings.libraryExpandedFolderIDs.contains(folder.id))
    let selectedNow = reprobe.outline.selectedRowIndexes.compactMap {
        (reprobe.outline.item(atRow: $0) as? LibraryNode)?.id
    }
    check("폴더 안 대본 선택 복원", selectedNow == [nested])
    check("선택된 대본 본문이 편집기에", reprobe.editor.string == "안쪽")

    print("\(ok ? "PASS" : "FAIL") 라이브러리 창 레이아웃 "
          + "(사이드바 \(Int(sidebarWidth)) / 편집기 \(Int(library.editorScrollFrameForTest.width))"
          + "×\(Int(library.editorScrollFrameForTest.height)), 스텔스=\(window.sharingType == .none))")
    resetSupportDirForTest()
    return ok
}

/// F. 삭제 3단 계약 — 유령 파일과 활성 대본 증발을 막는다.
func runScriptDeletionSyncSelfTest() -> Bool {
    guard resetSupportDirForTest() else {
        print("PASS 대본 삭제 동기화 (SHADOWCUE_SUPPORT_DIR 없음 — 건너뜀)")
        return true
    }
    var ok = true
    func check(_ label: String, _ condition: Bool) {
        if !condition { ok = false; print("FAIL 삭제 동기화: \(label)") }
    }

    guard let a = ScriptStore.createScript(title: "A", text: "본문 A"),
          let b = ScriptStore.createScript(title: "B", text: "본문 B") else {
        print("FAIL 삭제 동기화: 구성"); return false
    }
    SettingsStore.shared.update { $0.activeScriptID = a }

    let prompter = PrompterWindowController()
    prompter.loadActiveScript()
    check("활성 = A", prompter.activeScriptID == a)

    // ★ 예약된 쓰기가 취소되는가 — 안 되면 1.5초 뒤 디바운스가 지운 파일을 되살린다
    prompter.updateScript("고치는 중")
    check("쓰기 예약됨", prompter.hasPendingScriptWriteForTest)
    prompter.prepareForDeletion(of: [a])
    check("활성 대본 삭제 전 예약 취소", prompter.hasPendingScriptWriteForTest == false)

    // 삭제 → 활성 승계
    check("삭제 성공", ScriptStore.deleteScript(id: a) != nil)
    prompter.libraryDidChange(deleted: [a])
    check("활성이 A 가 아님", prompter.activeScriptID != a)
    check("활성이 B 로 승계", prompter.activeScriptID == b)
    check("승계된 대본 파일 존재", prompter.activeScriptID.map { ScriptStore.exists(id: $0) } == true)
    check("지운 파일은 되살아나지 않음", ScriptStore.exists(id: a) == false)

    // 비대상 삭제일 때는 예약을 취소하지 않고 **확정**한다(지우는 김에 다른 대본을 잃을 이유가 없다)
    prompter.updateScript("B 를 고치는 중")
    check("B 쓰기 예약됨", prompter.hasPendingScriptWriteForTest)
    prompter.prepareForDeletion(of: ["관계없는id"])
    check("비대상이면 확정 저장", ScriptStore.read(id: b) == "B 를 고치는 중")

    // 전부 지우면 새로 만든다
    for meta in ScriptStore.loadLibrary().scripts { _ = ScriptStore.deleteScript(id: meta.id) }
    prompter.libraryDidChange(deleted: Set([b]))
    let survivor = prompter.activeScriptID
    check("전부 지운 뒤 새 대본 생성", survivor != nil)
    check("새 대본 파일 존재", survivor.map { ScriptStore.exists(id: $0) } == true)
    check("새 대본이 색인에 있음",
          ScriptStore.loadLibrary().scripts.contains { $0.id == survivor })

    print("\(ok ? "PASS" : "FAIL") 대본 삭제 동기화 (예약취소·활성승계·유령파일 방지)")
    resetSupportDirForTest()
    return ok
}

/// H. 우클릭 메뉴 구성과 액션 배선.
///
/// 이 부분은 GUI 로 검증하기 어렵다 — 합성 클릭은 NSMenu 의 자체 이벤트 추적 루프에서
/// 잘 먹지 않아서, 실기기 시도에서 좌표가 맞는데도 항목이 실행되지 않았다.
/// 그래서 메뉴를 만들고 액션을 직접 호출하는 경로로 검사한다.
func runLibraryContextMenuSelfTest() -> Bool {
    guard resetSupportDirForTest() else {
        print("PASS 라이브러리 우클릭 메뉴 (SHADOWCUE_SUPPORT_DIR 없음 — 건너뜀)")
        return true
    }
    var ok = true
    func check(_ label: String, _ condition: Bool) {
        if !condition { ok = false; print("FAIL 우클릭 메뉴: \(label)") }
    }

    guard let lg = ScriptStore.createFolder(name: "LG"),
          let yt = ScriptStore.createFolder(name: "YT"),
          let script = ScriptStore.createScript(title: "오프닝", in: lg.id, text: "본문") else {
        print("FAIL 우클릭 메뉴: 구성"); return false
    }
    SettingsStore.shared.update { $0.libraryWindowFrame = nil; $0.libraryExpandedFolderIDs = [lg.id, yt.id] }

    let prompter = PrompterWindowController()
    let library = ScriptLibraryWindowController(prompterController: prompter)
    guard let menu = library.contextMenuForTest(selecting: script) else {
        print("FAIL 우클릭 메뉴: 메뉴 없음"); return false
    }

    let titles = menu.items.map(\.title).filter { !$0.isEmpty }
    for expected in ["새 대본", "새 폴더", "이름 변경", "복제", "프롬프터에 올리기", "이동", "삭제"] {
        check("항목 '\(expected)'", titles.contains(expected))
    }

    // ★ 이동 서브메뉴 — 최상위 + 모든 폴더가 나와야 한다
    guard let moveItem = menu.items.first(where: { $0.title == "이동" }),
          let moveMenu = moveItem.submenu else {
        print("FAIL 우클릭 메뉴: 이동 서브메뉴 없음"); return false
    }
    check("이동에 '최상위로'", moveMenu.items.contains { $0.title == "최상위로" })
    check("이동에 폴더 2개", moveMenu.items.filter { $0.representedObject is String }.count == 2)

    // ★ 실제로 옮겨지는가 (메뉴 액션 배선)
    guard let toYT = moveMenu.items.first(where: { ($0.representedObject as? String) == yt.id }) else {
        print("FAIL 우클릭 메뉴: YT 항목 없음"); return false
    }
    library.performMenuItemForTest(toYT)
    check("이동 실행됨",
          ScriptStore.loadLibrary().scripts.first { $0.id == script }?.folderID == yt.id)

    // 최상위로 되돌리기
    if let toRoot = moveMenu.items.first(where: { $0.title == "최상위로" }) {
        library.performMenuItemForTest(toRoot)
        check("최상위로 이동",
              ScriptStore.loadLibrary().scripts.first { $0.id == script }?.folderID == nil)
    }

    // 새 대본은 **우클릭한 항목이 속한 폴더**에 만들어져야 한다
    guard let inLG = library.contextMenuForTest(selecting: lg.id),
          let newScript = inLG.items.first(where: { $0.title == "새 대본" }) else {
        print("FAIL 우클릭 메뉴: 폴더 메뉴 없음"); return false
    }
    let before = ScriptStore.loadLibrary().scripts.count
    library.performMenuItemForTest(newScript)
    let after = ScriptStore.loadLibrary().scripts
    check("새 대본 생성", after.count == before + 1)
    check("새 대본이 우클릭한 폴더 안에",
          after.contains { $0.folderID == lg.id && $0.title == "새 대본" })

    // 복제
    if let dupMenu = library.contextMenuForTest(selecting: script),
       let dup = dupMenu.items.first(where: { $0.title == "복제" }) {
        let n = ScriptStore.loadLibrary().scripts.count
        library.performMenuItemForTest(dup)
        check("복제 실행", ScriptStore.loadLibrary().scripts.count == n + 1)
        check("복제본 제목", ScriptStore.loadLibrary().scripts.contains { $0.title == "오프닝 사본" })
    }

    // ★ 이름이 그대로면 저장을 시도하지 않는다.
    //   편집 세션은 사용자가 Return 을 치지 않아도 닫힌다(선택 변경·트리 재구성).
    //   그때마다 저장하면, 잠긴 상태에서 **행을 클릭하는 것만으로 모달이 떠 앱이 멈춘다.**
    //   실제로 이 테스트가 그 지점에서 영구히 멈춰 버그를 찾았다.
    let renameCount = ScriptStore.loadLibrary().scripts.count
    library.simulateEndEditingForTest(id: script, text: "오프닝")   // 원래 이름 그대로
    check("동일 이름은 저장 시도 없음", ScriptStore.loadLibrary().scripts.count == renameCount)
    library.simulateEndEditingForTest(id: script, text: "   ")      // 빈 입력
    check("빈 이름은 원래 이름 유지",
          ScriptStore.loadLibrary().scripts.first { $0.id == script }?.title == "오프닝")
    library.simulateEndEditingForTest(id: script, text: "바뀐 이름")
    check("바뀐 이름은 저장됨",
          ScriptStore.loadLibrary().scripts.first { $0.id == script }?.title == "바뀐 이름")

    // 쓰기가 잠기면 구조 변경 항목이 비활성이어야 한다
    try? "{{{".data(using: .utf8)!.write(to: ScriptStore.libraryURL, options: .atomic)
    _ = ScriptStore.loadLibraryDetailed()
    if let locked = library.contextMenuForTest(selecting: script) {
        let create = locked.items.first { $0.title == "새 대본" }
        check("잠긴 상태에서 '새 대본' 비활성", create?.isEnabled == false)
    }
    // 잠긴 상태에서 같은 이름으로 편집이 끝나도 모달이 뜨면 안 된다.
    // (뜨면 이 줄에서 테스트가 영영 멈추므로, 통과 자체가 검증이다)
    library.simulateEndEditingForTest(id: script, text: "바뀐 이름")
    check("잠긴 상태 + 동일 이름 → 멈추지 않음", true)

    print("\(ok ? "PASS" : "FAIL") 라이브러리 우클릭 메뉴 (구성·이동·생성·복제·잠금)")
    resetSupportDirForTest()
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
    // 격리 확인을 **먼저** 한다 — 격리가 깨진 상태에서 파괴적 테스트가 도는 최악의 순서를 피한다.
    let supportDirOK = runSupportDirIsolationSelfTest()
    let migrationOK = runLibraryMigrationSelfTest()
    let corruptionOK = runLibraryCorruptionGuardSelfTest()
    let decoderOK = runSettingsDecoderCoverageSelfTest()
    let crudOK = runFolderCRUDSelfTest()
    let treeOK = runLibraryTreeSelfTest()
    let libWindowOK = runLibraryWindowLayoutSelfTest()
    let deleteSyncOK = runScriptDeletionSyncSelfTest()
    let ctxMenuOK = runLibraryContextMenuSelfTest()

    let persistenceOK = runPersistenceSelfTest()
    let layoutOK = runSettingsLayoutSelfTest()
    let mirrorOK = runMirrorSelfTest()
    let mirrorLayoutOK = runMirrorPersistsLayoutSelfTest()
    let buttonsOK = runWindowButtonsSelfTest()
    let cheatOK = runCheatSheetSelfTest()
    exit(persistenceOK && layoutOK && mirrorOK && mirrorLayoutOK
         && buttonsOK && cheatOK && supportDirOK
         && migrationOK && corruptionOK && decoderOK && crudOK && treeOK
         && libWindowOK && deleteSyncOK && ctxMenuOK ? 0 : 1)
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
