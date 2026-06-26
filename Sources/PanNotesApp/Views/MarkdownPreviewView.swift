import PanNotesCore
import SwiftUI

struct MarkdownPreviewView: View {
    let nodes: [MarkdownRenderNode]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 11) {
                ForEach(Array(nodes.enumerated()), id: \.offset) { _, node in
                    switch node {
                    case let .heading(level, text):
                        Text(text)
                            .font(level == 1 ? .title2.weight(.semibold) : .headline.weight(.semibold))
                            .padding(.top, level == 1 ? 3 : 1)
                    case let .paragraph(text):
                        Text(text)
                            .font(.system(size: 16))
                            .lineSpacing(2)
                    case let .bulletList(items):
                        ForEach(items, id: \.self) { item in
                            HStack(alignment: .firstTextBaseline) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 5, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                                Text(item)
                                    .font(.system(size: 16))
                            }
                        }
                    case let .taskList(items):
                        ForEach(items, id: \.text) { item in
                            HStack {
                                Image(systemName: item.isComplete ? "checkmark.square" : "square")
                                    .foregroundStyle(.secondary)
                                Text(item.text)
                                    .font(.system(size: 16))
                            }
                        }
                    case let .codeBlock(_, code):
                        Text(code)
                            .font(.system(size: 14, design: .monospaced))
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
                                .font(.system(size: 16))
                                .foregroundStyle(.secondary)
                        }
                    case let .table(raw):
                        Text(raw)
                            .font(.system(size: 14, design: .monospaced))
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
}
