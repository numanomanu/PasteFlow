import SwiftUI
import AppKit

public struct PreferencesView: View {
    @ObservedObject var store: HistoryStore
    public var onDismiss: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    @State private var selectedLimit: Int = 500
    @State private var isAccessibilityGranted: Bool = PasteService.shared.isAccessibilityTrusted
    @State private var showClearConfirmation: Bool = false
    @ObservedObject private var launchManager = LaunchAtLoginManager.shared

    public init(store: HistoryStore, onDismiss: (() -> Void)? = nil) {
        self.store = store
        self.onDismiss = onDismiss
        _selectedLimit = State(initialValue: store.maxHistoryCount)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Preferences")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Button("Done (Esc)") {
                    if let onDismiss = onDismiss {
                        onDismiss()
                    } else {
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            Divider()

            Form {
                // Section: HotKey
                Section {
                    HStack {
                        Text("Global Shortcut")
                        Spacer()
                        HStack(spacing: 4) {
                            keyCap("⌘")
                            keyCap("⇧")
                            keyCap("V")
                        }
                    }
                } header: {
                    Text("Shortcut")
                }

                // Section: History Storage
                Section {
                    Picker("History Limit", selection: $selectedLimit) {
                        Text("100 items").tag(100)
                        Text("300 items").tag(300)
                        Text("500 items (Recommended)").tag(500)
                        Text("1,000 items").tag(1000)
                    }
                    .onChange(of: selectedLimit) { _, newValue in
                        store.maxHistoryCount = newValue
                    }

                    HStack {
                        Text("Saved Items")
                        Spacer()
                        Text("\(store.items.count)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Button("Clear History (Keep Favorites)") {
                            store.clearHistory(keepFavorites: true)
                        }
                        .foregroundColor(.orange)

                        Spacer()

                        Button("Clear All") {
                            showClearConfirmation = true
                        }
                        .foregroundColor(.red)
                    }
                } header: {
                    Text("History")
                }

                // Section: Accessibility & Auto-paste
                Section {
                    Toggle("Launch at Login", isOn: Binding(
                        get: { launchManager.isEnabled },
                        set: { launchManager.setEnabled($0) }
                    ))

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Accessibility Permission (Auto-paste)")
                                .font(.system(size: 13, weight: .medium))
                            Text(isAccessibilityGranted ? "Granted. Enter automatically pastes into previous app." : "Not granted. Copies to clipboard only.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if isAccessibilityGranted {
                            Label("Enabled", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 12))
                        } else {
                            Button("Enable...") {
                                PasteService.shared.promptForAccessibility()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                    isAccessibilityGranted = PasteService.shared.isAccessibilityTrusted
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                } header: {
                    Text("System Integration")
                }

                // Section: Shortcuts Guide
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        guideRow(key: "⌘ + ⇧ + V", desc: "Toggle PasteFlow popup")
                        guideRow(key: "↑ / ↓", desc: "Navigate history items")
                        guideRow(key: "Tab / ⇧ + Tab", desc: "Cycle filter categories")
                        guideRow(key: "Enter (↵)", desc: "Paste selected item directly")
                        guideRow(key: "⌘ + 1 ~ 9", desc: "Quick paste items 1-9")
                        guideRow(key: "⌘ + F / ⌘ + P", desc: "Toggle favorite status")
                        guideRow(key: "⌘ + C", desc: "Copy without pasting")
                        guideRow(key: "⌘ + ⌫", desc: "Delete item from history")
                        guideRow(key: "Esc", desc: "Close popup")
                    }
                } header: {
                    Text("Keyboard Shortcuts")
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .confirmationDialog(
            "Clear all clipboard history?",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear All (Including Favorites)", role: .destructive) {
                store.clearHistory(keepFavorites: false)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all items from your history, including favorites. This action cannot be undone.")
        }
        .onAppear {
            isAccessibilityGranted = PasteService.shared.isAccessibilityTrusted
            launchManager.checkStatus()
        }
    }

    private func keyCap(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .frame(minWidth: 20, minHeight: 20)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.1))
            )
    }

    private func guideRow(key: String, desc: String) -> some View {
        HStack {
            Text(key)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.accentColor)
                .frame(width: 130, alignment: .leading)
            Text(desc)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }
}
