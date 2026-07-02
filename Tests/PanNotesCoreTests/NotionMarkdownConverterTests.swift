import PanNotesCore

let notionMarkdownConverterTests: [TestCase] = [
    TestCase("notionMarkdownConverterAddsMarkersAndSupportedBlocks", notionMarkdownConverterAddsMarkersAndSupportedBlocks),
    TestCase("notionMarkdownConverterRendersSupportedBlocksToMarkdown", notionMarkdownConverterRendersSupportedBlocksToMarkdown),
    TestCase("notionMarkdownConverterExtractsManagedMarkerRange", notionMarkdownConverterExtractsManagedMarkerRange),
    TestCase("notionMarkdownConverterReturnsManagedBlockIDsIncludingMarkers", notionMarkdownConverterReturnsManagedBlockIDsIncludingMarkers)
]

private func notionMarkdownConverterAddsMarkersAndSupportedBlocks() throws {
    let source = """
    # Title

    Paragraph text

    - Bullet
    1. Numbered
    - [x] Done
    - [ ] Next
    > Quote
    ---
    ```swift
    let value = 1
    ```
    """

    let blocks = NotionMarkdownConverter.blocks(from: source, dotID: "001")

    try expect(
        blocks == [
            .paragraph("<!-- pan-notes:start dot=001 -->"),
            .heading(level: 1, "Title"),
            .paragraph("Paragraph text"),
            .bulletedListItem("Bullet"),
            .numberedListItem("Numbered"),
            .toDo(text: "Done", isComplete: true),
            .toDo(text: "Next", isComplete: false),
            .quote("Quote"),
            .divider,
            .code(language: "swift", "let value = 1"),
            .paragraph("<!-- pan-notes:end dot=001 -->")
        ],
        "markdown converts to supported Notion blocks with markers"
    )
}

private func notionMarkdownConverterRendersSupportedBlocksToMarkdown() throws {
    let blocks: [NotionBlock] = [
        .paragraph("<!-- pan-notes:start dot=001 -->"),
        .heading(level: 2, "Title"),
        .paragraph("Paragraph text"),
        .bulletedListItem("Bullet"),
        .numberedListItem("Numbered"),
        .toDo(text: "Done", isComplete: true),
        .toDo(text: "Next", isComplete: false),
        .quote("Quote"),
        .divider,
        .code(language: "swift", "let value = 1"),
        .paragraph("<!-- pan-notes:end dot=001 -->")
    ]

    let markdown = NotionMarkdownConverter.markdown(from: blocks)

    let expected = """
    ## Title

    Paragraph text

    - Bullet

    1. Numbered

    - [x] Done

    - [ ] Next

    > Quote

    ---

    ```swift
    let value = 1
    ```
    """
    try expect(markdown == expected, "supported Notion blocks render to Markdown")
}

private func notionMarkdownConverterExtractsManagedMarkerRange() throws {
    let blocks: [NotionBlock] = [
        .paragraph("Outside before"),
        .paragraph("<!-- pan-notes:start dot=002 -->"),
        .paragraph("Managed"),
        .paragraph("<!-- pan-notes:end dot=002 -->"),
        .paragraph("Outside after")
    ]

    let managed = NotionMarkdownConverter.managedBlocks(in: blocks, dotID: "002")

    try expect(managed == [.paragraph("Managed")], "managed range excludes outside blocks and markers")
}

private func notionMarkdownConverterReturnsManagedBlockIDsIncludingMarkers() throws {
    let blocks: [NotionBlock] = [
        .paragraph("Outside before", id: "outside-before"),
        .paragraph("<!-- pan-notes:start dot=002 -->", id: "start"),
        .paragraph("Managed", id: "managed"),
        .paragraph("<!-- pan-notes:end dot=002 -->", id: "end"),
        .paragraph("Outside after", id: "outside-after")
    ]

    let ids = NotionMarkdownConverter.managedBlockIDs(in: blocks, dotID: "002")

    try expect(ids == ["start", "managed", "end"], "managed deletion includes markers and managed content")
}
