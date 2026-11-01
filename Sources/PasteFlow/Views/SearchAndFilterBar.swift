import SwiftUI

public struct SearchAndFilterBar: View {
    @ObservedObject var store: HistoryStore
    @EnvironmentObject var windowManager: WindowManager
    @FocusState private var isSearchFocused: Bool

    public init(store: HistoryStore) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 8) {
            // Search Input Field
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.secondary)

                TextField("Search clipboard...", text: $store.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .focused($isSearchFocused)

                if !store.searchText.isEmpty {
                    Button(action: {
                        store.searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
            )

            // Category Filter Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(FilterCategory.allCases) { category in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                store.selectedCategory = category
                                store.selectFirstItem()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: category.iconName)
                                    .font(.system(size: category == .all ? 10 : 11, weight: .semibold))
                                if category == .all || category == .html || store.selectedCategory == category {
                                    Text(category.rawValue)
                                        .font(.system(size: 11, weight: store.selectedCategory == category ? .semibold : .regular))
                                }
                            }
                            .padding(.horizontal, (category == .all || category == .html || store.selectedCategory == category) ? 10 : 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(store.selectedCategory == category ? Color.accentColor : Color.primary.opacity(0.06))
                            )
                            .foregroundColor(store.selectedCategory == category ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                        .help(category.rawValue)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .onAppear {
            isSearchFocused = true
        }
        .onChange(of: windowManager.isVisible) { _, isVisible in
            if isVisible {
                isSearchFocused = true
            }
        }
        .onChange(of: store.searchText) { _, _ in
            store.selectFirstItem()
        }
    }
}
