import SwiftUI

public struct MainPopupView: View {
    @EnvironmentObject var store: HistoryStore
    @EnvironmentObject var windowManager: WindowManager

    public init() {}

    public var body: some View {
        Group {
            if windowManager.showingPreferences {
                PreferencesView(store: store) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        windowManager.showingPreferences = false
                    }
                }
            } else {
                mainContentView
            }
        }
        .frame(minWidth: 720, minHeight: 460)
        .background(
            VisualEffectView(material: .popover, blendingMode: .behindWindow)
                .ignoresSafeArea()
        )
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
    }

    private var mainContentView: some View {
        VStack(spacing: 0) {
            // Header Search & Filter Bar
            SearchAndFilterBar(store: store)
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 10)

            Divider()

            // Main 2-Pane Content
            HStack(spacing: 0) {
                // Left Pane: Flat List
                leftListPane
                    .frame(width: 340)

                Divider()

                // Right Pane: Rich Preview
                ClipPreviewView(
                    item: store.selectedItem,
                    onPaste: {
                        windowManager.pasteSelectedAndHide()
                    },
                    onCopy: {
                        windowManager.copySelectedAndHide()
                    },
                    onTogglePin: {
                        if let item = store.selectedItem {
                            store.togglePin(id: item.id)
                        }
                    },
                    onDelete: {
                        if let item = store.selectedItem {
                            store.delete(id: item.id)
                        }
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxHeight: .infinity)

            Divider()

            // Bottom Status / Shortcut Bar
            bottomShortcutBar
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.4))
        }
    }

    // MARK: - Left List Pane

    private var leftListPane: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 3) {
                    let items = store.filteredItems
                    if items.isEmpty {
                        emptyStateView
                            .padding(.top, 40)
                    } else {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            ClipRowView(
                                item: item,
                                isSelected: item.id == store.selectedItemId,
                                index: index,
                                onSelect: {
                                    store.selectedItemId = item.id
                                },
                                onDoubleClick: {
                                    store.selectedItemId = item.id
                                    windowManager.pasteSelectedAndHide()
                                }
                            )
                            .id(item.id)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
            .onChange(of: store.selectedItemId) { _, newId in
                if let newId = newId {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        proxy.scrollTo(newId, anchor: .center)
                    }
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.15))
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 22))
                .foregroundColor(.secondary.opacity(0.5))
            Text("No history found")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Bottom Shortcut Bar

    private var bottomShortcutBar: some View {
        HStack(spacing: 12) {
            shortcutHint(key: "↵", label: "Paste")
            shortcutHint(key: "Tab", label: "Filter")
            shortcutHint(key: "⌘1-9", label: "Quick")
            shortcutHint(key: "⌘F", label: "Fav")
            shortcutHint(key: "⌘C", label: "Copy")
            shortcutHint(key: "⌘⌫", label: "Del")
            shortcutHint(key: "Esc", label: "Close")

            Spacer()

            Text("\(store.filteredItems.count) items")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Button(action: {
                withAnimation(.easeInOut(duration: 0.15)) {
                    windowManager.showingPreferences = true
                }
            }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Preferences")
        }
    }

    private func shortcutHint(key: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .padding(.horizontal, 4)
                .padding(.vertical, 1.5)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.primary.opacity(0.08))
                )
                .foregroundColor(.primary.opacity(0.8))

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }
}
