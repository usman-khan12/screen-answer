import Carbon
import Foundation
import Security

/// All user-configurable settings. Everything except the API key lives in UserDefaults;
/// the API key lives in the macOS Keychain.
final class Settings: ObservableObject {
    static let shared = Settings()

    static let defaultPrompt = """
    The red circle in this screenshot marks my mouse cursor. \
    Answer ONLY the one question closest to the red circle. \
    Reply on a single line in the form "<question number>. <answer>", \
    using the question's number exactly as shown on screen (e.g. "3. B — mitochondria"). \
    If the question has no number, reply with just the answer. \
    For multiple choice, give the correct option's letter and text. \
    No explanation, no preamble, no restating the question, no markdown.
    """
    static let defaultModel = "gpt-6.1-sol"

    private let defaults = UserDefaults.standard

    @Published var prompt: String { didSet { defaults.set(prompt, forKey: "prompt") } }
    @Published var model: String { didSet { defaults.set(model, forKey: "model") } }
    /// Seconds before the answer bubble hides itself. 0 = stay until you click.
    @Published var hideAfter: Double { didSet { defaults.set(hideAfter, forKey: "hideAfter") } }
    @Published var copyToClipboard: Bool { didSet { defaults.set(copyToClipboard, forKey: "copyToClipboard") } }

    @Published private(set) var hotKeyCode: UInt32
    @Published private(set) var hotKeyModifiers: UInt32
    @Published private(set) var hotKeyDisplay: String

    @Published var apiKey: String { didSet { Keychain.save(apiKey) } }

    /// Called whenever the hotkey changes so the app can re-register it.
    var onHotKeyChange: (() -> Void)?

    private init() {
        prompt = defaults.string(forKey: "prompt") ?? Settings.defaultPrompt
        model = defaults.string(forKey: "model") ?? Settings.defaultModel
        hideAfter = defaults.object(forKey: "hideAfter") as? Double ?? 0
        copyToClipboard = defaults.bool(forKey: "copyToClipboard")
        // Default hotkey: ⌥⇧Space
        hotKeyCode = defaults.object(forKey: "hotKeyCode") as? UInt32 ?? UInt32(kVK_Space)
        hotKeyModifiers = defaults.object(forKey: "hotKeyModifiers") as? UInt32 ?? UInt32(optionKey | shiftKey)
        hotKeyDisplay = defaults.string(forKey: "hotKeyDisplay") ?? "⌥⇧Space"
        apiKey = Keychain.load() ?? ""
    }

    func setHotKey(code: UInt32, modifiers: UInt32, display: String) {
        hotKeyCode = code
        hotKeyModifiers = modifiers
        hotKeyDisplay = display
        defaults.set(code, forKey: "hotKeyCode")
        defaults.set(modifiers, forKey: "hotKeyModifiers")
        defaults.set(display, forKey: "hotKeyDisplay")
        onHotKeyChange?()
    }
}

enum Keychain {
    private static let service = "ScreenAnswer"
    private static let account = "openai-api-key"

    private static var baseQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    static func load() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func save(_ value: String) {
        SecItemDelete(baseQuery as CFDictionary)
        guard !value.isEmpty else { return }
        var query = baseQuery
        query[kSecValueData as String] = Data(value.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(query as CFDictionary, nil)
    }
}
