import XCTest
@testable import ApexText
@MainActor final class FileBrowserTests: XCTestCase {
    func testFolderFilteringAndSorting() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Notes"), withIntermediateDirectories: true)
        for name in ["b.md", "a.MD", "image.png", ".hidden.md", "draft.txt"] {
            try Data().write(to: root.appendingPathComponent(name))
        }
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("loop"), withDestinationURL: root)
        let children = try FolderContents.children(of: root)
        XCTAssertEqual(children.map(\.lastPathComponent), ["Notes", "a.MD", "b.md", "draft.txt"])
    }
}
