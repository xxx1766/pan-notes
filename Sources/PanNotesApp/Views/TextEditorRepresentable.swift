import AppKit
import PanNotesCore
import SwiftUI

struct TextEditorRepresentable: NSViewRepresentable {
    @Binding var text: String
    @Binding var selectedRange: NSRange
    let fontSize: Double

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = PanTextView()
        textView.delegate = context.coordinator
        textView.font = Self.editorFont(size: fontSize)
        textView.string = text
        textView.setSelectedRange(selectedRange)
        textView.isRichText = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.textColor = .labelColor
        textView.insertionPointColor = .labelColor
        textView.textContainerInset = NSSize(width: 0, height: 12)
        textView.textContainer?.lineFragmentPadding = 0
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.usesFindPanel = true
        textView.isIncrementalSearchingEnabled = true
        textView.menu = Self.editMenu()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.scrollerStyle = .overlay
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? PanTextView else {
            return
        }
        textView.font = Self.editorFont(size: fontSize)
        if textView.string != text {
            textView.string = text
        }
        if textView.selectedRange() != selectedRange {
            textView.setSelectedRange(selectedRange)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, selectedRange: $selectedRange)
    }

    private static func editMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: ""))
        return menu
    }

    private static func editorFont(size: Double) -> NSFont {
        .systemFont(ofSize: size, weight: .regular)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding private var text: String
        @Binding private var selectedRange: NSRange

        init(text: Binding<String>, selectedRange: Binding<NSRange>) {
            self._text = text
            self._selectedRange = selectedRange
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }
            text = textView.string
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }
            selectedRange = textView.selectedRange()
        }
    }
}

final class PanTextView: NSTextView {
    override func insertNewline(_ sender: Any?) {
        apply(TextCommandProcessor.insertNewline(in: string, selectedRange: selectedRange()))
    }

    override func insertTab(_ sender: Any?) {
        apply(TextCommandProcessor.indentSelection(in: string, selectedRange: selectedRange()))
    }

    override func insertBacktab(_ sender: Any?) {
        apply(TextCommandProcessor.outdentSelection(in: string, selectedRange: selectedRange()))
    }

    override func keyDown(with event: NSEvent) {
        let commandPressed = event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command)
        if commandPressed && (event.keyCode == 36 || event.keyCode == 76) {
            toggleSmartBullet(event)
            return
        }
        super.keyDown(with: event)
    }

    @objc func insertSmartBullet(_ sender: Any?) {
        apply(TextCommandProcessor.insertSmartBullet(in: string, selectedRange: selectedRange()))
    }

    @objc func insertPlainBullet(_ sender: Any?) {
        apply(TextCommandProcessor.insertBullet(in: string, selectedRange: selectedRange()))
    }

    @objc func insertTextDivider(_ sender: Any?) {
        apply(TextCommandProcessor.insertDivider(in: string, selectedRange: selectedRange()))
    }

    @objc func insertCurrentDate(_ sender: Any?) {
        apply(TextCommandProcessor.insertText(Self.dateFormatter.string(from: Date()), in: string, selectedRange: selectedRange()))
    }

    @objc func insertCurrentTime(_ sender: Any?) {
        apply(TextCommandProcessor.insertText(Self.timeFormatter.string(from: Date()), in: string, selectedRange: selectedRange()))
    }

    @objc func toggleSmartBullet(_ sender: Any?) {
        apply(TextCommandProcessor.toggleSmartBullet(in: string, selectedRange: selectedRange()))
    }

    @objc func indentSelectedLines(_ sender: Any?) {
        apply(TextCommandProcessor.indentSelection(in: string, selectedRange: selectedRange()))
    }

    @objc func outdentSelectedLines(_ sender: Any?) {
        apply(TextCommandProcessor.outdentSelection(in: string, selectedRange: selectedRange()))
    }

    private func apply(_ result: TextEditResult) {
        let fullRange = NSRange(location: 0, length: (string as NSString).length)
        guard shouldChangeText(in: fullRange, replacementString: result.text) else {
            return
        }
        string = result.text
        didChangeText()
        setSelectedRange(result.selectedRange)
        scrollRangeToVisible(result.selectedRange)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}
