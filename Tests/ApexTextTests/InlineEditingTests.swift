import XCTest
import WebKit
@testable import ApexText
@MainActor final class InlineEditingTests: XCTestCase {
    func testEditingCommandsCompositionAndRoundTrip() async throws {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        config.userContentController.addUserScript(WKUserScript(source: MarkdownPreview.inlineScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        let coordinator = MarkdownPreview.Coordinator()
        for name in ["editMarkdown", "commitMarkdown", "historyMarkdown"] { config.userContentController.add(coordinator, name: name) }
        let web = WKWebView(frame: NSRect(x: 0, y: 0, width: 900, height: 700), configuration: config)
        coordinator.view = web
        web.navigationDelegate = coordinator
        let original = "# Original\n\nKeep **this** & <tag> unchanged.\n\nLast paragraph\n"
        var updated = original
        coordinator.source = original
        coordinator.onEdit = { updated = $0 }
        coordinator.load(web)
        try await waitReady(web)
        _ = try await web.evaluateJavaScript("window.apexTextInline.activate(2)")
        let outline = try await web.evaluateJavaScript("getComputedStyle(document.querySelector('.editing')).outlineStyle")
        XCTAssertEqual(outline as? String, "none")
        let editorHeight = try await web.evaluateJavaScript("document.querySelector('textarea').getBoundingClientRect().height")
        XCTAssertLessThan(editorHeight as? Double ?? 1000, 60)
        let padding = try await web.evaluateJavaScript("getComputedStyle(document.querySelector('.editing')).paddingTop")
        XCTAssertEqual(padding as? String, "0px")
        _ = try await web.evaluateJavaScript("var a=document.querySelector('textarea');a.dispatchEvent(new CompositionEvent('compositionstart'));a.value='中文输入';a.dispatchEvent(new Event('input'))")
        XCTAssertEqual(updated, original)
        _ = try await web.evaluateJavaScript("a.dispatchEvent(new CompositionEvent('compositionend'))")
        try await waitSource({ updated }, contains: "中文输入")
        XCTAssertTrue(updated.hasPrefix("# Original\n\nKeep **this** & <tag> unchanged.\n\n"))
        _ = try await web.evaluateJavaScript("document.dispatchEvent(new KeyboardEvent('keydown',{key:'2',metaKey:true,altKey:true,bubbles:true}))")
        try await waitSource({ updated }, contains: "## 中文输入")
        _ = try await web.evaluateJavaScript("a.value='/code';a.dispatchEvent(new Event('input'));a.dispatchEvent(new KeyboardEvent('keydown',{key:'Enter',bubbles:true}))")
        try await waitSource({ updated }, contains: "```\n\n```" )
        _ = try await web.evaluateJavaScript("a.value='```bash';a.dispatchEvent(new Event('input'));a.dispatchEvent(new KeyboardEvent('keydown',{key:'Enter',bubbles:true}))")
        try await waitSource({ updated }, contains: "```bash")
        let addButtonCount = try await web.evaluateJavaScript("document.querySelectorAll('.add-block').length")
        XCTAssertEqual(addButtonCount as? Int, 0)
        let menuCount = try await web.evaluateJavaScript("document.querySelectorAll('.block-toolbar,select').length")
        XCTAssertEqual(menuCount as? Int, 0)
        let final = updated
        _ = try await web.evaluateJavaScript("window.apexTextInline.commit()")
        try await waitReady(web)
        XCTAssertEqual(updated, final)
        XCTAssertTrue(MarkdownRenderer(source: final).html.contains("<pre"))
        _ = try await web.evaluateJavaScript("document.dispatchEvent(new KeyboardEvent('keydown',{key:'z',metaKey:true,bubbles:true}))")
        try await waitSource({ updated }, contains: "Last paragraph")
        XCTAssertEqual(updated, original)
        for name in ["editMarkdown", "commitMarkdown", "historyMarkdown"] { config.userContentController.removeScriptMessageHandler(forName: name) }
    }

    func testLanguageTriggersAndEmptyDocumentWithoutButton() async throws {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        config.userContentController.addUserScript(WKUserScript(source: MarkdownPreview.inlineScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        let coordinator = MarkdownPreview.Coordinator()
        for name in ["editMarkdown", "commitMarkdown", "historyMarkdown"] { config.userContentController.add(coordinator, name: name) }
        let web = WKWebView(frame: NSRect(x: 0, y: 0, width: 900, height: 700), configuration: config)
        coordinator.view = web
        web.navigationDelegate = coordinator
        coordinator.source = ""
        var updated = ""
        coordinator.onEdit = { updated = $0 }
        coordinator.load(web)
        try await waitReady(web)
        _ = try await web.evaluateJavaScript("document.querySelector('.empty-block').click()")
        for language in ["", "bash", "python", "javascript", "typescript", "swift", "java", "json", "yaml", "sql", "c++", "c#", "objective-c", "dockerfile", "custom.lang"] {
            for trigger in [" ", "Enter"] {
                _ = try await web.callAsyncJavaScript("const a=document.querySelector('textarea');a.value='```'+language;a.dispatchEvent(new Event('input'));a.dispatchEvent(new KeyboardEvent('keydown',{key:trigger,bubbles:true}));", arguments: ["language":language,"trigger":trigger], in: nil, contentWorld: .page)
                try await waitSource({updated}, contains: "```" + language + "\n\n```")
            }
        }
        _ = try await web.evaluateJavaScript("var a=document.querySelector('textarea');a.value='Keep this /code';a.dispatchEvent(new Event('input'));a.dispatchEvent(new KeyboardEvent('keydown',{key:'Enter',bubbles:true}))")
        try await waitSource({updated}, contains: "```\nKeep this ")
        XCTAssertTrue(updated.contains("Keep this"))
        for name in ["editMarkdown", "commitMarkdown", "historyMarkdown"] { config.userContentController.removeScriptMessageHandler(forName: name) }
    }
    final class MenuCapture: NSObject, WKScriptMessageHandler {
        var canFormat = false
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            canFormat = (message.body as? [String: Any])?["canFormatText"] as? Bool == true
        }
    }
    func testContextFormattingPreservesRenderedSelection() async throws {
        let config = WKWebViewConfiguration()
        config.userContentController.addUserScript(WKUserScript(source: MarkdownPreview.inlineScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        let coordinator = MarkdownPreview.Coordinator()
        let capture = MenuCapture()
        config.userContentController.add(coordinator, name: "editMarkdown")
        config.userContentController.add(capture, name: "selectionMenu")
        defer {
            config.userContentController.removeScriptMessageHandler(forName: "editMarkdown")
            config.userContentController.removeScriptMessageHandler(forName: "selectionMenu")
        }
        let web = WKWebView(frame: NSRect(x: 0, y: 0, width: 900, height: 700), configuration: config)
        coordinator.view = web
        web.navigationDelegate = coordinator
        var updated = "# Title\n\nBefore 中文 after\n"
        coordinator.source = updated
        coordinator.onEdit = { updated = $0 }
        coordinator.load(web)
        try await waitReady(web)
        _ = try await web.evaluateJavaScript("""
        const p = document.querySelector('p'), range = document.createRange();
        range.setStart(p.firstChild, 7); range.setEnd(p.firstChild, 9);
        window.getSelection().removeAllRanges(); window.getSelection().addRange(range);
        p.dispatchEvent(new MouseEvent('contextmenu', {bubbles:true,cancelable:true}));
        """)
        let item = NSMenuItem(); item.representedObject = "bold"
        coordinator.applyContextFormat(item)
        try await waitSource({ updated }, contains: "Before **中文** after")
        XCTAssertTrue(capture.canFormat)
        XCTAssertEqual(updated, "# Title\n\nBefore **中文** after\n")
        _ = try await web.evaluateJavaScript("""
        const a = document.querySelector('textarea');
        a.dispatchEvent(new MouseEvent('contextmenu', {bubbles:true,cancelable:true}));
        """)
        item.representedObject = "italic"
        coordinator.applyContextFormat(item)
        try await waitSource({ updated }, contains: "***中文***")
    }

    private func waitReady(_ web: WKWebView) async throws {
        for _ in 0..<100 {
            if (try? await web.evaluateJavaScript("document.querySelector('main')?.dataset.editorReady === 'true'")) as? Bool == true { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTFail("Inline editor did not initialize")
    }
    private func waitSource(_ value: () -> String, contains: String) async throws {
        for _ in 0..<100 {
            if value().contains(contains) { return }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTFail("Missing expected Markdown: \(contains). Actual: \(value())")
    }
    func testRangesPreserveUnicodeCRLFAndBlankLines() {
        let source = "# 标题😀\r\n\r\n正文\r\n\r\n```swift\r\nlet x = 1\r\n```\r\n"
        let renderer = MarkdownRenderer(source: source)
        XCTAssertEqual(renderer.editableRanges.count, 3)
        let range = renderer.editableRanges[1]
        XCTAssertEqual((source as NSString).substring(with: NSRange(location: range["start"]!, length: range["end"]! - range["start"]!)), "正文\r\n")
    }
}
