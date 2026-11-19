import XCTest
import AppKit
@testable import ApexText
@MainActor final class MarkdownShortcutTests: XCTestCase {
    private func event(_ key: String) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [.command, .option], timestamp: 0, windowNumber: 0, context: nil, characters: key, charactersIgnoringModifiers: key, isARepeat: false, keyCode: 0)!
    }
    func testHeadingShortcutsAndRestoreBody() {
        let view = MarkdownTextView()
        view.isRichText = false
        view.string = "First\nSecond\n"
        view.setSelectedRange(NSRange(location: 0, length: 5))
        XCTAssertTrue(view.performKeyEquivalent(with: event("2")))
        XCTAssertEqual(view.string, "## First\nSecond\n")
        view.setSelectedRange(NSRange(location: 0, length: 8))
        XCTAssertTrue(view.performKeyEquivalent(with: event("0")))
        XCTAssertEqual(view.string, "First\nSecond\n")
        XCTAssertNil(MarkdownShortcut.action(for: event("4")))
    }
    func testCodeShortcutPreservesSelection() {
        let view = MarkdownTextView()
        view.isRichText = false
        view.string = "echo hello"
        view.setSelectedRange(NSRange(location: 0, length: 10))
        XCTAssertTrue(view.performKeyEquivalent(with: event("c")))
        XCTAssertEqual(view.string, "```\necho hello\n```\n\n")
    }
    private func input(_ key: String, code: UInt16 = 0, modifiers: NSEvent.ModifierFlags = []) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0, windowNumber: 0, context: nil, characters: key, charactersIgnoringModifiers: key, isARepeat: false, keyCode: code)!
    }
    func testAllLanguageFencesAndBothTriggers() {
        for language in ["", "bash", "python", "javascript", "typescript", "swift", "java", "json", "yaml", "sql", "c++", "c#", "objective-c", "dockerfile", "custom.lang"] {
            for trigger in [" ", "\r"] {
                let view = MarkdownTextView()
                view.isRichText = false
                view.string = "```" + language
                view.setSelectedRange(NSRange(location: view.string.utf16.count, length: 0))
                view.keyDown(with: input(trigger))
                XCTAssertEqual(view.string, "```" + language + "\n\n```", language)
                XCTAssertEqual(view.selectedRange().location, language.utf16.count + 4)
            }
        }
    }
    func testTaskListContinuationAndIndentation() {
        let view = MarkdownTextView()
        view.isRichText = false
        view.string = "[]"
        view.setSelectedRange(NSRange(location: 2, length: 0))
        view.keyDown(with: input(" "))
        XCTAssertEqual(view.string, "- [ ] ")
        view.insertText("Task", replacementRange: view.selectedRange())
        view.keyDown(with: input("\r"))
        XCTAssertEqual(view.string, "- [ ] Task\n- [ ] ")
        view.keyDown(with: input("\t", code: 48))
        XCTAssertEqual(view.string, "- [ ] Task\n  - [ ] ")
        view.keyDown(with: input("\t", code: 48, modifiers: .shift))
        XCTAssertEqual(view.string, "- [ ] Task\n- [ ] ")
        view.keyDown(with: input("\r"))
        XCTAssertEqual(view.string, "- [ ] Task\n")
    }

}
