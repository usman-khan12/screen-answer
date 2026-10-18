import AppKit
import SwiftUI

@main
enum Main {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory) // menu bar only, no Dock icon
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = Settings.shared
    private var statusItem: NSStatusItem!
    private var askItem: NSMenuItem!
    private var hotKey: HotKey!
    private let panel = AnswerPanel()
    private var settingsWindow: NSWindow?
    private var currentTask: Task<Void, Never>?
    /// Only send the user to System Settings once per launch, not on every press.
    private var openedPrivacySettings = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        hotKey = HotKey { [weak self] in self?.ask() }
        registerHotKey()
        settings.onHotKeyChange = { [weak self] in self?.registerHotKey() }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: "ScreenAnswer")

        let menu = NSMenu()
        askItem = NSMenuItem(title: "", action: #selector(askFromMenu), keyEquivalent: "")
        askItem.target = self
        menu.addItem(askItem)
        menu.addItem(.separator())
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit ScreenAnswer", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        updateAskTitle()

        if settings.apiKey.isEmpty { openSettings() }
    }

    private func registerHotKey() {
        hotKey.register(keyCode: settings.hotKeyCode, modifiers: settings.hotKeyModifiers)
        updateAskTitle()
    }

    private func updateAskTitle() {
        askItem?.title = "Answer Screen  (\(settings.hotKeyDisplay))"
    }

    @objc private func askFromMenu() {
        // Give the menu a moment to close so it isn't in the screenshot.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { self.ask() }
    }

    private func ask() {
        currentTask?.cancel()
        panel.showLoading()
        let prompt = settings.prompt
        let model = settings.model
        let apiKey = settings.apiKey
        let hideAfter = settings.hideAfter
        let copy = settings.copyToClipboard

        currentTask = Task { @MainActor in
            do {
                let jpeg = try await ScreenCapture.captureScreenUnderCursor()
                let answer = try await OpenAIClient.ask(prompt: prompt, imageJPEG: jpeg, model: model, apiKey: apiKey)
                guard !Task.isCancelled else { return }
                if copy {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(answer, forType: .string)
                }
                panel.showAnswer(answer, hideAfter: hideAfter)
            } catch {
                guard !Task.isCancelled, (error as? URLError)?.code != .cancelled else { return }
                panel.showError(error.localizedDescription)
                if case CaptureError.noPermission = error, !openedPrivacySettings {
                    openedPrivacySettings = true
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
                }
            }
        }
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let view = SettingsView { [weak self] recording in
                guard let self else { return }
                recording ? self.hotKey.unregister() : self.registerHotKey()
            }
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = "ScreenAnswer Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
