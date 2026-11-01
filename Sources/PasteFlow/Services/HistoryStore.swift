import Foundation
import SwiftUI
import Combine

public enum FilterCategory: String, CaseIterable, Identifiable {
    case all = "All"
    case favorites = "Favorites"
    case text = "Text"
    case link = "Links"
    case image = "Images"
    case color = "Colors"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .favorites: return "star.fill"
        case .text: return "text.alignleft"
        case .link: return "link"
        case .image: return "photo"
        case .color: return "paintpalette"
        }
    }
}

@MainActor
public final class HistoryStore: ObservableObject {
    public static let shared = HistoryStore()
    
    @Published public var items: [ClipItem] = []
    @Published public var searchText: String = ""
    @Published public var selectedCategory: FilterCategory = .all
    @Published public var selectedItemId: UUID?
    @Published public var maxHistoryCount: Int = 500
    
    private let fileManager = FileManager.default
    private var baseDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("PasteFlow", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    public var imagesDirectory: URL {
        let dir = baseDirectory.appendingPathComponent("images", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    private var historyFileURL: URL {
        baseDirectory.appendingPathComponent("history.json")
    }
    
    // In-memory cache for images with automatic eviction under memory pressure
    private let imageCache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 50 // Limit to 50 images in memory
        cache.totalCostLimit = 60 * 1024 * 1024 // Max 60MB RAM
        return cache
    }()

    private var saveTask: Task<Void, Never>?
    
    public init() {
        loadHistory()
        if items.isEmpty {
            createSampleDataIfNeeded()
        }
        selectedItemId = filteredItems.first?.id
    }
    
    // MARK: - Filtering
    
    public var filteredItems: [ClipItem] {
        var result = items
        
        // Category filter
        switch selectedCategory {
        case .all:
            break
        case .favorites:
            result = result.filter { $0.isFavorite }
        case .text:
            result = result.filter { $0.type == .text }
        case .link:
            result = result.filter { $0.type == .link }
        case .image:
            result = result.filter { $0.type == .image }
        case .color:
            result = result.filter { $0.type == .color }
        }
        
        // Search text filter
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            let terms = query.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            result = result.filter { item in
                let targetText = [
                    item.title,
                    item.subtitle,
                    item.plainText ?? "",
                    item.sourceAppName ?? ""
                ].joined(separator: " ").lowercased()
                
                return terms.allSatisfy { targetText.contains($0) }
            }
        }
        
        // Keep pure chronological order for All (no favorite hijacking)
        return result
    }
    
    public var selectedItem: ClipItem? {
        guard let id = selectedItemId else {
            return filteredItems.first
        }
        return filteredItems.first { $0.id == id } ?? filteredItems.first
    }
    
    // MARK: - Actions
    
    public func add(item: ClipItem) {
        // Check for duplicates with the most recent item
        if let first = items.first, isDuplicate(first, item) {
            // Update timestamp and bring to top
            var updated = first
            updated.timestamp = Date()
            items.removeFirst()
            items.insert(updated, at: 0)
            selectFirstItem()
            scheduleSave()
            return
        }
        
        // If it exists further down, remove it to bring to top
        if let existingIndex = items.firstIndex(where: { isDuplicate($0, item) }) {
            var existing = items.remove(at: existingIndex)
            existing.timestamp = Date()
            items.insert(existing, at: 0)
        } else {
            items.insert(item, at: 0)
        }
        
        // Trim history
        trimHistory()
        selectFirstItem()
        scheduleSave()
    }
    
    public func toggleFavorite(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isFavorite.toggle()
        scheduleSave()
    }

    public func togglePin(id: UUID) {
        toggleFavorite(id: id)
    }
    
    public func delete(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let item = items.remove(at: index)
        
        // Delete image file if present
        if let imageFile = item.imageFileName {
            imageCache.removeObject(forKey: imageFile as NSString)
            let fileURL = imagesDirectory.appendingPathComponent(imageFile)
            try? fileManager.removeItem(at: fileURL)
        }
        
        // Update selection if the deleted item was selected
        if selectedItemId == id {
            selectedItemId = filteredItems.first?.id
        }
        scheduleSave()
    }
    
    public func clearHistory(keepFavorites: Bool = true) {
        if keepFavorites {
            let deletedImages = items.filter { !$0.isFavorite }.compactMap { $0.imageFileName }
            for img in deletedImages {
                try? fileManager.removeItem(at: imagesDirectory.appendingPathComponent(img))
            }
            items.removeAll { !$0.isFavorite }
        } else {
            try? fileManager.removeItem(at: imagesDirectory)
            items.removeAll()
        }
        selectedItemId = items.first?.id
        scheduleSave()
    }

    public func clearHistory(keepPinned: Bool) {
        clearHistory(keepFavorites: keepPinned)
    }
    
    // MARK: - Selection Navigation
    
    public func selectNext() {
        let currentList = filteredItems
        guard !currentList.isEmpty else { return }
        guard let currentId = selectedItemId,
              let currentIndex = currentList.firstIndex(where: { $0.id == currentId }) else {
            selectedItemId = currentList.first?.id
            return
        }
        let nextIndex = min(currentIndex + 1, currentList.count - 1)
        selectedItemId = currentList[nextIndex].id
    }
    
    public func selectPrevious() {
        let currentList = filteredItems
        guard !currentList.isEmpty else { return }
        guard let currentId = selectedItemId,
              let currentIndex = currentList.firstIndex(where: { $0.id == currentId }) else {
            selectedItemId = currentList.first?.id
            return
        }
        let prevIndex = max(currentIndex - 1, 0)
        selectedItemId = currentList[prevIndex].id
    }
    
    public func selectFirstItem() {
        selectedItemId = filteredItems.first?.id
    }
    
    public func selectNextCategory() {
        let all = FilterCategory.allCases
        guard let currentIndex = all.firstIndex(of: selectedCategory) else { return }
        let nextIndex = (currentIndex + 1) % all.count
        selectedCategory = all[nextIndex]
        selectFirstItem()
    }
    
    public func selectPreviousCategory() {
        let all = FilterCategory.allCases
        guard let currentIndex = all.firstIndex(of: selectedCategory) else { return }
        let prevIndex = (currentIndex - 1 + all.count) % all.count
        selectedCategory = all[prevIndex]
        selectFirstItem()
    }
    
    public func selectIndex(_ index: Int) -> ClipItem? {
        let list = filteredItems
        guard index >= 0 && index < list.count else { return nil }
        selectedItemId = list[index].id
        return list[index]
    }
    
    // MARK: - Image Caching Helper
    
    public func saveImage(_ image: NSImage) -> (fileName: String, width: Double, height: Double)? {
        // Downsample excessively huge images (e.g. 4K/8K screenshots) to max 1920px
        let maxDimension: CGFloat = 1920
        let originalSize = image.size
        var targetSize = originalSize
        if originalSize.width > maxDimension || originalSize.height > maxDimension {
            let ratio = min(maxDimension / originalSize.width, maxDimension / originalSize.height)
            targetSize = NSSize(width: originalSize.width * ratio, height: originalSize.height * ratio)
        }

        let resizedImage: NSImage
        if targetSize != originalSize {
            resizedImage = NSImage(size: targetSize)
            resizedImage.lockFocus()
            image.draw(in: NSRect(origin: .zero, size: targetSize),
                       from: NSRect(origin: .zero, size: originalSize),
                       operation: .copy,
                       fraction: 1.0)
            resizedImage.unlockFocus()
        } else {
            resizedImage = image
        }

        guard let tiffData = resizedImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }
        
        let fileName = "\(UUID().uuidString).png"
        let fileURL = imagesDirectory.appendingPathComponent(fileName)
        do {
            try pngData.write(to: fileURL)
            // Store into memory cache
            imageCache.setObject(resizedImage, forKey: fileName as NSString)
            return (fileName, Double(targetSize.width), Double(targetSize.height))
        } catch {
            return nil
        }
    }
    
