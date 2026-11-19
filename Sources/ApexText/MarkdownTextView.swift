import AppKit

final class MarkdownTextView: NSTextView {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard !hasMarkedText(), let action = MarkdownShortcut.action(for: event) else { return super.performKeyEquivalent(with: event) }
        apply(action)
        return true
    }
    private func apply(_ action: MarkdownShortcut) {
        guard !hasMarkedText() else { return }
        switch action {
        case .heading(let level):
            let item = NSMenuItem(); item.tag = level; applyHeading(item)
        case .format(let action): applyFormat(action)
        case .codeBlock:
            let selection = selectedRange()
            let body = (string as NSString).substring(with: selection)
            let longest = body.components(separatedBy: CharacterSet(charactersIn: "`").inverted).map(\.count).max() ?? 0
            let fence = String(repeating: "`", count: max(3, longest + 1))
            let before = (string as NSString).substring(to: selection.location)
            let prefix = before.isEmpty || before.hasSuffix("\n\n") ? "" : (before.hasSuffix("\n") ? "\n" : "\n\n")
            let replacement = prefix + fence + "\n" + body + "\n" + fence + "\n\n"
            insertText(replacement, replacementRange: selection)
            setSelectedRange(NSRange(location: selection.location + (prefix as NSString).length + fence.count + 1, length: (body as NSString).length))
        }
    }
    private func applyFormat(_ action: String) {
        let range = selectedRange(), source = string as NSString
        let text = source.substring(with: range)
        let wrappers = ["bold": ("**", "**"), "italic": ("*", "*"), "underline": ("<u>", "</u>"), "strike": ("~~", "~~"), "inlineCode": ("`", "`")]
        if let (left, right) = wrappers[action] {
            let start = range.location - left.utf16.count
            let leadingStars = source.substring(to: range.location).reversed().prefix { $0 == "*" }.count
            let trailingStars = source.substring(from: NSMaxRange(range)).prefix { $0 == "*" }.count
            let italicActive = action != "italic" || (leadingStars % 2 == 1 && trailingStars % 2 == 1)
            if italicActive, start >= 0, NSMaxRange(range) + right.utf16.count <= source.length,
               source.substring(with: NSRange(location: start, length: left.utf16.count)) == left,
               source.substring(with: NSRange(location: NSMaxRange(range), length: right.utf16.count)) == right {
                insertText(text, replacementRange: NSRange(location: start, length: left.utf16.count + range.length + right.utf16.count))
                setSelectedRange(NSRange(location: start, length: range.length))
            } else {
                insertText(left + text + right, replacementRange: range)
                setSelectedRange(NSRange(location: range.location + left.utf16.count, length: range.length))
            }
        } else if action == "link" {
            insertText("[" + text + "](https://)", replacementRange: range)
            setSelectedRange(NSRange(location: range.location + range.length + 3, length: 8))
        } else {
            let lines = source.lineRange(for: NSRange(location: range.location, length: max(0, range.length - 1)))
            let old = source.substring(with: lines)
            if action == "divider" { insertText("---\n\n" + old, replacementRange: lines); return }
            let prefix = ["bullet":"- ", "numbered":"1. ", "task":"- [ ] ", "quote":"> "][action] ?? ""
            let replacement = old.components(separatedBy: "\n").enumerated().map { index, line in
                line.isEmpty && index > 0 ? line : prefix + line.replacingOccurrences(of: "^(?:[-*+] |[0-9]+\\. |> )", with: "", options: .regularExpression)
            }.joined(separator: "\n")
            insertText(replacement, replacementRange: lines)
        }
    }
    override func keyDown(with event: NSEvent) {
        guard !hasMarkedText(), !event.modifierFlags.contains(.command), !event.modifierFlags.contains(.control), selectedRange().length == 0 else { super.keyDown(with: event); return }
        let caret = selectedRange().location, source = string as NSString
        let range = source.lineRange(for: NSRange(location: caret, length: 0))
        let before = source.substring(with: NSRange(location: range.location, length: caret - range.location))
        let previous = source.substring(to: range.location)
        let fences = previous.components(separatedBy: "\n").filter { $0.range(of: "^ {0,3}(?:`{3,}|~{3,})", options: .regularExpression) != nil }.count
        let inCode = fences % 2 == 1
        let key = event.charactersIgnoringModifiers ?? ""
        if !inCode && (key == " " || key == "\r"), before.range(of: "^ {0,3}`{3,}[A-Za-z0-9_+#.\\-]*$", options: .regularExpression) != nil {
            let opener = before.trimmingCharacters(in: .whitespaces)
            let fence = String(opener.prefix(while: { $0 == "`" }))
            insertText(opener + "\n\n" + fence, replacementRange: NSRange(location: range.location, length: caret - range.location))
            setSelectedRange(NSRange(location: range.location + opener.utf16.count + 1, length: 0)); return
        }
        if !inCode && key == " " && ["[]", "[ ]"].contains(before) {
            insertText("- [ ] ", replacementRange: NSRange(location: range.location, length: caret - range.location)); return
        }
        if event.keyCode == 48 {
            if event.modifierFlags.contains(.shift) {
                let leading = String(before.prefix(while: { $0 == " " || $0 == "\t" }))
                let count = leading.first == "\t" ? 1 : min(2, leading.count)
                if count > 0 { insertText("", replacementRange: NSRange(location: range.location, length: count)); setSelectedRange(NSRange(location: max(range.location, caret - count), length: 0)) }
            } else if inCode { insertText("  ", replacementRange: selectedRange()) }
            else { insertText("  ", replacementRange: NSRange(location: range.location, length: 0)); setSelectedRange(NSRange(location: caret + 2, length: 0)) }
            return
        }
        if !inCode && key == "\r" && !event.modifierFlags.contains(.shift),
           let regex = try? NSRegularExpression(pattern: "^(\\s*)([-*+] |[0-9]+\\. |> )((?:\\[[ xX]\\] )?)(.*)$"),
           let match = regex.firstMatch(in: before, range: NSRange(location: 0, length: before.utf16.count)) {
            let value = before as NSString
            let body = value.substring(with: match.range(at: 4))
            if body.trimmingCharacters(in: .whitespaces).isEmpty { insertText("", replacementRange: NSRange(location: range.location, length: caret - range.location)); return }
            var marker = value.substring(with: match.range(at: 2))
            if let n = Int(marker.trimmingCharacters(in: CharacterSet(charactersIn: ". "))) { marker = "\(n + 1). " }
            let task = match.range(at: 3).length > 0 ? "[ ] " : ""
            insertText("\n" + value.substring(with: match.range(at: 1)) + marker + task, replacementRange: selectedRange()); return
        }
        super.keyDown(with: event)
    }
    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event) ?? NSMenu()
        guard selectedRange().length > 0 else { return menu }
        menu.addItem(.separator())
        let format = FormattingMenu.make(target: self, action: #selector(applyContextFormat(_:)))
        for item in format.items { format.removeItem(item); menu.addItem(item) }
        return menu
    }
    @objc func applyContextFormat(_ sender: NSMenuItem) {
        guard !hasMarkedText(), let command = sender.representedObject as? String else { return }
        if command == "font" { selectFont(sender) }
        else if command.hasPrefix("heading:"), let level = Int(command.dropFirst(8)) { apply(.heading(level)) }
        else if command == "codeBlock" { apply(.codeBlock) }
        else { apply(.format(command)) }
    }
    @objc private func selectFont(_ sender: NSMenuItem) { FontPreferences.shared.showPanel() }
    @objc private func applyHeading(_ sender: NSMenuItem) {
        guard !hasMarkedText() else { return }
        let selected = selectedRange()
        let source = string as NSString
        let range = source.lineRange(for: NSRange(location: selected.location, length: max(0, selected.length - 1)))
        let old = source.substring(with: range)
        let lines = old.components(separatedBy: "\n")
        let replacement = lines.map { line -> String in
            guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return line }
            let plain = line.replacingOccurrences(of: "^ {0,3}#{1,6}[ \\t]+", with: "", options: .regularExpression)
            return (sender.tag == 0 ? "" : String(repeating: "#", count: sender.tag) + " ") + plain
        }.joined(separator: "\n")
        insertText(replacement, replacementRange: range)
    }
}
