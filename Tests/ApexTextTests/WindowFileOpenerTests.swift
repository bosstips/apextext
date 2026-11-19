import XCTest
import AppKit
@testable import ApexText
@MainActor final class WindowFileOpenerTests: XCTestCase {
    final class TestDocument: NSDocument {
        var text = "old"
        override func read(from data: Data, ofType typeName: String) throws {
            guard let value = String(data: data, encoding: .utf8) else { throw CocoaError(.fileReadInapplicableStringEncoding) }
            MainActor.assumeIsolated { text = value }
        }
        override func data(ofType typeName: String) throws -> Data { Data(text.utf8) }
    }
    func testReplacementKeepsWindowAndUpdatesSaveDestination() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let old = root.appendingPathComponent("old.md")
        let target = root.appendingPathComponent("new.md")
        try Data("old".utf8).write(to: old)
        try Data("new".utf8).write(to: target)
        let document = TestDocument()
        document.fileURL = old
        document.fileType = "public.plain-text"
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 600), styleMask: [.titled], backing: .buffered, defer: false)
        let controller = NSWindowController(window: window)
        document.addWindowController(controller)
        let opener = WindowFileOpener()
        let done = expectation(description: "Replaced")
        opener.open(target, document: document) { result in
            if case .failure(let error) = result { XCTFail(error.localizedDescription) }
            done.fulfill()
        }
        await fulfillment(of: [done], timeout: 5)
        XCTAssertEqual(document.text, "new")
        XCTAssertEqual(document.fileURL, target)
        XCTAssertTrue(document.windowControllers.first?.window === window)
        XCTAssertEqual(try String(contentsOf: old, encoding: .utf8), "old")
        document.close()
    }
    func testMissingFileDoesNotReplaceDocument() {
        let document = TestDocument()
        let opener = WindowFileOpener()
        var failed = false
        opener.open(URL(fileURLWithPath: "/nonexistent/\(UUID()).md"), document: document) { result in
            if case .failure = result { failed = true }
        }
        XCTAssertTrue(failed)
        XCTAssertEqual(document.text, "old")
    }
}
