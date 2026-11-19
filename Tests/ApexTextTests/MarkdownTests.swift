import XCTest
@testable import ApexText
final class MarkdownTests: XCTestCase {
    func testStructureAndOutline() {
        let renderer = MarkdownRenderer(source: "# 标题\n正文\n\n### 子标题\n\n```md\n# 非标题\n```\n\n- 第一项\n  - 嵌套\n\n> 引用\n\n| A | B |\n|---|---|\n| 1 | 2 |")
        XCTAssertEqual(renderer.headings.map(\.text), ["标题", "子标题"])
        XCTAssertEqual(renderer.headings.map(\.id), [0, 3])
        let html = renderer.html.replacingOccurrences(of: #" data-language="[^"]*""#, with: "", options: .regularExpression).replacingOccurrences(of: #" data-source-(?:start|end)="[0-9]+""#, with: "", options: .regularExpression)
        XCTAssertTrue(renderer.html.contains("data-source-start=\"0\""))
        for expected in ["<h1 id=\"line-0\">标题</h1>", "<p>正文</p>", "<h3", "<ul>", "<blockquote>", "<table>", "<th>A</th>", "<td>1</td>", "<pre><code># 非标题"] { XCTAssertTrue(html.contains(expected), expected) }
    }
    func testSetextIndentationAndEscaping() {
        let renderer = MarkdownRenderer(source: "标题\n====\n\n    # 缩进代码\n\n<script>alert(1)</script>\n\n[坏链接](javascript:alert)\n\n- [x] 完成")
        XCTAssertEqual(renderer.headings.count, 1)
        XCTAssertTrue(renderer.html.contains("&lt;script&gt;"))
        XCTAssertFalse(renderer.html.contains("href=\"javascript:"))
        XCTAssertTrue(renderer.html.contains("disabled checked"))
    }
}
