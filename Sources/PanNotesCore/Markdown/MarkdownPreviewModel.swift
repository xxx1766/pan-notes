import Foundation
import Markdown

public struct TaskListItem: Equatable, Sendable {
    public var text: String
    public var isComplete: Bool

    public init(text: String, isComplete: Bool) {
        self.text = text
        self.isComplete = isComplete
    }
}

public enum MarkdownRenderNode: Equatable, Sendable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case bulletList([String])
    case taskList([TaskListItem])
    case codeBlock(language: String?, code: String)
    case blockQuote(String)
    case table(raw: String)
}

public enum MarkdownPreviewModel {
    public static func nodes(from source: String, rules: MarkdownRules) -> [MarkdownRenderNode] {
        if isTable(source) {
            let raw = source.trimmingCharacters(in: .whitespacesAndNewlines)
            return rules.tables ? [.table(raw: raw)] : [.paragraph(raw)]
        }

        if let taskItems = parseTaskList(source), rules.taskLists {
            return [.taskList(taskItems)]
        }

        if let heading = parseHeading(source) {
            return rules.headings
                ? [.heading(level: heading.level, text: heading.text)]
                : [.paragraph(heading.text)]
        }

        let text = plainText(from: source).trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? [] : [.paragraph(text)]
    }

    private static func parseHeading(_ source: String) -> (level: Int, text: String)? {
        let line = source.trimmingCharacters(in: .whitespacesAndNewlines)
        let hashes = line.prefix { $0 == "#" }.count
        guard (1...6).contains(hashes), line.dropFirst(hashes).first == " " else {
            return nil
        }
        return (hashes, String(line.dropFirst(hashes + 1)))
    }

    private static func parseTaskList(_ source: String) -> [TaskListItem]? {
        let lines = source.split(separator: "\n", omittingEmptySubsequences: true)
        guard !lines.isEmpty else {
            return nil
        }

        var items: [TaskListItem] = []
        for line in lines {
            let text = String(line)
            if text.hasPrefix("- [x] ") || text.hasPrefix("- [X] ") {
                items.append(TaskListItem(text: String(text.dropFirst(6)), isComplete: true))
            } else if text.hasPrefix("- [ ] ") {
                items.append(TaskListItem(text: String(text.dropFirst(6)), isComplete: false))
            } else {
                return nil
            }
        }
        return items
    }

    private static func isTable(_ source: String) -> Bool {
        let lines = source.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        guard lines.count >= 2 else {
            return false
        }
        return lines[0].contains("|") && lines[1].contains("-") && lines[1].contains("|")
    }

    private static func plainText(from source: String) -> String {
        let document = Document(parsing: source)
        var collector = PlainTextCollector()
        collector.visit(document)
        return collector.text
    }
}

private struct PlainTextCollector: MarkupWalker {
    var text = ""

    mutating func visitText(_ text: Text) {
        self.text += text.string
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) {
        text += "\n"
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) {
        text += "\n"
    }
}
