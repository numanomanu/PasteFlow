import SwiftUI
import AppKit

@MainActor
private final class RichPreviewCache {
    static let shared = RichPreviewCache()
    private let cache: NSCache<NSString, NSAttributedString> = {
        let c = NSCache<NSString, NSAttributedString>()
        c.countLimit = 40
        return c
    }()

    func get(_ id: UUID) -> AttributedString? {
        guard let nsAttr = cache.object(forKey: id.uuidString as NSString) else { return nil }
        return AttributedString(nsAttr)
    }

    func set(_ nsAttr: NSAttributedString, for id: UUID) {
        cache.setObject(nsAttr, forKey: id.uuidString as NSString)
    }
}

public struct ClipPreviewView: View {
    private enum PreviewMode: String, CaseIterable, Identifiable {
        case rich = "Rich"
        case plain = "Plain"
        case rawHTML = "HTML"

        var id: String { rawValue }
    }

    public let item: ClipItem?
    public let onPaste: () -> Void
    public let onPastePlain: () -> Void
    public let onCopy: () -> Void
    public let onTogglePin: () -> Void
    public let onDelete: () -> Void

    @State private var previewMode: PreviewMode = .plain
    @State private var cachedAttributed: AttributedString?
    @State private var cachedItemId: UUID?

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
            .onChange(of: item.id) { _, _ in
                syncPreviewForCurrentItem(item)
            }
            .onAppear {
                syncPreviewForCurrentItem(item)
            }
            .onChange(of: previewMode) { _, newMode in
                if newMode == .rich {
                    loadRichPreviewIfNeeded(for: item)
                }
            }
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

    private var availableModes: [PreviewMode] {
        guard let item = item else { return [.plain] }
        if item.hasHTML {
            return [.plain, .rich, .rawHTML]
        } else if item.hasRichText {
            return [.plain, .rich]
        } else {
            return [.plain]
        }
    }

    private func syncPreviewForCurrentItem(_ item: ClipItem) {
        if let hit = RichPreviewCache.shared.get(item.id) {
            cachedAttributed = hit
            cachedItemId = item.id
            previewMode = .rich
            return
        }

        cachedAttributed = nil
        cachedItemId = nil

        // Fast path: in-process RTF takes < 1ms, safe to render immediately
        if item.hasRichText, let rtf = item.richTextRTF, rtf.count <= 200_000,
           let nsAttr = Self.parseRTF(rtf) {
            RichPreviewCache.shared.set(nsAttr, for: item.id)
            cachedAttributed = AttributedString(nsAttr)
            cachedItemId = item.id
            previewMode = .rich
        } else {
            // HTML-only items default to Plain (0ms instant!) — WebKit HTML only runs when user clicks "Rich"
            previewMode = .plain
        }
    }

    private func loadRichPreviewIfNeeded(for item: ClipItem) {
        if cachedItemId == item.id && cachedAttributed != nil { return }
        if let hit = RichPreviewCache.shared.get(item.id) {
            cachedAttributed = hit
            cachedItemId = item.id
            return
        }
        if let rtf = item.richTextRTF, rtf.count <= 200_000,
           let nsAttr = Self.parseRTF(rtf) {
            RichPreviewCache.shared.set(nsAttr, for: item.id)
            cachedAttributed = AttributedString(nsAttr)
            cachedItemId = item.id
            return
        }
        if let nsAttr = Self.parseHTML(for: item) {
            RichPreviewCache.shared.set(nsAttr, for: item.id)
            cachedAttributed = AttributedString(nsAttr)
            cachedItemId = item.id
        }
    }

    @ViewBuilder
    private func modeSelector(for item: ClipItem) -> some View {
        let modes = availableModes
        if modes.count > 1 {
            HStack {
                Picker("", selection: $previewMode) {
                    ForEach(modes) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: modes.count == 3 ? 190 : 130)

                Spacer()
            }
            .padding(.bottom, 2)
        }
    }

