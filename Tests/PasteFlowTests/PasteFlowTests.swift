import Testing
import Foundation
@testable import PasteFlow

@Test func testColorDetection() {
    #expect(ClipItem.detectColor(from: "#FFFFFF") == "#FFFFFF")
    #expect(ClipItem.detectColor(from: "#007aff") == "#007AFF")
    #expect(ClipItem.detectColor(from: "#abc") == "#ABC")
    #expect(ClipItem.detectColor(from: "rgb(255, 0, 128)") == "#FF0080")
    #expect(ClipItem.detectColor(from: "Hello world") == nil)
}

@Test func testURLDetection() {
    #expect(ClipItem.isURL("https://apple.com") == true)
    #expect(ClipItem.isURL("http://localhost:3000") == true)
    #expect(ClipItem.isURL("Not a url") == false)
}

@Test func testClipItemProperties() {
    let item = ClipItem(
        type: .text,
        plainText: "First line of text\nSecond line",
        sourceAppName: "Xcode"
    )

    #expect(item.title == "First line of text")
    #expect(item.subtitle == "Second line")
    #expect(item.charCount == 30)
    #expect(item.lineCount == 2)
}

@Test @MainActor func testHistoryFiltering() {
    let store = HistoryStore()
    store.items = [
        ClipItem(type: .text, plainText: "SwiftUI layout notes", isFavorite: false),
        ClipItem(type: .link, plainText: "https://developer.apple.com", isFavorite: true),
        ClipItem(type: .color, plainText: "#FF3B30", colorHex: "#FF3B30")
    ]

    // Search filter
    store.searchText = "apple"
    #expect(store.filteredItems.count == 1)
    #expect(store.filteredItems.first?.type == .link)

    // Category filter
    store.searchText = ""
    store.selectedCategory = .color
    #expect(store.filteredItems.count == 1)
    #expect(store.filteredItems.first?.type == .color)

    // Tab category navigation
    store.selectedCategory = .all
    store.selectNextCategory()
    #expect(store.selectedCategory == .favorites)
    store.selectPreviousCategory()
    #expect(store.selectedCategory == .all)
}
