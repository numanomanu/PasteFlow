import Foundation
import SwiftUI
import Combine

public enum FilterCategory: String, CaseIterable, Identifiable {
    case all = "All"
    case favorites = "Favorites"
    case text = "Text"
    case html = "HTML"
    case link = "Links"
    case image = "Images"
    case color = "Colors"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .favorites: return "star.fill"
        case .text: return "text.alignleft"
        case .html: return "chevron.left.forwardslash.chevron.right"
        case .link: return "link"
        case .image: return "photo"
        case .color: return "paintpalette"
        }
    }
}

@MainActor
public final class HistoryStore: ObservableObject {
    public static let shared = HistoryStore()

    private static let maxHistoryCountKey = "PasteFlow.maxHistoryCount"
    private static let hasLaunchedBeforeKey = "PasteFlow.hasLaunchedBefore"

    @Published public var items: [ClipItem] = [] {
        didSet { recomputeFilteredItems() }
    }
    @Published public var searchText: String = "" {
        didSet { recomputeFilteredItems() }
    }
    @Published public var selectedCategory: FilterCategory = .all {
        didSet { recomputeFilteredItems() }
    }
    @Published public private(set) var filteredItems: [ClipItem] = []
    @Published public var selectedItemId: UUID?

    @Published public var maxHistoryCount: Int {
        didSet {
            UserDefaults.standard.set(maxHistoryCount, forKey: Self.maxHistoryCountKey)
            trimHistory()
            scheduleSave()
        }
    }
    
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
        let savedMax = UserDefaults.standard.integer(forKey: Self.maxHistoryCountKey)
        self.maxHistoryCount = (savedMax > 0) ? savedMax : 500

        loadHistory()

        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: Self.hasLaunchedBeforeKey)
        if !hasLaunchedBefore {
            if items.isEmpty {
                createSampleDataIfNeeded()
            }
            UserDefaults.standard.set(true, forKey: Self.hasLaunchedBeforeKey)
        }

        recomputeFilteredItems()
        selectedItemId = filteredItems.first?.id
    }
    
    // MARK: - Filtering
    
    private func recomputeFilteredItems() {
        var result = items
        
        // Category filter (O(1) precomputed Bool reads!)
        switch selectedCategory {
        case .all:
            break
        case .favorites:
            result = result.filter { $0.isFavorite }
        case .text:
            result = result.filter { $0.type == .text }
        case .html:
            result = result.filter { $0.hasRichText }
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
                terms.allSatisfy { term in
                    item.title.localizedCaseInsensitiveContains(term) ||
                    item.subtitle.localizedCaseInsensitiveContains(term) ||
                    (item.plainText?.localizedCaseInsensitiveContains(term) ?? false) ||
                    (item.sourceAppName?.localizedCaseInsensitiveContains(term) ?? false)
                }
            }
        }
        
        filteredItems = result
    }
    
    public var selectedItem: ClipItem? {
        guard let id = selectedItemId else {
            return filteredItems.first
        }
        return filteredItems.first { $0.id == id } ?? filteredItems.first
    }
    
    // MARK: - Actions
    
    public func add(item: ClipItem) {
        // Check if an identical item already exists anywhere in history
        if let existingIndex = items.firstIndex(where: { isDuplicate($0, item) }) {
            var existing = items.remove(at: existingIndex)
            existing.timestamp = Date()

            // Preserve newer rich formatting if the duplicate copy included HTML/RTF
            if let html = item.htmlContent, !html.isEmpty {
                existing.htmlContent = html
            }
            if let rtf = item.richTextRTF {
                existing.richTextRTF = rtf
            }
            if let appName = item.sourceAppName {
                existing.sourceAppName = appName
            }
            if let bundleId = item.sourceAppBundleId {
                existing.sourceAppBundleId = bundleId
            }
            existing.refreshCachedMetadata()

            // Clean up newly saved duplicate image file to prevent disk leak
            if let newImageFile = item.imageFileName, newImageFile != existing.imageFileName {
                imageCache.removeObject(forKey: newImageFile as NSString)
                try? fileManager.removeItem(at: imagesDirectory.appendingPathComponent(newImageFile))
            }

            items.insert(existing, at: 0)
            selectFirstItem()
            scheduleSave()
            return
        }

        items.insert(item, at: 0)

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
        let oldFilteredIndex = filteredItems.firstIndex(where: { $0.id == id })
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let item = items.remove(at: index)
        
        // Delete image file if present
        if let imageFile = item.imageFileName {
            imageCache.removeObject(forKey: imageFile as NSString)
            let fileURL = imagesDirectory.appendingPathComponent(imageFile)
            try? fileManager.removeItem(at: fileURL)
        }
        
        // Keep selection at the same position in the filtered list
        if selectedItemId == id {
            let newList = filteredItems
            if newList.isEmpty {
                selectedItemId = nil
            } else if let oldIdx = oldFilteredIndex {
                selectedItemId = newList[min(oldIdx, newList.count - 1)].id
            } else {
                selectedItemId = newList.first?.id
            }
        }
        scheduleSave()
    }
    
    public func clearHistory(keepFavorites: Bool = true) {
        if keepFavorites {
            let deletedImages = items.filter { !$0.isFavorite }.compactMap { $0.imageFileName }
            for img in deletedImages {
                imageCache.removeObject(forKey: img as NSString)
                try? fileManager.removeItem(at: imagesDirectory.appendingPathComponent(img))
            }
            items.removeAll { !$0.isFavorite }
        } else {
            imageCache.removeAllObjects()
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
            if a.imageFileName == b.imageFileName { return true }
            if let wA = a.imageWidth, let hA = a.imageHeight,
               let wB = b.imageWidth, let hB = b.imageHeight,
               wA == wB && hA == hB {
                if let fileA = a.imageFileName, let fileB = b.imageFileName {
                    let urlA = imagesDirectory.appendingPathComponent(fileA)
                    let urlB = imagesDirectory.appendingPathComponent(fileB)
                    if let sizeA = try? fileManager.attributesOfItem(atPath: urlA.path)[.size] as? Int64,
                       let sizeB = try? fileManager.attributesOfItem(atPath: urlB.path)[.size] as? Int64,
                       sizeA == sizeB {
                        return true
                    }
                }
            }
            return false
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
                    imageCache.removeObject(forKey: imageFile as NSString)
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