    private static func parseRTF(_ rtf: Data) -> NSAttributedString? {
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.rtf
        ]
        guard let attr = try? NSAttributedString(data: rtf, options: options, documentAttributes: nil) else {
            return nil
        }
        return normalizeForDisplay(attr)
    }

    private static func parseHTML(for item: ClipItem) -> NSAttributedString? {
        let rawHTML: String?
        if let html = item.htmlContent, !html.isEmpty {
            rawHTML = html
        } else if item.hasHTML, let text = item.plainText, !text.isEmpty {
            rawHTML = text
        } else {
            rawHTML = nil
        }

        // Skip WebKit HTML parsing for huge blobs (> 32KB) to prevent UI stall
        guard let html = rawHTML, html.utf8.count <= 32_768 else {
            return nil
        }

        let styledHTML = """
        <style>
        body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; font-size: 13px; line-height: 1.45; }
        code, pre { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 12px; }
        </style>
        \(html)
        """
        guard let data = styledHTML.data(using: .utf8) else { return nil }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        guard let attr = try? NSAttributedString(data: data, options: options, documentAttributes: nil) else {
            return nil
        }
        return normalizeForDisplay(attr)
    }

    private static func normalizeForDisplay(_ baseAttr: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: baseAttr)
        let fullRange = NSRange(location: 0, length: mutable.length)
        mutable.enumerateAttribute(.foregroundColor, in: fullRange, options: []) { value, range, _ in
            if let color = value as? NSColor,
               let rgb = color.usingColorSpace(.sRGB),
               rgb.redComponent < 0.15 && rgb.greenComponent < 0.15 && rgb.blueComponent < 0.15 {
                mutable.removeAttribute(.foregroundColor, range: range)
            }
        }
        mutable.enumerateAttribute(.backgroundColor, in: fullRange, options: []) { value, range, _ in
            if let color = value as? NSColor,
               let rgb = color.usingColorSpace(.sRGB),
               rgb.redComponent > 0.9 && rgb.greenComponent > 0.9 && rgb.blueComponent > 0.9 {
                mutable.removeAttribute(.backgroundColor, range: range)
            }
        }
        return mutable
    }

    private func previewText(_ text: String?, maxChars: Int = 12_000) -> String {
        guard let text = text else { return "" }
        if text.count <= maxChars { return text }
        return String(text.prefix(maxChars)) + "\n\n… (Preview truncated at \(maxChars) chars — full \(text.count) chars will be pasted)"
    }

    @ViewBuilder
    private func richRenderedView(for item: ClipItem) -> some View {
        if cachedItemId == item.id, let attr = cachedAttributed {
            Text(attr)
                .foregroundColor(.primary)
                .textSelection(.enabled)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(previewText(item.plainText))
                .font(.system(size: 12, design: isCodeLike(item.plainText) ? .monospaced : .default))
                .foregroundColor(.primary)
                .textSelection(.enabled)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func textPreviewBody(item: ClipItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            modeSelector(for: item)

            switch previewMode {
            case .rich:
                richRenderedView(for: item)
            case .plain:
                Text(previewText(item.plainText))
                    .font(.system(size: 12, design: isCodeLike(item.plainText) ? .monospaced : .default))
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .rawHTML:
                Text(previewText(item.htmlContent ?? item.plainText))
                    .font(.system(size: 11, design: .monospaced))
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

            if availableModes.count > 1 {
                modeSelector(for: item)

                switch previewMode {
                case .rich:
                    richRenderedView(for: item)
                case .plain:
                    Text(item.plainText ?? "")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.blue)
                        .textSelection(.enabled)
                case .rawHTML:
                    Text(previewText(item.htmlContent ?? item.plainText))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Text(item.plainText ?? "")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.blue)
                    .textSelection(.enabled)
            }
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
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(value, forType: .string)
                ClipboardMonitor.shared.syncChangeCount()
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

                if item.type == .text || item.type == .link {
                    Button(action: onPastePlain) {
                        HStack(spacing: 4) {
                            Image(systemName: "text.alignleft")
                                .font(.system(size: 10))
                            Text("Plain")
                                .font(.system(size: 11, weight: item.hasRichText ? .semibold : .regular))
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
