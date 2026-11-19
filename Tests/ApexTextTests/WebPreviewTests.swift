import XCTest
import WebKit
@testable import ApexText
@MainActor final class WebPreviewTests: XCTestCase {
    final class Loader: NSObject, WKNavigationDelegate {
        let finished: XCTestExpectation
        init(_ finished: XCTestExpectation) { self.finished = finished }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { finished.fulfill() }
    }
    func testRenderedHierarchyAndJump() async throws {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        let web = WKWebView(frame: NSRect(x: 0, y: 0, width: 900, height: 600), configuration: config)
        let finished = expectation(description: "HTML loaded")
        let loader = Loader(finished)
        web.navigationDelegate = loader
        let source = "# Heading\nBody\n\n" + String(repeating: "Paragraph\n\n", count: 60) + "## Target"
        let renderer = MarkdownRenderer(source: source, fontName: "Menlo", fontSize: 20)
        web.loadHTMLString(renderer.html, baseURL: nil)
        await fulfillment(of: [finished], timeout: 20)
        let size = try await web.evaluateJavaScript("getComputedStyle(document.body).fontSize")
        XCTAssertEqual(size as? String, "20px")
        let family = try await web.evaluateJavaScript("getComputedStyle(document.body).fontFamily")
        XCTAssertTrue((family as? String ?? "").contains("Menlo"))
        let larger = try await web.evaluateJavaScript("parseFloat(getComputedStyle(document.querySelector('h1')).fontSize) > parseFloat(getComputedStyle(document.querySelector('p')).fontSize)")
        XCTAssertEqual(larger as? Bool, true)
        let coordinator = MarkdownPreview.Coordinator()
        coordinator.ready = true
        coordinator.line = renderer.headings.last!.id
        coordinator.scroll(web)
        let position = try await web.evaluateJavaScript("document.getElementById('line-\(renderer.headings.last!.id)').getBoundingClientRect().top")
        XCTAssertLessThan(abs((position as? Double ?? 10000) - 24), 3)
        _ = try await web.evaluateJavaScript(ReadingPosition.restoreScript(63.25))
        let captured = try await web.evaluateJavaScript(ReadingPosition.captureScript)
        XCTAssertEqual(captured as? Double ?? -1, 63.25, accuracy: 0.05)
        let scroll = NSTextView.scrollableTextView()
        scroll.frame = NSRect(x: 0, y: 0, width: 900, height: 600)
        let text = scroll.documentView as! NSTextView
        text.string = source
        text.font = .systemFont(ofSize: 16)
        scroll.layoutSubtreeIfNeeded()
        let reading = ReadingPosition()
        reading.textView = text
        reading.line = captured as? Double ?? 0
        reading.restoreEditor(text)
        reading.capture(preview: false) {}
        XCTAssertEqual(reading.line, 63.25, accuracy: 0.2)
        _ = try await web.evaluateJavaScript(ReadingPosition.restoreScript(reading.line))
        let roundTrip = try await web.evaluateJavaScript(ReadingPosition.captureScript)
        XCTAssertEqual(roundTrip as? Double ?? -1, 63.25, accuracy: 0.2)
    }
}
