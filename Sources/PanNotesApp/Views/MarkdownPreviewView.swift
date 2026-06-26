import PanNotesCore
import SwiftUI

struct MarkdownPreviewView: View {
    let nodes: [MarkdownRenderNode]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(nodes.enumerated()), id: \.offset) { _, node in
                    switch node {
                    case let .heading(level, text):
                        Text(text).font(level == 1 ? .title2 : .headline)
                    case let .paragraph(text):
                        Text(text).font(.body)
                    case let .bulletList(items):
                        ForEach(items, id: \.self) { item in
                            HStack(alignment: .firstTextBaseline) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 5))
                                Text(item)
                            }
                        }
                    case let .taskList(items):
                        ForEach(items, id: \.text) { item in
                            HStack {
                                Image(systemName: item.isComplete ? "checkmark.square" : "square")
                                Text(item.text)
                            }
                        }
                    case let .codeBlock(_, code):
                        Text(code).font(.system(.body, design: .monospaced))
                    case let .blockQuote(text):
                        Text(text).italic()
                    case let .table(raw):
                        Text(raw).font(.system(.body, design: .monospaced))
                    }
                }
                Spacer(minLength: 0)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
