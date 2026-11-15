import SwiftUI

/// 의존성 없는 간단한 마크다운 렌더러. 블록(제목·목록·인용·코드·이미지)은 직접 나누고 인라인은 AttributedString에 맡깁니다.
struct MarkdownPreview: View {
    let note: WikiNote

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if let title = note.title.nonEmpty {
                    Text(title).font(.largeTitle.bold()).padding(.bottom, 4)
                }
                ForEach(Array(MarkdownBlock.parse(note.body).enumerated()), id: \.offset) { _, block in
                    view(for: block)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private func view(for block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            Text(inline(text))
                .font(level == 1 ? .title.bold() : level == 2 ? .title2.bold() : .headline)
                .padding(.top, 6)
        case .paragraph(let text):
            Text(inline(text))
        case .bullet(let text, let checked):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                switch checked {
                case .some(true): Image(systemName: "checkmark.square")
                case .some(false): Image(systemName: "square")
                case .none: Text("•")
                }
                Text(inline(text))
            }
        case .numbered(let number, let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(number).").monospacedDigit()
                Text(inline(text))
            }
        case .quote(let text):
            HStack(spacing: 10) {
                Rectangle().fill(Color.primary.opacity(0.3)).frame(width: 3)
                Text(inline(text)).foregroundStyle(.secondary)
            }
        case .code(let text):
            Text(text)
                .font(.callout.monospaced())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.primary.opacity(0.06), in: .rect(cornerRadius: 8))
        case .image(let path):
            if let image = Image(data: note.image(for: path)?.data) {
                image.resizable().scaledToFit().clipShape(.rect(cornerRadius: 10))
            } else {
                Label(path, systemImage: "photo").foregroundStyle(.secondary)
            }
        case .rule:
            Divider()
        }
    }

    private func inline(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
    }
}

enum MarkdownBlock: Equatable {
    case heading(Int, String)
    case paragraph(String)
    case bullet(String, checked: Bool?)
    case numbered(Int, String)
    case quote(String)
    case code(String)
    case image(String)
    case rule

    static func parse(_ source: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var paragraph: [String] = []
        var code: [String]?

        func flush() {
            if !paragraph.isEmpty { blocks.append(.paragraph(paragraph.joined(separator: "\n"))) }
            paragraph = []
        }

        for raw in source.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("```") {
                if let lines = code { blocks.append(.code(lines.joined(separator: "\n"))); code = nil }
                else { flush(); code = [] }
                continue
            }
            if code != nil { code?.append(raw); continue }

            if line.isEmpty { flush(); continue }
            if let path = imagePath(line) { flush(); blocks.append(.image(path)); continue }
            if line == "---" || line == "***" { flush(); blocks.append(.rule); continue }
            if let level = headingLevel(line) {
                flush(); blocks.append(.heading(level, String(line.dropFirst(level + 1)))); continue
            }
            if line.hasPrefix("> ") { flush(); blocks.append(.quote(String(line.dropFirst(2)))); continue }
            if line.hasPrefix("- [ ] ") { flush(); blocks.append(.bullet(String(line.dropFirst(6)), checked: false)); continue }
            if line.lowercased().hasPrefix("- [x] ") { flush(); blocks.append(.bullet(String(line.dropFirst(6)), checked: true)); continue }
            if line.hasPrefix("- ") || line.hasPrefix("* ") { flush(); blocks.append(.bullet(String(line.dropFirst(2)), checked: nil)); continue }
            if let dot = line.firstIndex(of: "."), let number = Int(line[..<dot]), line[line.index(after: dot)...].hasPrefix(" ") {
                flush(); blocks.append(.numbered(number, String(line[line.index(dot, offsetBy: 2)...]))); continue
            }
            paragraph.append(raw)
        }
        if let lines = code { blocks.append(.code(lines.joined(separator: "\n"))) }
        flush()
        return blocks
    }

    private static func headingLevel(_ line: String) -> Int? {
        let hashes = line.prefix { $0 == "#" }.count
        guard (1...6).contains(hashes), line.dropFirst(hashes).hasPrefix(" ") else { return nil }
        return hashes
    }

    /// `![설명](경로)` 한 줄짜리 이미지
    static func imagePath(_ line: String) -> String? {
        guard line.hasPrefix("!["), line.hasSuffix(")"),
              let open = line.range(of: "](") else { return nil }
        return String(line[open.upperBound..<line.index(before: line.endIndex)])
    }
}
