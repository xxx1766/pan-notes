import Foundation

public struct TextEditResult: Equatable {
    public var text: String
    public var selectedRange: NSRange

    public init(text: String, selectedRange: NSRange) {
        self.text = text
        self.selectedRange = selectedRange
    }
}

public enum TextCommandProcessor {
    public static func insertText(_ insertedText: String, in text: String, selectedRange: NSRange) -> TextEditResult {
        replace(selectedRange, in: text, with: insertedText, cursorOffset: insertedText.utf16.count)
    }

    public static func insertSmartBullet(in text: String, selectedRange: NSRange) -> TextEditResult {
        insertText("- [ ] ", in: text, selectedRange: selectedRange)
    }

    public static func insertBullet(in text: String, selectedRange: NSRange) -> TextEditResult {
        insertText("- ", in: text, selectedRange: selectedRange)
    }

    public static func insertDivider(in text: String, selectedRange: NSRange) -> TextEditResult {
        insertText("---", in: text, selectedRange: selectedRange)
    }

    public static func toggleSmartBullet(in text: String, selectedRange: NSRange) -> TextEditResult {
        let line = currentLine(in: text, selectedRange: selectedRange)
        let parsed = parseIndentedLine(line.content)
        let replacement: String

        if let checklist = checklistMarker(in: parsed.body) {
            let toggled = checklist.isComplete ? "- [ ]" : "- [x]"
            replacement = parsed.indent + toggled + parsed.body.dropFirst(checklist.markerLength)
        } else if parsed.body.hasPrefix("- ") || parsed.body.hasPrefix("* ") {
            replacement = parsed.indent + "- [ ] " + parsed.body.dropFirst(2)
        } else {
            replacement = parsed.indent + "- [ ] " + parsed.body
        }

        let result = replace(line.contentRange, in: text, with: replacement, cursorOffset: min(selectionOffset(selectedRange, in: line), replacement.utf16.count))
        return result
    }

    public static func insertNewline(in text: String, selectedRange: NSRange) -> TextEditResult {
        let line = currentLine(in: text, selectedRange: selectedRange)
        let parsed = parseIndentedLine(line.content)

        if let checklist = checklistMarker(in: parsed.body) {
            let body = parsed.body.dropFirst(checklist.markerLength).trimmingCharacters(in: .whitespaces)
            if body.isEmpty {
                return replace(line.contentRange, in: text, with: parsed.indent, cursorOffset: parsed.indent.utf16.count)
            }
            return insertText("\n\(parsed.indent)- [ ] ", in: text, selectedRange: selectedRange)
        }

        if parsed.body.hasPrefix("- ") || parsed.body.hasPrefix("* ") {
            let marker = String(parsed.body.prefix(2))
            let body = parsed.body.dropFirst(2).trimmingCharacters(in: .whitespaces)
            if body.isEmpty {
                return replace(line.contentRange, in: text, with: parsed.indent, cursorOffset: parsed.indent.utf16.count)
            }
            return insertText("\n\(parsed.indent)\(marker)", in: text, selectedRange: selectedRange)
        }

        if let ordered = orderedListMarker(in: parsed.body) {
            let body = parsed.body.dropFirst(ordered.markerLength).trimmingCharacters(in: .whitespaces)
            if body.isEmpty {
                return replace(line.contentRange, in: text, with: parsed.indent, cursorOffset: parsed.indent.utf16.count)
            }
            return insertText("\n\(parsed.indent)\(ordered.nextNumber). ", in: text, selectedRange: selectedRange)
        }

        return insertText("\n", in: text, selectedRange: selectedRange)
    }

    public static func indentSelection(in text: String, selectedRange: NSRange) -> TextEditResult {
        transformSelectedLines(in: text, selectedRange: selectedRange) { content in
            content.isEmpty ? content : "    " + content
        }
    }

    public static func outdentSelection(in text: String, selectedRange: NSRange) -> TextEditResult {
        transformSelectedLines(in: text, selectedRange: selectedRange) { content in
            if content.hasPrefix("    ") {
                return String(content.dropFirst(4))
            }
            if content.hasPrefix("\t") {
                return String(content.dropFirst())
            }
            let removable = content.prefix(4).prefix { $0 == " " }.count
            return String(content.dropFirst(removable))
        }
    }

    public static func toggleTaskItem(at taskIndex: Int, in text: String) -> TextEditResult? {
        guard taskIndex >= 0 else {
            return nil
        }

        let nsText = text as NSString
        var lineStart = 0
        var foundIndex = 0

        while lineStart < nsText.length {
            let lineRange = nsText.lineRange(for: NSRange(location: lineStart, length: 0))
            let line = nsText.substring(with: lineRange)
            let newline = trailingNewline(in: line)
            let content = String(line.dropLast(newline.utf16.count))
            let parsed = parseIndentedLine(content)

            if let marker = checklistMarker(in: parsed.body) {
                if foundIndex == taskIndex {
                    let markerLocation = lineRange.location + parsed.indent.utf16.count
                    let replacement = marker.isComplete ? "- [ ]" : "- [x]"
                    return replace(
                        NSRange(location: markerLocation, length: marker.markerLength),
                        in: text,
                        with: replacement,
                        cursorOffset: replacement.utf16.count
                    )
                }
                foundIndex += 1
            }

            lineStart = lineRange.location + max(lineRange.length, 1)
        }

        return nil
    }
}

