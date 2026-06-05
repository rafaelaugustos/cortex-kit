import SwiftUI
import CortexUI

/// A lightweight Markdown renderer tuned for short AI replies: headings,
/// paragraphs, ordered/unordered lists, fenced code blocks, and inline
/// `*bold*` / `_italic_` / `` `code` ``. Deliberately not a full Markdown
/// engine — AI answers are short and well-shaped, and this keeps zero deps.
public struct MarkdownText: View {
    public let text: String

    public init(_ text: String) { self.text = text }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Self.parse(text)) { block in
                render(block)
            }
        }
        .textSelection(.enabled)
    }

    public enum Kind: Equatable, Sendable {
        case heading(level: Int, text: String)
        case paragraph(String)
        case list(items: [String], ordered: Bool)
        case code(String)
    }

    public struct Block: Identifiable, Equatable, Sendable {
        public let id: Int
        public let kind: Kind
    }

    @ViewBuilder
    private func render(_ block: Block) -> some View {
        switch block.kind {
        case .heading(let level, let txt):
            Text(inline(txt))
                .font(.system(size: headingSize(level), weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .padding(.top, 4)
        case .paragraph(let txt):
            Text(inline(txt))
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)
        case .list(let items, let ordered):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text(ordered ? "\(idx + 1)." : "•")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Brand.accent)
                            .frame(width: 16, alignment: .trailing)
                        Text(inline(item))
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.88))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        case .code(let txt):
            Text(txt)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.white.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.05)))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.08), lineWidth: 1))
        }
    }

    private func headingSize(_ level: Int) -> CGFloat {
        switch level { case 1: return 19; case 2: return 16; case 3: return 14; default: return 13 }
    }

    /// Parses inline emphasis/code/links via Foundation's Markdown
    /// `AttributedString`, falling back to plain text.
    private func inline(_ s: String) -> AttributedString {
        if let a = try? AttributedString(markdown: s,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            return a
        }
        return AttributedString(s)
    }

    // MARK: - Block parser

    public static func parse(_ text: String) -> [Block] {
        var blocks: [Block] = []
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var i = 0
        var nextId = 0
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Fenced code block ```
            if trimmed.hasPrefix("```") {
                var buf: [String] = []
                i += 1
                while i < lines.count, !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    buf.append(lines[i]); i += 1
                }
                if i < lines.count { i += 1 }  // closing fence
                blocks.append(Block(id: nextId, kind: .code(buf.joined(separator: "\n"))))
                nextId += 1
                continue
            }

            // Heading
            if let (level, body) = heading(line) {
                blocks.append(Block(id: nextId, kind: .heading(level: level, text: body)))
                nextId += 1
                i += 1
                continue
            }

            // List (group consecutive items of the same kind)
            if let kind = listKind(trimmed) {
                var items: [String] = []
                while i < lines.count {
                    let t = lines[i].trimmingCharacters(in: .whitespaces)
                    guard let k = listKind(t), k == kind else { break }
                    items.append(stripMarker(t, kind: kind))
                    i += 1
                }
                blocks.append(Block(id: nextId, kind: .list(items: items, ordered: kind == .ordered)))
                nextId += 1
                continue
            }

            // Blank line → skip
            if trimmed.isEmpty { i += 1; continue }

            // Paragraph (gather consecutive plain lines)
            var buf: [String] = []
            while i < lines.count {
                let t = lines[i].trimmingCharacters(in: .whitespaces)
                if t.isEmpty || t.hasPrefix("```") || heading(lines[i]) != nil || listKind(t) != nil { break }
                buf.append(lines[i])
                i += 1
            }
            if !buf.isEmpty {
                blocks.append(Block(id: nextId, kind: .paragraph(buf.joined(separator: " "))))
                nextId += 1
            }
        }
        return blocks
    }

    private enum ListMarker { case unordered, ordered }

    private static func heading(_ line: String) -> (Int, String)? {
        let t = line.trimmingCharacters(in: .whitespaces)
        for level in [3, 2, 1] {
            let prefix = String(repeating: "#", count: level) + " "
            if t.hasPrefix(prefix) { return (level, String(t.dropFirst(prefix.count))) }
        }
        return nil
    }

    private static func listKind(_ t: String) -> ListMarker? {
        if t.hasPrefix("- ") || t.hasPrefix("* ") { return .unordered }
        if let r = t.range(of: "^\\d+\\.\\s", options: .regularExpression), r.lowerBound == t.startIndex {
            return .ordered
        }
        return nil
    }

    private static func stripMarker(_ t: String, kind: ListMarker) -> String {
        switch kind {
        case .unordered: return String(t.dropFirst(2))
        case .ordered:
            if let r = t.range(of: "^\\d+\\.\\s", options: .regularExpression) {
                return String(t[r.upperBound...])
            }
            return t
        }
    }
}
