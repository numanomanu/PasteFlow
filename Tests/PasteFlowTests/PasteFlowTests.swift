import Testing
import Foundation
import AppKit
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

@Test @MainActor func testHTMLFilterAndProperties() {
    let plainItem = ClipItem(type: .text, plainText: "Plain text only")
    let htmlItem = ClipItem(type: .text, plainText: "HTML text", htmlContent: "<b>HTML text</b>")
    let rtfItem = ClipItem(type: .text, plainText: "RTF text", richTextRTF: "{\\rtf1 test}".data(using: .utf8))
    let rawHTMLSnippet = ClipItem(type: .text, plainText: "<div><span>Raw HTML</span></div>")
    let vsCodeItem = ClipItem(
        type: .text,
        plainText: "let x = 1",
        htmlContent: "<div style=\"color:#d4d4d4;\"><span style=\"color:#569cd6;\">let</span> x = 1</div>",
        sourceAppName: "Visual Studio Code",
        sourceAppBundleId: "com.microsoft.VSCode"
    )

    #expect(plainItem.hasHTML == false)
    #expect(plainItem.hasRichText == false)

    #expect(htmlItem.hasHTML == true)
    #expect(htmlItem.hasRichText == true)

    #expect(rtfItem.hasHTML == false)
    #expect(rtfItem.hasRichText == true)

    #expect(rawHTMLSnippet.hasHTML == true)
    #expect(rawHTMLSnippet.hasRichText == true)

    // VSCode syntax highlight copy should NOT be classified as HTML
    #expect(vsCodeItem.hasHTML == false)
    #expect(vsCodeItem.hasRichText == false)

    let store = HistoryStore()
    store.items = [plainItem, htmlItem, rtfItem, rawHTMLSnippet, vsCodeItem]

    store.selectedCategory = .html
    #expect(store.filteredItems.count == 3)
    #expect(store.filteredItems.contains { $0.id == htmlItem.id })
    #expect(store.filteredItems.contains { $0.id == rtfItem.id })
    #expect(store.filteredItems.contains { $0.id == rawHTMLSnippet.id })
    #expect(!store.filteredItems.contains { $0.id == plainItem.id })
    #expect(!store.filteredItems.contains { $0.id == vsCodeItem.id })
}

@Test @MainActor func testPasteServicePlainTextOnly() {
    let richItem = ClipItem(
        type: .text,
        plainText: "Hello Plain",
        richTextRTF: "{\\rtf1 Hello RTF}".data(using: .utf8),
        htmlContent: "<b>Hello HTML</b>"
    )

    // 1. Plain text only: true
    PasteService.shared.copyToClipboard(item: richItem, plainTextOnly: true)
    let pb = NSPasteboard.general
    #expect(pb.string(forType: .string) == "Hello Plain")
    #expect(pb.string(forType: .html) == nil)
    #expect(pb.data(forType: .rtf) == nil)

    // 2. Formatted: false
    PasteService.shared.copyToClipboard(item: richItem, plainTextOnly: false)
    #expect(pb.string(forType: .string) == "Hello Plain")
    #expect(pb.string(forType: .html) == "<b>Hello HTML</b>")
    #expect(pb.data(forType: .rtf) != nil)
}
