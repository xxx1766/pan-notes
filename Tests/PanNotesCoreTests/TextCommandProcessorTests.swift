import Foundation
import PanNotesCore

let textCommandProcessorTests: [TestCase] = [
    TestCase("toggleSmartBulletAddsUncheckedMarker", toggleSmartBulletAddsUncheckedMarker),
    TestCase("toggleSmartBulletSwitchesUncheckedToChecked", toggleSmartBulletSwitchesUncheckedToChecked),
    TestCase("insertNewlineContinuesChecklist", insertNewlineContinuesChecklist),
    TestCase("insertNewlineExitsEmptyChecklist", insertNewlineExitsEmptyChecklist),
    TestCase("indentAndOutdentSelectedLines", indentAndOutdentSelectedLines),
    TestCase("toggleTaskItemByIndex", toggleTaskItemByIndex),
    TestCase("quickInsertsReplaceSelection", quickInsertsReplaceSelection)
]

private func toggleSmartBulletAddsUncheckedMarker() throws {
    let result = TextCommandProcessor.toggleSmartBullet(
        in: "Buy milk",
        selectedRange: NSRange(location: 0, length: 0)
    )

    try expect(result.text == "- [ ] Buy milk", "plain current line gets unchecked smart bullet")
}

private func toggleSmartBulletSwitchesUncheckedToChecked() throws {
    let result = TextCommandProcessor.toggleSmartBullet(
        in: "- [ ] Buy milk",
        selectedRange: NSRange(location: 4, length: 0)
    )

    try expect(result.text == "- [x] Buy milk", "unchecked smart bullet toggles checked")
}

private func insertNewlineContinuesChecklist() throws {
    let result = TextCommandProcessor.insertNewline(
        in: "  - [x] Done",
        selectedRange: NSRange(location: 13, length: 0)
    )

    try expect(result.text == "  - [x] Done\n  - [ ] ", "return continues checklist indentation")
}

private func insertNewlineExitsEmptyChecklist() throws {
    let result = TextCommandProcessor.insertNewline(
        in: "  - [ ] ",
        selectedRange: NSRange(location: 8, length: 0)
    )

    try expect(result.text == "  ", "return on empty checklist exits list")
}

private func indentAndOutdentSelectedLines() throws {
    let indented = TextCommandProcessor.indentSelection(
        in: "one\ntwo",
        selectedRange: NSRange(location: 0, length: 7)
    )

    try expect(indented.text == "    one\n    two", "selected lines indent")

    let outdented = TextCommandProcessor.outdentSelection(
        in: indented.text,
        selectedRange: NSRange(location: 0, length: (indented.text as NSString).length)
    )

    try expect(outdented.text == "one\ntwo", "selected lines outdent")
}

private func toggleTaskItemByIndex() throws {
    let result = TextCommandProcessor.toggleTaskItem(
        at: 1,
        in: "- [ ] First\n- [x] Second\n- [ ] Third"
    )

    try expect(result?.text == "- [ ] First\n- [ ] Second\n- [ ] Third", "task item toggles by index")
}

private func quickInsertsReplaceSelection() throws {
    let result = TextCommandProcessor.insertDivider(
        in: "a selected word",
        selectedRange: NSRange(location: 2, length: 8)
    )

    try expect(result.text == "a --- word", "quick insert replaces selected range")
}
