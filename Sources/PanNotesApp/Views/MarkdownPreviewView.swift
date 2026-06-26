import PanNotesCore
import SwiftUI

struct MarkdownPreviewView: View {
    let nodes: [MarkdownRenderNode]
    let fontSize: Double
    let onToggleTask: (Int) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 11) {
                ForEach(Array(nodes.enumerated()), id: \.offset) { nodeOffset, node in
                    switch node {
                    case let .heading(level, text):
                        Text(text)
                            .font(headingFont(level: level))
                            .padding(.top, level == 1 ? 3 : 1)
                    case let .paragraph(text):
                        Text(text)
                            .font(.system(size: fontSize))
                            .lineSpacing(2)
                    case let .richParagraph(runs):
                        richText(from: runs)
                            .lineSpacing(2)
                    case let .bulletList(items):
                        ForEach(items, id: \.self) { item in
                            HStack(alignment: .firstTextBaseline) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 5, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                                Text(item)
                                    .font(.system(size: fontSize))
                            }
                        }
                    case let .taskList(items):
                        ForEach(Array(items.enumerated()), id: \.offset) { itemOffset, item in
                            HStack {
                                Button {
                                    onToggleTask(taskOffset(before: nodeOffset) + itemOffset)
                                } label: {
                                    Image(systemName: item.isComplete ? "checkmark.square" : "square")
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)
                                Text(item.text)
                                    .font(.system(size: fontSize))
                            }
                        }
                    case let .codeBlock(_, code):
                        Text(code)
                            .font(.system(size: codeFontSize, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 6))
                    case let .blockQuote(text):
                        HStack(alignment: .top, spacing: 10) {
                            Rectangle()
                                .fill(Color.primary.opacity(0.18))
                                .frame(width: 2)
                            Text(text)
                                .italic()
                                .font(.system(size: fontSize))
                                .foregroundStyle(.secondary)
                        }
                    case let .table(raw):
                        Text(raw)
                            .font(.system(size: codeFontSize, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollContentBackground(.hidden)
    }

    private var codeFontSize: Double {
        max(11, fontSize - 1)
    }

    private func taskOffset(before nodeOffset: Int) -> Int {
        nodes.prefix(nodeOffset).reduce(0) { total, node in
            if case let .taskList(items) = node {
                return total + items.count
            }
            return total
        }
    }

    private func headingFont(level: Int) -> Font {
        let increment: Double
        switch level {
        case 1:
            increment = 11
        case 2:
            increment = 8
        case 3:
            increment = 5
        case 4:
            increment = 3
        default:
            increment = 2
        }
        return .system(size: fontSize + increment, weight: .semibold)
    }

    private func richText(from runs: [MarkdownInlineRun]) -> Text {
        runs.reduce(Text("")) { text, run in
            text + textRun(run)
        }
    }

    private func textRun(_ run: MarkdownInlineRun) -> Text {
        var text = Text(run.text)
            .font(
                run.isCode
                    ? .system(size: codeFontSize, design: .monospaced)
                    : .system(size: fontSize, weight: run.isStrong ? .semibold : .regular)
            )
        if run.isEmphasized {
            text = text.italic()
        }
        if run.isStrikethrough {
            text = text.strikethrough()
        }
        return text
    }
}
