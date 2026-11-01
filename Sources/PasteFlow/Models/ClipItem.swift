import Foundation
import SwiftUI
import AppKit

public struct ClipItem: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var timestamp: Date
    public var type: ClipType
    public var plainText: String?
    public var richTextRTF: Data?
    public var htmlContent: String?
    public var imageFileName: String?
    public var imageWidth: Double?
    public var imageHeight: Double?
    public var fileURLs: [String]?
    public var isFavorite: Bool
    public var sourceAppName: String?
    public var sourceAppBundleId: String?
    public var colorHex: String?

    // Backwards compatibility for isPinned
    public var isPinned: Bool {
        get { isFavorite }
        set { isFavorite = newValue }
    }

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        type: ClipType = .text,
        plainText: String? = nil,
        richTextRTF: Data? = nil,
        htmlContent: String? = nil,
        imageFileName: String? = nil,
        imageWidth: Double? = nil,
        imageHeight: Double? = nil,
        fileURLs: [String]? = nil,
        isFavorite: Bool = false,
        sourceAppName: String? = nil,
        sourceAppBundleId: String? = nil,
        colorHex: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.plainText = plainText
        self.richTextRTF = richTextRTF
        self.htmlContent = htmlContent
        self.imageFileName = imageFileName
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.fileURLs = fileURLs
        self.isFavorite = isFavorite
        self.sourceAppName = sourceAppName
        self.sourceAppBundleId = sourceAppBundleId
        self.colorHex = colorHex
    }

    // Custom Decodable to support both isFavorite and legacy isPinned
    enum CodingKeys: String, CodingKey {
        case id, timestamp, type, plainText, richTextRTF, htmlContent
        case imageFileName, imageWidth, imageHeight, fileURLs
        case isFavorite, isPinned, sourceAppName, sourceAppBundleId, colorHex
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        self.type = try container.decode(ClipType.self, forKey: .type)
        self.plainText = try container.decodeIfPresent(String.self, forKey: .plainText)
        self.richTextRTF = try container.decodeIfPresent(Data.self, forKey: .richTextRTF)
        self.htmlContent = try container.decodeIfPresent(String.self, forKey: .htmlContent)
        self.imageFileName = try container.decodeIfPresent(String.self, forKey: .imageFileName)
        self.imageWidth = try container.decodeIfPresent(Double.self, forKey: .imageWidth)
        self.imageHeight = try container.decodeIfPresent(Double.self, forKey: .imageHeight)
        self.fileURLs = try container.decodeIfPresent([String].self, forKey: .fileURLs)
        self.sourceAppName = try container.decodeIfPresent(String.self, forKey: .sourceAppName)
        self.sourceAppBundleId = try container.decodeIfPresent(String.self, forKey: .sourceAppBundleId)
        self.colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex)

        // Read isFavorite or legacy isPinned
        if let fav = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) {
            self.isFavorite = fav
        } else if let pin = try container.decodeIfPresent(Bool.self, forKey: .isPinned) {
            self.isFavorite = pin
        } else {
            self.isFavorite = false
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(plainText, forKey: .plainText)
        try container.encodeIfPresent(richTextRTF, forKey: .richTextRTF)
        try container.encodeIfPresent(htmlContent, forKey: .htmlContent)
        try container.encodeIfPresent(imageFileName, forKey: .imageFileName)
        try container.encodeIfPresent(imageWidth, forKey: .imageWidth)
        try container.encodeIfPresent(imageHeight, forKey: .imageHeight)
        try container.encodeIfPresent(fileURLs, forKey: .fileURLs)
        try container.encode(isFavorite, forKey: .isFavorite)
        try container.encodeIfPresent(sourceAppName, forKey: .sourceAppName)
        try container.encodeIfPresent(sourceAppBundleId, forKey: .sourceAppBundleId)
        try container.encodeIfPresent(colorHex, forKey: .colorHex)
    }

    // MARK: - Computed Properties

    public var title: String {
        switch type {
        case .text, .link, .color:
            guard let text = plainText, !text.isEmpty else { return "(Empty text)" }
            let lines = text.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            return lines.first ?? "(Empty text)"

        case .image:
            if let w = imageWidth, let h = imageHeight {
                return "Image (\(Int(w)) × \(Int(h)))"
            }
            return "Image"

        case .file:
            if let urls = fileURLs, let first = urls.first, let url = URL(string: first) {
                if urls.count > 1 {
                    return "\(url.lastPathComponent) +\(urls.count - 1)"
                }
                return url.lastPathComponent
            }
            return "File"
        }
    }

    public var subtitle: String {
        switch type {
        case .text:
            guard let text = plainText else { return "" }
            let lines = text.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            if lines.count > 1 {
                return lines[1]
            }
            return "\(text.count) chars"

        case .link:
            return plainText ?? ""

        case .color:
            return colorHex ?? (plainText ?? "")

        case .image:
            if let w = imageWidth, let h = imageHeight {
                return "\(Int(w)) × \(Int(h)) px"
            }
            return "PNG Image"

        case .file:
            guard let urls = fileURLs, let first = urls.first, let url = URL(string: first) else { return "" }
            return url.deletingLastPathComponent().path
        }
    }

    public var charCount: Int {
        plainText?.count ?? 0
    }

    public var lineCount: Int {
        guard let text = plainText, !text.isEmpty else { return 0 }
        return text.components(separatedBy: .newlines).count
    }

    public var timeAgo: String {
        let now = Date()
        let interval = now.timeIntervalSince(timestamp)
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else if interval < 86400 * 7 {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: timestamp)
        }
    }

    // MARK: - Color Detection Helpers

    public static func detectColor(from string: String) -> String? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let hexRegex = try? NSRegularExpression(pattern: "^#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$")
        let range = NSRange(location: 0, length: trimmed.utf16.count)
        if hexRegex?.firstMatch(in: trimmed, options: [], range: range) != nil {
            return trimmed.uppercased()
        }
        
        let rgbRegex = try? NSRegularExpression(pattern: "^rgba?\\(\\s*(\\d{1,3})\\s*,\\s*(\\d{1,3})\\s*,\\s*(\\d{1,3})(?:\\s*,\\s*([0-9.]+))?\\s*\\)$", options: .caseInsensitive)
        if let match = rgbRegex?.firstMatch(in: trimmed, options: [], range: range) {
            if let rRange = Range(match.range(at: 1), in: trimmed),
               let gRange = Range(match.range(at: 2), in: trimmed),
               let bRange = Range(match.range(at: 3), in: trimmed),
               let r = Int(trimmed[rRange]), let g = Int(trimmed[gRange]), let b = Int(trimmed[bRange]),
               r <= 255, g <= 255, b <= 255 {
                return String(format: "#%02X%02X%02X", r, g, b)
            }
        }
        return nil
    }

    public static func isURL(_ string: String) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let scheme = url.scheme else { return false }
        return scheme == "http" || scheme == "https"
    }
}