    public func loadImage(fileName: String) -> NSImage? {
        let key = fileName as NSString
        if let cached = imageCache.object(forKey: key) {
            return cached
        }
        let fileURL = imagesDirectory.appendingPathComponent(fileName)
        guard let image = NSImage(contentsOf: fileURL) else { return nil }
        imageCache.setObject(image, forKey: key)
        return image
    }
    
    // MARK: - Private Persistence
    
    private func isDuplicate(_ a: ClipItem, _ b: ClipItem) -> Bool {
        if a.type != b.type { return false }
        switch a.type {
        case .text, .link, .color:
            return a.plainText == b.plainText
        case .image:
            return a.imageFileName == b.imageFileName
        case .file:
            return a.fileURLs == b.fileURLs
        }
    }
    
    private func trimHistory() {
        let favorites = items.filter { $0.isFavorite }
        var regular = items.filter { !$0.isFavorite }
        if regular.count > maxHistoryCount {
            let overflow = regular.suffix(from: maxHistoryCount)
            for item in overflow {
                if let imageFile = item.imageFileName {
                    try? fileManager.removeItem(at: imagesDirectory.appendingPathComponent(imageFile))
                }
            }
            regular = Array(regular.prefix(maxHistoryCount))
            items = favorites + regular
            items.sort { $0.timestamp > $1.timestamp }
        }
    }
    
    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s debounce
            guard let self = self else { return }
            self.saveHistoryToDisk()
        }
    }
    
    private func saveHistoryToDisk() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(items)
            try data.write(to: historyFileURL, options: .atomic)
        } catch {
            print("Failed to save history: \(error)")
        }
    }
    
    private func loadHistory() {
        guard fileManager.fileExists(atPath: historyFileURL.path) else { return }
        do {
            let data = try Data(contentsOf: historyFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            self.items = try decoder.decode([ClipItem].self, from: data)
        } catch {
            print("Failed to load history: \(error)")
        }
    }
    
    private func createSampleDataIfNeeded() {
        let samples: [ClipItem] = [
            ClipItem(
                timestamp: Date().addingTimeInterval(-120),
                type: .text,
                plainText: "PasteFlow ⚡️ — Blazing-fast, folder-free clipboard manager for macOS.\nPress ⌘ + ⇧ + V to invoke anywhere.",
                isFavorite: true,
                sourceAppName: "Safari"
            ),
            ClipItem(
                timestamp: Date().addingTimeInterval(-300),
                type: .link,
                plainText: "https://github.com",
                isFavorite: false,
                sourceAppName: "Google Chrome"
            ),
            ClipItem(
                timestamp: Date().addingTimeInterval(-600),
                type: .color,
                plainText: "#007AFF",
                isFavorite: false,
                sourceAppName: "Xcode",
                colorHex: "#007AFF"
            ),
            ClipItem(
                timestamp: Date().addingTimeInterval(-1800),
                type: .text,
                plainText: "git commit -m \"feat: keyboard-first clipboard workflow\"",
                isFavorite: false,
                sourceAppName: "Terminal"
            )
        ]
        self.items = samples
        saveHistoryToDisk()
    }
}
