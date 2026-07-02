import Foundation

public enum NotionMarkdownConverter {
    public static func startMarker(dotID: String) -> String {
        "<!-- pan-notes:start dot=\(dotID) -->"
    }

    public static func endMarker(dotID: String) -> String {
        "<!-- pan-notes:end dot=\(dotID) -->"
    }

    public static func blocks(from markdown: String, dotID: String) -> [NotionBlock] {
        [.paragraph(startMarker(dotID: dotID))]
            + contentBlocks(from: markdown)
            + [.paragraph(endMarker(dotID: dotID))]
    }

    public static func managedBlocks(in blocks: [NotionBlock], dotID: String) -> [NotionBlock] {
        guard
            let startIndex = blocks.firstIndex(where: { isMarker($0, text: startMarker(dotID: dotID)) }),
            let endIndex = blocks[(startIndex + 1)...].firstIndex(where: { isMarker($0, text: endMarker(dotID: dotID)) }),
            startIndex < endIndex
        else {
            return blocks
        }

        return Array(blocks[(startIndex + 1)..<endIndex])
    }

    public static func markdown(from blocks: [NotionBlock]) -> String {
        blocks.compactMap(markdownBlock(from:))
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    private static func contentBlocks(from markdown: String) -> [NotionBlock] {
        let lines = markdown.components(separatedBy: .newlines)
        var blocks: [NotionBlock] = []
        var paragraphLines: [String] = []
        var index = 0

        func flushParagraph() {
            let text = paragraphLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                blocks.append(.paragraph(text))
            }
            paragraphLines.removeAll()
        }

        while index < lines.count {
            let rawLine = lines[index]
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                flushParagraph()
                index += 1
                continue
            }

            if trimmed.hasPrefix("```") {
                flushParagraph()
                let language = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                index += 1
                var codeLines: [String] = []
                while index < lines.count {
                    let codeLine = lines[index]
                    if codeLine.trimmingCharacters(in: .whitespaces) == "```" {
                        break
                    }
                    codeLines.append(codeLine)
                    index += 1
                }
                blocks.append(.code(language: language.isEmpty ? nil : language, codeLines.joined(separator: "\n")))
                if index < lines.count {
                    index += 1
                }
                continue
            }

            if let heading = headingBlock(from: trimmed) {
                flushParagraph()
                blocks.append(heading)
                index += 1
                continue
            }

            if let task = taskBlock(from: trimmed) {
                flushParagraph()
                blocks.append(task)
                index += 1
                continue
            }

            if let bullet = bulletBlock(from: trimmed) {
                flushParagraph()
                blocks.append(bullet)
                index += 1
                continue
            }

            if let numbered = numberedBlock(from: trimmed) {
                flushParagraph()
                blocks.append(numbered)
                index += 1
                continue
            }

            if trimmed.hasPrefix("> ") {
                flushParagraph()
                blocks.append(.quote(String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)))
                index += 1
                continue
            }

            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                flushParagraph()
                blocks.append(.divider)
                index += 1
                continue
            }

            paragraphLines.append(rawLine)
            index += 1
        }

        flushParagraph()
        return blocks
    }

    private static func headingBlock(from line: String) -> NotionBlock? {
        let markers = line.prefix { $0 == "#" }
        guard (1...3).contains(markers.count) else {
            return nil
        }
        let remainder = line.dropFirst(markers.count)
        guard remainder.first == " " else {
            return nil
        }
        let text = String(remainder.dropFirst()).trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : .heading(level: markers.count, text)
    }

    private static func taskBlock(from line: String) -> NotionBlock? {
        if line.hasPrefix("- [x] ") || line.hasPrefix("- [X] ") {
            return .toDo(text: String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces), isComplete: true)
        }
        if line.hasPrefix("- [ ] ") {
            return .toDo(text: String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces), isComplete: false)
        }
        return nil
    }

    private static func bulletBlock(from line: String) -> NotionBlock? {
        guard line.hasPrefix("- ") || line.hasPrefix("* ") else {
            return nil
        }
        let text = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : .bulletedListItem(text)
    }

    private static func numberedBlock(from line: String) -> NotionBlock? {
        guard let dotIndex = line.firstIndex(of: ".") else {
            return nil
        }
        let prefix = line[..<dotIndex]
        guard !prefix.isEmpty, prefix.allSatisfy(\.isNumber) else {
            return nil
        }
        let afterDot = line[line.index(after: dotIndex)...]
        guard afterDot.first == " " else {
            return nil
        }
        let text = String(afterDot.dropFirst()).trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : .numberedListItem(text)
    }

    private static func markdownBlock(from block: NotionBlock) -> String? {
        switch block.kind {
        case .paragraph(let text):
            return text.hasPrefix("<!-- pan-notes:") ? nil : text
        case .heading(let level, let text):
            return "\(String(repeating: "#", count: min(max(level, 1), 3))) \(text)"
        case .bulletedListItem(let text):
            return "- \(text)"
        case .numberedListItem(let text):
            return "1. \(text)"
        case .toDo(let text, let isComplete):
            return "- [\(isComplete ? "x" : " ")] \(text)"
        case .quote(let text):
            return "> \(text)"
        case .divider:
            return "---"
        case .code(let language, let text):
            let info = language ?? ""
            return "```\(info)\n\(text)\n```"
        case .unsupported(let text):
            return text
        }
    }

    private static func isMarker(_ block: NotionBlock, text: String) -> Bool {
        guard case .paragraph(let blockText) = block.kind else {
            return false
        }
        return blockText == text
    }
}
