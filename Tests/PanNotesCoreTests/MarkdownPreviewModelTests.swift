import PanNotesCore

let markdownPreviewModelTests: [TestCase] = [
    TestCase("disabledHeadingsRenderAsPlainText", disabledHeadingsRenderAsPlainText),
    TestCase("enabledHeadingsRenderAsHeadingNode", enabledHeadingsRenderAsHeadingNode),
    TestCase("disabledTablesRenderAsPlainTextLines", disabledTablesRenderAsPlainTextLines),
    TestCase("enabledTaskListsRenderTaskNodes", enabledTaskListsRenderTaskNodes)
]

private func disabledHeadingsRenderAsPlainText() throws {
    var rules = MarkdownRules.defaultEnabled
    rules.headings = false

    let nodes = MarkdownPreviewModel.nodes(from: "# Title", rules: rules)

    try expect(nodes == [.paragraph("Title")], "disabled headings render paragraph")
}

private func enabledHeadingsRenderAsHeadingNode() throws {
    let nodes = MarkdownPreviewModel.nodes(from: "# Title", rules: .defaultEnabled)

    try expect(nodes == [.heading(level: 1, text: "Title")], "enabled headings render heading")
}

private func disabledTablesRenderAsPlainTextLines() throws {
    var rules = MarkdownRules.defaultEnabled
    rules.tables = false

    let source = """
    | A | B |
    | - | - |
    | 1 | 2 |
    """
    let nodes = MarkdownPreviewModel.nodes(from: source, rules: rules)

    try expect(nodes == [.paragraph("| A | B |\n| - | - |\n| 1 | 2 |")], "disabled tables render paragraph")
}

private func enabledTaskListsRenderTaskNodes() throws {
    let nodes = MarkdownPreviewModel.nodes(from: "- [x] Done\n- [ ] Next", rules: .defaultEnabled)

    try expect(
        nodes == [.taskList([
            TaskListItem(text: "Done", isComplete: true),
            TaskListItem(text: "Next", isComplete: false)
        ])],
        "enabled task lists render task nodes"
    )
}
