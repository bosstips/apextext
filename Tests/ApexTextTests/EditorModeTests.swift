import XCTest
import WebKit
@testable import ApexText

@MainActor final class EditorModeTests: XCTestCase {
    func testCycleIncludesEveryMode() {
        for mode in EditorMode.allCases {
            XCTAssertEqual(Set([mode, mode.next, mode.next.next]), Set(EditorMode.allCases))
            XCTAssertEqual(mode.next.next.next, mode)
        }
    }

    func testAllTransitionsPreserveContentAndReadingPosition() async throws {
        let source = "# Start\n\n" + (0..<90).map { "Paragraph \($0) with **text** and 中文.\n\n" }.joined()
        for from in EditorMode.allCases {
            for to in EditorMode.allCases where to != from {
                let reading = ReadingPosition()
                var synchronized = source
                let (origin, originDelegate) = try await web(source, inline: from == .inline)
                defer { _ = originDelegate }
                let sourceScroll = native(source)
                reading.webView = origin
                reading.textView = sourceScroll.documentView as? NSTextView
                if from == .source {
                    reading.line = 62.25
                    reading.restoreEditor(reading.textView!)
                } else {
                    _ = try await origin.evaluateJavaScript(ReadingPosition.restoreScript(62.25))
                }
                let captured = expectation(description: "Capture \(from) to \(to)")
                reading.capture(preview: from != .source, synchronize: { synchronized = $0 }) { captured.fulfill() }
                await fulfillment(of: [captured], timeout: 5)
                XCTAssertEqual(synchronized, source)
                XCTAssertEqual(reading.line, 62.25, accuracy: 0.2)
                if to == .source {
                    let target = native(synchronized)
                    reading.textView = target.documentView as? NSTextView
                    reading.restoreEditor(reading.textView!)
                    reading.capture(preview: false) {}
                    XCTAssertEqual(reading.line, 62.25, accuracy: 0.2)
                } else {
                    let (target, targetDelegate) = try await web(synchronized, inline: to == .inline)
                    defer { _ = targetDelegate }
                    _ = try await target.evaluateJavaScript(ReadingPosition.restoreScript(reading.line))
                    let actual = try await target.evaluateJavaScript(ReadingPosition.captureScript)
                    XCTAssertEqual(actual as? Double ?? -1, 62.25, accuracy: 0.2)
                    let editable = try await target.evaluateJavaScript("typeof window.apexTextInline !== 'undefined'")
                    XCTAssertEqual(editable as? Bool, to == .inline)
                }
            }
        }
    }

    func testSwitchFlushesActiveEditAndProtectsComposition() async throws {
        let (view, coordinator) = try await web("# Title\n\nOriginal\n", inline: true)
        defer { _ = coordinator }
        let reading = ReadingPosition()
        reading.webView = view
        _ = try await view.evaluateJavaScript("window.apexTextInline.activate(1);document.querySelector('textarea').value='Unsaved 中文';")
        var text = ""
        let captured = expectation(description: "Flushed edit")
        reading.capture(preview: true, synchronize: { text = $0 }) { captured.fulfill() }
        await fulfillment(of: [captured], timeout: 5)
        XCTAssertEqual(text, "# Title\n\nUnsaved 中文\n")
        _ = try await view.evaluateJavaScript("document.querySelector('textarea').dispatchEvent(new CompositionEvent('compositionstart'))")
        let prevented = expectation(description: "Do not destroy uncommitted input")
        prevented.isInverted = true
        reading.capture(preview: true) { prevented.fulfill() }
        await fulfillment(of: [prevented], timeout: 0.3)
        XCTAssertFalse(reading.switching)
        _ = try await view.evaluateJavaScript("document.querySelector('textarea').dispatchEvent(new CompositionEvent('compositionend'))")
        let resumed = expectation(description: "Switch after composition")
        reading.capture(preview: true) { resumed.fulfill() }
        await fulfillment(of: [resumed], timeout: 5)
    }

    private func native(_ source: String) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        scroll.frame = NSRect(x: 0, y: 0, width: 900, height: 600)
        let text = scroll.documentView as! NSTextView
        text.string = source
        text.font = .systemFont(ofSize: 16)
        scroll.layoutSubtreeIfNeeded()
        return scroll
    }

    private func web(_ source: String, inline: Bool) async throws -> (WKWebView, MarkdownPreview.Coordinator) {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        if inline {
            config.userContentController.addUserScript(WKUserScript(source: MarkdownPreview.inlineScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        }
        let view = WKWebView(frame: NSRect(x: 0, y: 0, width: 900, height: 600), configuration: config)
        let coordinator = MarkdownPreview.Coordinator()
        coordinator.source = source
        coordinator.view = view
        coordinator.onEdit = inline ? { _ in } : nil
        view.navigationDelegate = coordinator
        coordinator.load(view)
        for _ in 0..<200 {
            if coordinator.ready {
                let ready = try? await view.evaluateJavaScript(inline ? "document.querySelector('main')?.dataset.editorReady === 'true'" : "document.readyState === 'complete'")
                if ready as? Bool == true { return (view, coordinator) }
            }
            try await Task.sleep(for: .milliseconds(25))
        }
        throw NSError(domain: "EditorModeTests.LoadTimeout", code: 1)
    }
}
