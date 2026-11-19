import XCTest
import AppKit
@testable import ApexText

@MainActor final class FormattingMenuTests: XCTestCase {
    func testMenuCommandsChangeMarkdownAndKeepSurroundingText() {
        let view = MarkdownTextView()
        view.isRichText = false
        for (command, expected) in [
            ("bold", "Before **中文** after"),
            ("italic", "Before *中文* after"),
            ("underline", "Before <u>中文</u> after"),
            ("strike", "Before ~~中文~~ after"),
            ("inlineCode", "Before `中文` after"),
            ("link", "Before [中文](https://) after"),
            ("bullet", "- Before 中文 after"),
            ("numbered", "1. Before 中文 after"),
            ("task", "- [ ] Before 中文 after"),
            ("quote", "> Before 中文 after"),
            ("heading:2", "## Before 中文 after")
        ] {
            view.string = "Before 中文 after"
            view.setSelectedRange(NSRange(location: 7, length: 2))
            let menu = FormattingMenu.make(target: view, action: #selector(MarkdownTextView.applyContextFormat(_:)))
            let entries = menu.items + (menu.items.first?.submenu?.items ?? [])
            guard let item = entries.first(where: { $0.representedObject as? String == command }) else { XCTFail("Missing command \(command)"); continue }
            view.applyContextFormat(item)
            XCTAssertEqual(view.string, expected, command)
        }
    }
}
