import Foundation
import Markdown

struct OutlineEntry: Identifiable {
    let id: Int
    let text: String
    let level: Int
}

struct MarkdownRenderer {
    let document: Document
    let source: String
    let fontName: String
    let fontSize: Double
    init(source: String, fontName: String = "", fontSize: Double = 16) {
        self.source = source
        document = Document(parsing: source)
        self.fontName = fontName
        self.fontSize = fontSize
    }
    private var cssFont: String {
        let escaped = fontName.unicodeScalars.map { "\\" + String($0.value, radix: 16) + " " }.joined()
        return fontName.isEmpty ? "-apple-system,BlinkMacSystemFont,sans-serif" : "'\(escaped)',-apple-system,sans-serif"
    }
    var headings: [OutlineEntry] {
        func collect(_ node: any Markup) -> [OutlineEntry] {
            if let heading = node as? Heading {
                return [.init(id: (heading.range?.lowerBound.line ?? 1) - 1, text: heading.plainText, level: heading.level)]
            }
            return node.children.flatMap { collect($0) }
        }
        return collect(document)
    }
    static func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
    }
    func render(_ node: any Markup) -> String {
        let content = node.children.map { render($0) }.joined()
        func tag(_ name: String, _ body: String? = nil, attributes: String = "") -> String {
            let tracked = ["h1", "h2", "h3", "h4", "h5", "h6", "p", "pre", "tr"].contains(name)
            let source = tracked && node.range != nil ? " data-source-start=\"\(node.range!.lowerBound.line - 1)\" data-source-end=\"\(node.range!.upperBound.line - 1)\"" : ""
            return "<\(name)\(attributes)\(source)>\(body ?? content)</\(name)>"
        }
        switch node {
        case let text as Markdown.Text: return Self.escape(text.string)
        case let heading as Heading:
            return tag("h\(heading.level)", attributes: " id=\"line-\((heading.range?.lowerBound.line ?? 1) - 1)\"")
        case is Paragraph: return tag("p")
        case is Strong: return tag("strong")
        case is Emphasis: return tag("em")
        case is Strikethrough: return tag("del")
        case let code as InlineCode: return tag("code", Self.escape(code.code))
        case let code as CodeBlock: return tag("pre", tag("code", Self.escape(code.code)), attributes: " data-language=\"\(Self.escape(code.language ?? "Plain Text"))\"")
        case is BlockQuote: return tag("blockquote")
        case let list as OrderedList: return tag("ol", attributes: " start=\"\(list.startIndex)\"")
        case is UnorderedList: return tag("ul")
        case let item as ListItem:
            let checkbox = item.checkbox.map { "<input type=\"checkbox\" disabled \($0 == .checked ? "checked" : "")>" } ?? ""
            return tag("li", checkbox + content)
        case is ThematicBreak: return "<hr>"
        case is SoftBreak: return "\n"
        case is LineBreak: return "<br>"
        case let link as Link:
            guard let destination = link.destination, let url = URL(string: destination), ["https", "http", "mailto"].contains(url.scheme?.lowercased() ?? "") else { return content }
            return tag("a", attributes: " href=\"\(Self.escape(destination))\"")
        case let image as Markdown.Image:
            guard let destination = image.source, URL(string: destination)?.scheme?.lowercased() == "https" else { return tag("span", "[Image: \(Self.escape(image.plainText))]") }
            return "<img src=\"\(Self.escape(destination))\" alt=\"\(Self.escape(image.plainText))\">"
        case is Table: return tag("div", tag("table"), attributes: " class=\"table-wrap\"")
        case is Table.Head: return tag("thead", tag("tr"))
        case is Table.Body: return tag("tbody")
        case is Table.Row: return tag("tr")
        case is Table.Cell: return tag(node.parent is Table.Head ? "th" : "td")
        case let html as HTMLBlock: return tag("pre", Self.escape(html.rawHTML))
        case let html as InlineHTML: return ["<u>", "</u>"].contains(html.rawHTML.lowercased()) ? html.rawHTML.lowercased() : Self.escape(html.rawHTML)
        default: return content
        }
    }
    var editableRanges: [[String: Int]] {
        let lines = source.components(separatedBy: "\n")
        var offsets = [0]
        for line in lines { offsets.append(offsets.last! + (line as NSString).length + 1) }
        return document.children.compactMap { node in
            guard let range = node.range else { return nil }
            return ["start": offsets[min(range.lowerBound.line - 1, lines.count)], "end": min((source as NSString).length, offsets[min(range.upperBound.line, lines.count)])]
        }
    }
    var editableHTML: String {
        let body = document.children.enumerated().map { index, node in
            "<section data-edit-block=\"\(index)\" data-source-start=\"\((node.range?.lowerBound.line ?? 1) - 1)\" data-source-end=\"\((node.range?.upperBound.line ?? 1) - 1)\">\(render(node))</section>"
        }.joined()
        let style = """
        <style>
        [data-edit-block]{position:relative;min-height:1lh;cursor:text}[data-edit-block]:hover{outline:none}[data-edit-block]:focus-visible{outline:none}
        .editing{outline:none;border:0;padding:0;background:transparent}.block-input{display:block;box-sizing:border-box;width:100%;resize:none;border:0;outline:none;box-shadow:none;background:transparent;color:CanvasText;font:inherit;line-height:inherit;padding:0;overflow:hidden;appearance:none}.code-edit .block-input{background:var(--code);padding:16px;border-radius:5px}
        .block-toolbar{display:flex;gap:8px;align-items:center;flex-wrap:wrap;font:12px -apple-system;color:var(--muted)}.block-toolbar select,.block-toolbar button,.add-block,.slash-menu button{font:13px -apple-system;color:CanvasText;background:var(--code);border:1px solid var(--border);border-radius:5px;padding:5px 8px;cursor:pointer}
        .slash-menu{padding:8px;border:1px solid var(--border);border-radius:6px}.slash-menu button{margin:3px}.empty-block{min-height:40px;margin-top:16px;cursor:text}
        </style>
        """
        return html.replacingOccurrences(of: "<main>\(render(document))</main>", with: "<main>\(body)</main>").replacingOccurrences(of: "</head>", with: style + "</head>")
    }
    var html: String {
        """
        <!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; img-src https:; script-src 'none'">
        <style>
        :root {color-scheme:light dark;--muted:#737780;--border:#dce0e5;--code:#f4f5f7}
        @media(prefers-color-scheme:dark){:root{--border:#3c4048;--code:#252830}}
        body{font:\(fontSize)px/1.75 \(cssFont);margin:0;padding:32px 40px calc(100vh - 40px);color:CanvasText;background:Canvas;overflow-wrap:anywhere}
        main{max-width:850px;margin:auto} h1,h2,h3,h4,h5,h6{line-height:1.3;margin:1.5em 0 .6em;scroll-margin-top:24px}
        h1{font-size:2em}h2{font-size:1.6em;border-bottom:1px solid var(--border);padding-bottom:.3em}h3{font-size:1.3em}h4{font-size:1.12em}h5,h6{font-size:1em}h6{color:var(--muted)}
        p{margin:.8em 0}li>p{margin:.3em 0}ul,ol{padding-left:1.8em}blockquote{border-left:3px solid var(--border);margin:1em 0;padding:.1em 1em;color:var(--muted)}
        pre,code{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:.9em;background:var(--code);border-radius:5px}code{padding:.15em .35em}pre{padding:16px;overflow:auto;overflow-wrap:normal;line-height:1.6}pre code{padding:0;font-size:inherit}pre[data-language]::before{content:attr(data-language);display:block;font:11px -apple-system;color:var(--muted);margin-bottom:8px}
        .table-wrap{overflow-x:auto}table{border-collapse:collapse;margin:1em 0;min-width:50%}th,td{border:1px solid var(--border);padding:8px 14px;text-align:left}th{background:var(--code)}
        img{max-width:100%}a{color:#3985dc}hr{border:0;border-top:1px solid var(--border);margin:2em 0}input{margin-right:8px}
        </style></head><body><main>\(render(document))</main></body></html>
        """
    }
}
