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
    public var isPinned: Bool
    public var sourceAppName: String?
    public var sourceAppBundleId: String?
    public var colorHex: String?

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
        isPinned: Bool = false,
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
        self.isPinned = isPinned
        self.sourceAppName = sourceAppName
        self.sourceAppBundleId = sourceAppBundleId
        self.colorHex = colorHex
    }

    // MARK: - Computed Properties

    public var title: String {
        switch type {
        case .text, .link, .color:
            guard let text = plainText, !text.isEmpty else { return "（空のテキスト）" }
            let lines = text.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            return lines.first ?? "（空のテキスト）"

        case .image:
            if let w = imageWidth, let h = imageHeight {
                return "画像 (\(Int(w)) × \(Int(h)))"
            }
            return "画像"

        case .file:
            if let urls = fileURLs, let first = urls.first, let url = URL(string: first) {
                if urls.count > 1 {
                    return "\(url.lastPathComponent) ほか \(urls.count - 1) 件"
                }
                return url.lastPathComponent
            }
            return "ファイル"
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
            return "\(text.count) 文字"

        case .link:
            return plainText ?? ""

        case .color:
            return colorHex ?? (plainText ?? "")

        case .image:
            if let w = imageWidth, let h = imageHeight {
                return "\(Int(w)) × \(Int(h)) px"
            }
            return "PNG 画像"

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
            return "たった今"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)分前"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)時間前"
        } else if interval < 86400 * 7 {
            let days = Int(interval / 86400)
            return "\(days)日前"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd"
            return formatter.string(from: timestamp)
        }
    }

    // MARK: - Color Detection Helpers

    public static func detectColor(from string: String) -> String? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        // HEX: #RGB, #RRGGBB, #RRGGBBAA
        let hexRegex = try? NSRegularExpression(pattern: "^#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$")
        let range = NSRange(location: 0, length: trimmed.utf16.count)
        if hexRegex?.firstMatch(in: trimmed, options: [], range: range) != nil {
            return trimmed.uppercased()
        }
        
        // rgb(r, g, b) or rgba(r, g, b, a)
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
