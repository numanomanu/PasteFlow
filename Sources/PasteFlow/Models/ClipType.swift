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
        case .text: return "Text"
        case .link: return "Link"
        case .color: return "Color"
        case .image: return "Image"
        case .file: return "File"
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
