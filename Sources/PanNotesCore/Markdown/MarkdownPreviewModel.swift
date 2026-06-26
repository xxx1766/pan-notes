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

public struct MarkdownInlineRun: Equatable, Sendable {
    public var text: String
    public var isEmphasized: Bool
    public var isStrong: Bool
    public var isStrikethrough: Bool
    public var isCode: Bool

    public init(
        text: String,
        isEmphasized: Bool = false,
        isStrong: Bool = false,
        isStrikethrough: Bool = false,
        isCode: Bool = false
    ) {
        self.text = text
        self.isEmphasized = isEmphasized
        self.isStrong = isStrong
        self.isStrikethrough = isStrikethrough
        self.isCode = isCode
    }
}

public enum MarkdownRenderNode: Equatable, Sendable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case richParagraph([MarkdownInlineRun])
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

        let document = Document(parsing: source)
        let nodes = document.children.flatMap { renderBlock($0, rules: rules) }
        if !nodes.isEmpty {
            return nodes
        }

        let text = source.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? [] : [.paragraph(text)]
    }

    private static func isTable(_ source: String) -> Bool {
        let lines = source.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        guard lines.count >= 2 else {
            return false
        }
        return lines[0].contains("|") && lines[1].contains("-") && lines[1].contains("|")
    }

    private static func renderBlock(_ block: Markup, rules: MarkdownRules) -> [MarkdownRenderNode] {
        if let heading = block as? Heading {
            let text = plainText(from: heading).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                return []
            }
            return rules.headings ? [.heading(level: heading.level, text: text)] : [.paragraph(text)]
        }

        if let paragraph = block as? Paragraph {
            return paragraphNode(from: inlineRuns(from: paragraph, rules: rules))
        }

        if let unorderedList = block as? UnorderedList {
            let items = unorderedList.children.compactMap { $0 as? ListItem }
            if let taskItems = taskListItems(from: items), rules.taskLists {
                return [.taskList(taskItems)]
            }

            let bulletItems = items
                .map { plainText(from: $0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            guard !bulletItems.isEmpty else {
                return []
            }
            return rules.lists ? [.bulletList(bulletItems)] : [.paragraph(bulletItems.joined(separator: "\n"))]
        }

        if let codeBlock = block as? CodeBlock {
            let code = codeBlock.code.trimmingCharacters(in: .newlines)
            guard !code.isEmpty else {
                return []
            }
            return rules.codeBlocks ? [.codeBlock(language: codeBlock.language, code: code)] : [.paragraph(code)]
        }

        if let blockQuote = block as? BlockQuote {
            let text = plainText(from: blockQuote).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                return []
            }
            return rules.blockQuotes ? [.blockQuote(text)] : [.paragraph(text)]
        }

        let text = plainText(from: block).trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? [] : [.paragraph(text)]
    }

    private static func paragraphNode(from runs: [MarkdownInlineRun]) -> [MarkdownRenderNode] {
        let normalizedRuns = mergeAdjacent(runs).filter { !$0.text.isEmpty }
        let text = normalizedRuns.map(\.text).joined().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return []
        }
        if normalizedRuns.contains(where: { $0.hasStyle }) {
            return [.richParagraph(normalizedRuns)]
        }
        return [.paragraph(text)]
    }

    private static func taskListItems(from listItems: [ListItem]) -> [TaskListItem]? {
        guard !listItems.isEmpty else {
            return nil
        }

        var items: [TaskListItem] = []
        for item in listItems {
            guard let checkbox = item.checkbox else {
                return nil
            }
            let text = plainText(from: item).trimmingCharacters(in: .whitespacesAndNewlines)
            items.append(TaskListItem(text: text, isComplete: checkbox == .checked))
        }
        return items
    }

    private static func plainText(from markup: Markup) -> String {
        var collector = PlainTextCollector()
        collector.visit(markup)
        return collector.text
    }

    private static func inlineRuns(
        from markup: Markup,
        rules: MarkdownRules,
        style: MarkdownInlineStyle = .plain
    ) -> [MarkdownInlineRun] {
        if let text = markup as? Text {
            return [style.run(text.string)]
        }

        if markup is SoftBreak || markup is LineBreak {
            return [style.run("\n")]
        }

        if let inlineCode = markup as? InlineCode {
            return [style.withCode(rules.inlineCode).run(inlineCode.code)]
        }

        if let emphasis = markup as? Emphasis {
            return emphasis.children.flatMap {
                inlineRuns(from: $0, rules: rules, style: style.withEmphasis(rules.emphasis))
            }
        }

        if let strong = markup as? Strong {
            return strong.children.flatMap {
                inlineRuns(from: $0, rules: rules, style: style.withStrong(rules.emphasis))
            }
        }

        if let strikethrough = markup as? Strikethrough {
            return strikethrough.children.flatMap {
                inlineRuns(from: $0, rules: rules, style: style.withStrikethrough(rules.strikethrough))
            }
        }

        return markup.children.flatMap {
            inlineRuns(from: $0, rules: rules, style: style)
        }
    }

    private static func mergeAdjacent(_ runs: [MarkdownInlineRun]) -> [MarkdownInlineRun] {
        runs.reduce(into: []) { merged, run in
            guard let last = merged.last, last.hasSameStyle(as: run) else {
                merged.append(run)
                return
            }
            merged[merged.count - 1].text += run.text
        }
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

private struct MarkdownInlineStyle {
    var isEmphasized = false
    var isStrong = false
    var isStrikethrough = false
    var isCode = false

    static let plain = MarkdownInlineStyle()

    func withEmphasis(_ enabled: Bool) -> MarkdownInlineStyle {
        var style = self
        style.isEmphasized = style.isEmphasized || enabled
        return style
    }

    func withStrong(_ enabled: Bool) -> MarkdownInlineStyle {
        var style = self
        style.isStrong = style.isStrong || enabled
        return style
    }

    func withStrikethrough(_ enabled: Bool) -> MarkdownInlineStyle {
        var style = self
        style.isStrikethrough = style.isStrikethrough || enabled
        return style
    }

    func withCode(_ enabled: Bool) -> MarkdownInlineStyle {
        var style = self
        style.isCode = style.isCode || enabled
        return style
    }

    func run(_ text: String) -> MarkdownInlineRun {
        MarkdownInlineRun(
            text: text,
            isEmphasized: isEmphasized,
            isStrong: isStrong,
            isStrikethrough: isStrikethrough,
            isCode: isCode
        )
    }
}

private extension MarkdownInlineRun {
    var hasStyle: Bool {
        isEmphasized || isStrong || isStrikethrough || isCode
    }

    func hasSameStyle(as other: MarkdownInlineRun) -> Bool {
        isEmphasized == other.isEmphasized
            && isStrong == other.isStrong
            && isStrikethrough == other.isStrikethrough
            && isCode == other.isCode
    }
}
