import AppKit

@MainActor enum FormattingMenu {
    static func make(target: AnyObject, action: Selector, canFormatText: Bool = true) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        func item(_ title: String, _ command: String, _ symbol: String, _ key: String = "", _ modifiers: NSEvent.ModifierFlags = .command) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
            item.target = target
            item.representedObject = command
            item.keyEquivalentModifierMask = modifiers
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
            return item
        }
        let styles = NSMenu()
        styles.autoenablesItems = false
        for level in 0...6 {
            styles.addItem(item(level == 0 ? "Body Text" : "Heading \(level)", "heading:\(level)", level == 0 ? "text.alignleft" : "textformat.size", level <= 3 ? String(level) : "", [.command, .option]))
        }
        let turnInto = NSMenuItem(title: "Turn Into", action: nil, keyEquivalent: "")
        turnInto.submenu = styles
        menu.addItem(turnInto)
        menu.addItem(.separator())
        for (title, command, symbol, key, modifiers) in [
            ("Bold", "bold", "bold", "b", NSEvent.ModifierFlags.command),
            ("Italic", "italic", "italic", "i", .command),
            ("Underline", "underline", "underline", "u", .command),
            ("Strikethrough", "strike", "strikethrough", "x", [.command, .shift]),
            ("Inline Code", "inlineCode", "chevron.left.forwardslash.chevron.right", "c", [.command, .control]),
            ("Add Link", "link", "link", "k", .command)
        ] {
            let entry = item(title, command, symbol, key, modifiers)
            entry.isEnabled = canFormatText
            menu.addItem(entry)
        }
        menu.addItem(.separator())
        for (title, command, symbol, key, modifiers) in [
            ("Bulleted List", "bullet", "list.bullet", "8", NSEvent.ModifierFlags([.command, .shift])),
            ("Numbered List", "numbered", "list.number", "7", [.command, .shift]),
            ("Task List", "task", "checklist", "t", [.command, .option]),
            ("Quote", "quote", "text.quote", ">", [.command, .shift]),
            ("Code Block", "codeBlock", "curlybraces", "c", [.command, .option])
        ] { menu.addItem(item(title, command, symbol, key, modifiers)) }
        menu.addItem(.separator())
        menu.addItem(item("Font…", "font", "textformat"))
        return menu
    }
}
