import SwiftUI

public struct ClipRowView: View {
    public let item: ClipItem
    public let isSelected: Bool
    public let index: Int
    public let onSelect: () -> Void
    public let onDoubleClick: () -> Void

    @State private var isHovered: Bool = false

    public init(
        item: ClipItem,
        isSelected: Bool,
        index: Int,
        onSelect: @escaping () -> Void,
        onDoubleClick: @escaping () -> Void
    ) {
        self.item = item
        self.isSelected = isSelected
        self.index = index
        self.onSelect = onSelect
        self.onDoubleClick = onDoubleClick
    }

    public var body: some View {
        HStack(spacing: 10) {
            // Left icon / thumbnail / color swatch
            leadingIconView
                .frame(width: 24, height: 24)

            // Content preview (title + subtitle)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                        .foregroundColor(isSelected ? .white : .primary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer(minLength: 4)

                    if item.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(isSelected ? .white.opacity(0.9) : .yellow)
                    }
                }

                HStack(spacing: 6) {
                    Text(item.subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                        .lineLimit(1)

                    Spacer()

                    Text(item.timeAgo)
                        .font(.system(size: 10))
                        .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary.opacity(0.8))

                    // Shortcut badge for top 9 items (Cmd+1 ~ Cmd+9)
                    if index < 9 {
                        Text("⌘\(index + 1)")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(isSelected ? Color.white.opacity(0.25) : Color.primary.opacity(0.08))
                            )
                            .foregroundColor(isSelected ? .white : .secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(backgroundFillColor)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture(count: 2) {
            onDoubleClick()
        }
        .onTapGesture(count: 1) {
            onSelect()
        }
    }

    @ViewBuilder
    private var leadingIconView: some View {
        switch item.type {
        case .color:
            if let hex = item.colorHex {
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 18, height: 18)
                    .overlay(Circle().stroke(Color.primary.opacity(0.2), lineWidth: 1))
            } else {
                defaultTypeIcon
            }

        case .image:
            if let fileName = item.imageFileName,
               let nsImage = HistoryStore.shared.loadImage(fileName: fileName) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 24, height: 24)
                    .cornerRadius(4)
                    .clipped()
            } else {
                defaultTypeIcon
            }

        default:
            defaultTypeIcon
        }
    }

    private var defaultTypeIcon: some View {
        Image(systemName: item.type.iconName)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(isSelected ? .white : item.type.tintColor)
            .frame(width: 22, height: 22)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isSelected ? Color.white.opacity(0.2) : item.type.tintColor.opacity(0.12))
            )
    }

    private var backgroundFillColor: Color {
        if isSelected {
            return Color.accentColor
        } else if isHovered {
            return Color.primary.opacity(0.05)
        } else {
            return Color.clear
        }
    }
}

// Extension to parse HEX color
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
