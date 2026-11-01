import Foundation
import SwiftUI

public enum ClipType: String, Codable, CaseIterable, Identifiable, Sendable {
    case text
    case link
    case color
    case image
    case file
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .text: return "テキスト"
        case .link: return "リンク"
        case .color: return "カラー"
        case .image: return "画像"
        case .file: return "ファイル"
        }
    }
    
    public var iconName: String {
        switch self {
        case .text: return "text.alignleft"
        case .link: return "link"
        case .color: return "paintpalette"
        case .image: return "photo"
        case .file: return "doc"
        }
    }
    
    public var tintColor: Color {
        switch self {
        case .text: return .blue
        case .link: return .cyan
        case .color: return .purple
        case .image: return .orange
        case .file: return .green
        }
    }
}
