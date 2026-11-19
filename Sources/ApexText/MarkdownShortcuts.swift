import AppKit
import WebKit

enum MarkdownShortcut: Equatable {
    case heading(Int)
    case codeBlock
    case format(String)
    static func action(for event: NSEvent) -> MarkdownShortcut? {
        let modifiers = event.modifierFlags.intersection([.command, .option, .shift, .control])
        guard let key = event.charactersIgnoringModifiers?.lowercased() else { return nil }
        if modifiers == [.command, .option] {
            if let level = Int(key), (0...3).contains(level) { return .heading(level) }
            if key == "c" { return .codeBlock }
            if key == "t" { return .format("task") }
            if key == "s" { return .format("divider") }
        }
        if modifiers == [.command], let format = ["b":"bold", "i":"italic", "u":"underline", "k":"link"][key] { return .format(format) }
        if modifiers == [.command, .shift], let format = ["x":"strike", "8":"bullet", "*":"bullet", "7":"numbered", "&":"numbered", ">":"quote", ".":"quote"][key] { return .format(format) }
        if modifiers == [.command, .control], key == "c" { return .format("inlineCode") }
        return nil
    }
}

final class MarkdownWebView: WKWebView {
    var allowsInlineEditing = false
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard allowsInlineEditing, let action = MarkdownShortcut.action(for: event) else { return super.performKeyEquivalent(with: event) }
        let script: String
        switch action {
        case .heading(let level): script = "window.apexTextInline?.applyCurrentHeading(\(level))"
        case .format(let action): script = "window.apexTextInline?.format(\"\(action)\")"
        case .codeBlock: script = "window.apexTextInline?.insertCode()"
        }
        evaluateJavaScript(script, completionHandler: nil)
        return true
    }
}
