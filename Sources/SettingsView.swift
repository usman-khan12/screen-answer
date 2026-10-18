import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = Settings.shared
    /// Lets the app pause the global hotkey while a new one is being recorded.
    var onRecordingChange: (Bool) -> Void = { _ in }

    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        Form {
            Section("OpenAI") {
                SecureField("API key", text: $settings.apiKey, prompt: Text("sk-..."))
                TextField("Model", text: $settings.model)
                Text("Get a key at platform.openai.com/api-keys. Stored in your Keychain.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Prompt") {
                TextEditor(text: $settings.prompt)
                    .font(.body)
                    .frame(minHeight: 110)
                Button("Reset to default") { settings.prompt = Settings.defaultPrompt }
            }

            Section("Behavior") {
                LabeledContent("Hotkey") {
                    Button(recording ? "Press keys…" : settings.hotKeyDisplay) {
                        recording ? stopRecording() : startRecording()
                    }
                }
                Picker("Hide answer", selection: $settings.hideAfter) {
                    Text("When I click").tag(0.0)
                    Text("After 5 seconds").tag(5.0)
                    Text("After 10 seconds").tag(10.0)
                    Text("After 20 seconds").tag(20.0)
                }
                Toggle("Also copy answer to clipboard", isOn: $settings.copyToClipboard)
            }
        }
        .formStyle(.grouped)
        // A grouped Form scrolls, so it has no natural height; give the window a real size.
        .frame(width: 460, height: 580)
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        recording = true
        onRecordingChange(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Esc cancels
                stopRecording()
                return nil
            }
            let mods = HotKey.carbonModifiers(from: event.modifierFlags)
            guard mods != 0 else { NSSound.beep(); return nil } // require at least one modifier
            settings.setHotKey(code: UInt32(event.keyCode), modifiers: mods,
                               display: HotKey.displayString(for: event))
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if recording { onRecordingChange(false) }
        recording = false
    }
}
