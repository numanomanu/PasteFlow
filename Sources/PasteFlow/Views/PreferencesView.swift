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
                Text("PasteFlow 設定")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Button("完了 (Esc)") {
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
                        Text("起動ショートカット")
                        Spacer()
                        HStack(spacing: 4) {
                            keyCap("⌘")
                            keyCap("⇧")
                            keyCap("V")
                        }
                    }
                } header: {
                    Text("ホットキー")
                }

                // Section: History Storage
                Section {
                    Picker("最大履歴保存件数", selection: $selectedLimit) {
                        Text("100 件").tag(100)
                        Text("300 件").tag(300)
                        Text("500 件 (推奨)").tag(500)
                        Text("1,000 件").tag(1000)
                    }
                    .onChange(of: selectedLimit) { _, newValue in
                        store.maxHistoryCount = newValue
                    }

                    HStack {
                        Text("現在の保存件数")
                        Spacer()
                        Text("\(store.items.count) 件")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Button("お気に入りを残して履歴を消去") {
                            store.clearHistory(keepFavorites: true)
                        }
                        .foregroundColor(.orange)

                        Spacer()

                        Button("全履歴を消去") {
                            showClearConfirmation = true
                        }
                        .foregroundColor(.red)
                    }
                } header: {
                    Text("履歴管理")
                }

                // Section: Accessibility & Auto-paste
                Section {
                    Toggle("ログイン時に自動起動", isOn: Binding(
                        get: { launchManager.isEnabled },
                        set: { launchManager.setEnabled($0) }
                    ))

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("アクセシビリティ権限 (自動ペースト)")
                                .font(.system(size: 13, weight: .medium))
                            Text(isAccessibilityGranted ? "許可されています。Enterで直前のアプリへ自動貼り付けされます。" : "未許可の場合、クリップボードへのコピーのみ実行されます。")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if isAccessibilityGranted {
                            Label("許可済み", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 12))
                        } else {
                            Button("権限を設定...") {
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
                    Text("システム連携")
                }

                // Section: Shortcuts Guide
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        guideRow(key: "⌘ + ⇧ + V", desc: "PasteFlow ポップアップを開く / 閉じる")
                        guideRow(key: "↑ / ↓", desc: "履歴を選択")
                        guideRow(key: "Tab / ⇧ + Tab", desc: "カテゴリフィルタを順に切り替え")
                        guideRow(key: "Enter (↵)", desc: "選択した履歴をペースト")
                        guideRow(key: "⌘ + 1 ~ 9", desc: "1〜9番目の履歴を即座にペースト")
                        guideRow(key: "⌘ + C", desc: "履歴をクリップボードにコピー (貼付なし)")
                        guideRow(key: "⌘ + P / ⌘ + F", desc: "選択アイテムをお気に入り登録 / 解除")
                        guideRow(key: "⌘ + ⌫", desc: "選択アイテムを履歴から削除")
                        guideRow(key: "Esc", desc: "ポップアップを閉じる")
                    }
                } header: {
                    Text("キーボードショートカット")
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .confirmationDialog(
            "すべての履歴を完全に消去しますか？",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("お気に入りも含めてすべて消去", role: .destructive) {
                store.clearHistory(keepFavorites: false)
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("お気に入りに登録された重要なアイテムを含む、すべてのクリップボード履歴が削除されます。この操作は取り消せません。")
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
                .frame(width: 120, alignment: .leading)
            Text(desc)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }
}
