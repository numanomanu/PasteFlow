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

    // Pre-computed cached metadata (not encoded to JSON; O(1) reads during UI rendering & filtering)
    public private(set) var isEditorSource: Bool = false
    public private(set) var hasHTML: Bool = false
    public private(set) var hasRichText: Bool = false
    public private(set) var title: String = ""
    public private(set) var subtitle: String = ""

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
        self.refreshCachedMetadata()
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

        self.refreshCachedMetadata()
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

    // MARK: - Cached Metadata Computation

    private static let editorBundlePrefixes: [String] = [
        "com.microsoft.vscode",
        "com.apple.dt.xcode",
        "com.sublimetext",
        "com.jetbrains",
        "com.todesktop.230313mzl4w4u92", // Cursor
        "dev.zed.zed",
        "com.panic.nova",
        "com.barebones.bbedit",
        "com.github.atom",
        "com.google.android.studio"
    ]

    private static let editorNames: [String] = [
        "visual studio code", "vscode", "xcode", "sublime text",
        "intellij", "pycharm", "webstorm", "goland", "android studio",
        "cursor", "zed", "fleet", "nova", "bbedit"
    ]

    private static let htmlStructuralTags: [String] = [
        "<a ", "<a\n", "<a>", "<b ", "<b>", "<strong", "<i ", "<i>", "<em",
        "<u ", "<u>", "<s ", "<s>", "<del", "<code", "<pre", "<ul", "<ol",
        "<li", "<table", "<tr", "<td", "<th", "<h1", "<h2", "<h3", "<h4",
        "<h5", "<h6", "<blockquote", "<img", "<hr", "<p>", "<p ", "<dl",
        "<dt", "<dd", "</a>", "</b>", "</strong>", "</i>", "</em>", "</u>",
        "</s>", "</del>", "</code>", "</pre>", "</ul>", "</ol>", "</li>",
        "</table>", "</tr>", "</td>", "</th>", "</h", "</blockquote>", "</p>"
    ]

    private static let plainHTMLSignatures: [String] = [
        "<html", "<!doctype", "<div", "<p>", "<p ", "<table", "<a href",
        "<span", "</span>", "</div>", "</p>", "</a>", "</html>", "</table>",
        "<b>", "</b>", "<strong>", "</strong>", "<ul>", "<li>"
    ]

    public mutating func refreshCachedMetadata() {
        // 1. Editor source check
        let bundle = (sourceAppBundleId ?? "").lowercased()
        let name = (sourceAppName ?? "").lowercased()
        let editor = Self.editorBundlePrefixes.contains(where: { bundle.hasPrefix($0) }) ||
                     Self.editorNames.contains(where: { name.contains($0) })
        self.isEditorSource = editor

        // 2. HTML detection (prefix scan, computed ONCE per item!)
        var detectedHTML = false
        if let html = htmlContent, !html.isEmpty {
            let sample = html.prefix(4096).lowercased()
            if Self.htmlStructuralTags.contains(where: { sample.contains($0) }) {
                detectedHTML = true
            } else if !editor && (sample.contains("<p") || sample.contains("<div") || sample.contains("<table")) {
                detectedHTML = true
            }
        }
        if !detectedHTML, let text = plainText, !text.isEmpty, text.contains("<") {
            let sample = text.prefix(4096).lowercased()
            if Self.plainHTMLSignatures.contains(where: { sample.contains($0) }) {
                detectedHTML = true
            }
        }
        self.hasHTML = detectedHTML
        self.hasRichText = detectedHTML || (richTextRTF != nil && !editor)

        // 3. Title & Subtitle (computed ONCE per item!)
        switch type {
        case .text, .link, .color:
            if let text = plainText, !text.isEmpty {
                let sample = text.prefix(1024)
                var firstLine: String? = nil
                var secondLine: String? = nil
                for line in sample.split(whereSeparator: \.isNewline) {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        if firstLine == nil {
                            firstLine = trimmed.count > 120 ? String(trimmed.prefix(120)) : trimmed
                        } else {
                            secondLine = trimmed.count > 120 ? String(trimmed.prefix(120)) : trimmed
                            break
                        }
                    }
                }
                self.title = firstLine ?? "(Empty text)"
                switch type {
                case .text:
                    self.subtitle = secondLine ?? "\(text.count) chars"
                case .link:
                    self.subtitle = text.count > 120 ? String(text.prefix(120)) : text
                case .color:
                    self.subtitle = colorHex ?? self.title
                default:
                    self.subtitle = ""
                }
            } else {
                self.title = "(Empty text)"
                self.subtitle = ""
            }

        case .image:
            if let w = imageWidth, let h = imageHeight {
                self.title = "Image (\(Int(w)) × \(Int(h)))"
                self.subtitle = "\(Int(w)) × \(Int(h)) px"
            } else {
                self.title = "Image"
                self.subtitle = "PNG Image"
            }

        case .file:
            if let urls = fileURLs, let first = urls.first, let url = URL(string: first) {
                self.title = urls.count > 1 ? "\(url.lastPathComponent) +\(urls.count - 1)" : url.lastPathComponent
                self.subtitle = url.deletingLastPathComponent().path
            } else {
                self.title = "File"
                self.subtitle = ""
            }
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
