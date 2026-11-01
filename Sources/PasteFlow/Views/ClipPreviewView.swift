import SwiftUI
import AppKit

public struct ClipPreviewView: View {
    private enum HTMLPreviewMode: String, CaseIterable {
        case text = "Text"
        case rawHTML = "Raw HTML"
    }

    public let item: ClipItem?
    public let onPaste: () -> Void
    public let onPastePlain: () -> Void
    public let onCopy: () -> Void
    public let onTogglePin: () -> Void
    public let onDelete: () -> Void

    @State private var previewMode: HTMLPreviewMode = .text

    public init(
        item: ClipItem?,
        onPaste: @escaping () -> Void,
        onPastePlain: @escaping () -> Void,
        onCopy: @escaping () -> Void,
        onTogglePin: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.item = item
        self.onPaste = onPaste
        self.onPastePlain = onPastePlain
        self.onCopy = onCopy
        self.onTogglePin = onTogglePin
        self.onDelete = onDelete
    }

    public var body: some View {
        if let item = item {
            VStack(spacing: 0) {
                // Header: Type, App, Favorite
                previewHeader(for: item)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                Divider()

                // Main Content View
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        contentBody(for: item)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Divider()

                // Footer metadata & action buttons
                previewFooter(for: item)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
            }
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
        } else {
            VStack(spacing: 10) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(.secondary.opacity(0.4))
                Text("Select an item")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Header

    private func previewHeader(for item: ClipItem) -> some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: item.type.iconName)
                    .foregroundColor(item.type.tintColor)
                    .font(.system(size: 13))
                Text(item.type.displayName)
                    .font(.system(size: 12, weight: .semibold))

                if let app = item.sourceAppName {
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(app)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                if item.hasRichText {
                    Text(item.hasHTML ? "HTML" : "RTF")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.accentColor.opacity(0.15))
                        )
                        .foregroundColor(.accentColor)
                }
            }

            Spacer()

            Button(action: onTogglePin) {
                HStack(spacing: 4) {
                    Image(systemName: item.isFavorite ? "star.fill" : "star")
                        .font(.system(size: 11))
                    Text(item.isFavorite ? "Favorited" : "Favorite")
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(item.isFavorite ? Color.yellow.opacity(0.18) : Color.primary.opacity(0.06))
                )
                .foregroundColor(item.isFavorite ? .orange : .secondary)
            }
            .buttonStyle(.plain)
            .help("Toggle Favorite (⌘F or ⌘P)")
        }
    }

    // MARK: - Body by Type

    @ViewBuilder
    private func contentBody(for item: ClipItem) -> some View {
        switch item.type {
        case .color:
            colorPreviewBody(item: item)

        case .link:
            linkPreviewBody(item: item)

        case .image:
            imagePreviewBody(item: item)

        case .text, .file:
            textPreviewBody(item: item)
        }
    }

    private func textPreviewBody(item: ClipItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if item.hasHTML {
                HStack {
                    Picker("", selection: $previewMode) {
                        ForEach(HTMLPreviewMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 170)

                    Spacer()
                }
                .padding(.bottom, 2)
            }

            if item.hasHTML && previewMode == .rawHTML {
                Text(item.htmlContent ?? "")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(item.plainText ?? "")
                    .font(.system(size: 12, design: isCodeLike(item.plainText) ? .monospaced : .default))
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func linkPreviewBody(item: ClipItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "safari")
                    .font(.system(size: 20))
                    .foregroundColor(.cyan)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Web Link")
                        .font(.system(size: 12, weight: .semibold))
                    if let urlString = item.plainText, let url = URL(string: urlString), let host = url.host {
                        Text(host)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()

                if let urlString = item.plainText, let url = URL(string: urlString) {
                    Button(action: {
                        NSWorkspace.shared.open(url)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10, weight: .bold))
                            Text("Open")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.cyan.opacity(0.08)))

            Text(item.plainText ?? "")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.blue)
                .textSelection(.enabled)
        }
    }

    private func colorPreviewBody(item: ClipItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            let hex = item.colorHex ?? item.plainText ?? "#000000"
            let color = Color(hex: hex)

            // Large Color Card
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color)
                .frame(height: 100)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                )

            // Color values
            VStack(alignment: .leading, spacing: 6) {
                colorValueRow(label: "HEX", value: hex)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
        }
    }

    private func colorValueRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .leading)

            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.primary)

            Spacer()

            Button(action: {
                ClipboardMonitor.shared.suppressNextRecording()
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(value, forType: .string)
            }) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Copy")
        }
    }

    private func imagePreviewBody(item: ClipItem) -> some View {
        VStack(spacing: 12) {
            if let fileName = item.imageFileName,
               let image = HistoryStore.shared.loadImage(fileName: fileName) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 220)
                    .cornerRadius(8)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)

                HStack(spacing: 12) {
                    if let w = item.imageWidth, let h = item.imageHeight {
                        Label("\(Int(w)) × \(Int(h))", systemImage: "aspectratio")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text("Unable to load image")
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Footer

    private func previewFooter(for item: ClipItem) -> some View {
        HStack {
            // Stats (chars, lines)
            HStack(spacing: 8) {
                if item.type == .text {
                    Text("\(item.charCount) chars")
                    Text("•")
                    Text("\(item.lineCount) lines")
                } else {
                    Text(item.timeAgo)
                }
            }
            .font(.system(size: 10))
            .foregroundColor(.secondary)

            Spacer()

            // Quick Action Buttons
            HStack(spacing: 8) {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
                .help("Delete (⌘⌫)")

                Button(action: onCopy) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10))
                        Text("Copy")
                            .font(.system(size: 11))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Copy (⌘C)")

                if item.hasRichText {
                    Button(action: onPastePlain) {
                        HStack(spacing: 4) {
                            Image(systemName: "text.alignleft")
                                .font(.system(size: 10))
                            Text("Plain")
                                .font(.system(size: 11))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Paste as plain text (⇧↵)")
                }

                Button(action: onPaste) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.turn.down.left")
                            .font(.system(size: 10, weight: .bold))
                        Text("Paste")
                            .font(.system(size: 11, weight: .semibold))
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .help("Paste into active app (↵)")
            }
        }
    }

    private func isCodeLike(_ text: String?) -> Bool {
        guard let text = text else { return false }
        let codeSymbols = ["{", "}", "func ", "import ", "const ", "let ", "class ", "def ", "var ", "return ", "</", "/>", "SELECT ", "curl "]
        let matchCount = codeSymbols.filter { text.contains($0) }.count
        return matchCount >= 2
    }
}