private struct LineInfo {
    var content: String
    var contentRange: NSRange
}

private struct ParsedLine {
    var indent: String
    var body: String
}

private struct ChecklistMarker {
    var isComplete: Bool
    var markerLength: Int
}

private struct OrderedListMarker {
    var nextNumber: Int
    var markerLength: Int
}

private extension TextCommandProcessor {
    static func currentLine(in text: String, selectedRange: NSRange) -> LineInfo {
        let nsText = text as NSString
        let location = min(max(0, selectedRange.location), nsText.length)
        let lineRange = nsText.lineRange(for: NSRange(location: location, length: 0))
        let rawLine = nsText.substring(with: lineRange)
        let newline = trailingNewline(in: rawLine)
        let contentLength = lineRange.length - newline.utf16.count
        let contentRange = NSRange(location: lineRange.location, length: max(0, contentLength))
        return LineInfo(content: nsText.substring(with: contentRange), contentRange: contentRange)
    }

    static func replace(_ range: NSRange, in text: String, with replacement: String, cursorOffset: Int) -> TextEditResult {
        let nsText = NSMutableString(string: text)
        let safeRange = clamped(range, length: nsText.length)
        nsText.replaceCharacters(in: safeRange, with: replacement)
        let cursor = safeRange.location + cursorOffset
        return TextEditResult(text: nsText as String, selectedRange: NSRange(location: cursor, length: 0))
    }

    static func clamped(_ range: NSRange, length: Int) -> NSRange {
        let location = min(max(0, range.location), length)
        let maxLength = max(0, length - location)
        return NSRange(location: location, length: min(max(0, range.length), maxLength))
    }

    static func selectionOffset(_ selectedRange: NSRange, in line: LineInfo) -> Int {
        max(0, selectedRange.location - line.contentRange.location)
    }

    static func parseIndentedLine(_ line: String) -> ParsedLine {
        let indent = line.prefix { $0 == " " || $0 == "\t" }
        return ParsedLine(indent: String(indent), body: String(line.dropFirst(indent.count)))
    }

    static func checklistMarker(in body: String) -> ChecklistMarker? {
        if body.hasPrefix("- [ ]") {
            return ChecklistMarker(isComplete: false, markerLength: 5)
        }
        if body.hasPrefix("- [x]") || body.hasPrefix("- [X]") {
            return ChecklistMarker(isComplete: true, markerLength: 5)
        }
        if body.hasPrefix("* [ ]") {
            return ChecklistMarker(isComplete: false, markerLength: 5)
        }
        if body.hasPrefix("* [x]") || body.hasPrefix("* [X]") {
            return ChecklistMarker(isComplete: true, markerLength: 5)
        }
        return nil
    }

    static func orderedListMarker(in body: String) -> OrderedListMarker? {
        let digits = body.prefix { $0.isNumber }
        guard !digits.isEmpty,
              body.dropFirst(digits.count).hasPrefix(". "),
              let number = Int(digits)
        else {
            return nil
        }
        return OrderedListMarker(nextNumber: number + 1, markerLength: digits.count + 2)
    }

    static func transformSelectedLines(
        in text: String,
        selectedRange: NSRange,
        transform: (String) -> String
    ) -> TextEditResult {
        let nsText = text as NSString
        let safeSelection = clamped(selectedRange, length: nsText.length)
        let selectedLineRange = nsText.lineRange(for: safeSelection)
        let segment = nsText.substring(with: selectedLineRange)
        let segmentText = segment as NSString
        var offset = 0
        var transformed = ""
        var addedBeforeCursor = 0

        while offset < segmentText.length {
            let range = segmentText.lineRange(for: NSRange(location: offset, length: 0))
            let rawLine = segmentText.substring(with: range)
            let newline = trailingNewline(in: rawLine)
            let content = String(rawLine.dropLast(newline.utf16.count))
            let newContent = transform(content)
            if selectedLineRange.location + offset < safeSelection.location {
                addedBeforeCursor += newContent.utf16.count - content.utf16.count
            }
            transformed += newContent + newline
            offset = range.location + range.length
        }

        let result = replace(selectedLineRange, in: text, with: transformed, cursorOffset: max(0, safeSelection.location - selectedLineRange.location + addedBeforeCursor))
        return TextEditResult(text: result.text, selectedRange: NSRange(location: result.selectedRange.location, length: safeSelection.length))
    }

    static func trailingNewline(in line: String) -> String {
        if line.hasSuffix("\r\n") {
            return "\r\n"
        }
        if line.hasSuffix("\n") {
            return "\n"
        }
        if line.hasSuffix("\r") {
            return "\r"
        }
        return ""
    }
}
