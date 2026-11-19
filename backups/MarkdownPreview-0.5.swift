import SwiftUI
import WebKit

struct MarkdownPreview: NSViewRepresentable {
    let source: String
    let selectedLine: Int?
    let jumpID: UUID
    var fontName: String = ""
    var fontSize: CGFloat = 16
    var readingPosition: ReadingPosition? = nil
    var onEdit: ((String) -> Void)? = nil
    static var inlineScript: String { (try? String(contentsOf: Bundle.module.url(forResource: "InlineEditor", withExtension: "js")!, encoding: .utf8)) ?? "" }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        if onEdit != nil {
            let script = Self.inlineScript
            configuration.userContentController.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
            configuration.userContentController.add(context.coordinator, name: "editMarkdown")
            configuration.userContentController.add(context.coordinator, name: "commitMarkdown")
            configuration.userContentController.add(context.coordinator, name: "historyMarkdown")
            configuration.userContentController.add(context.coordinator, name: "selectionMenu")
        }
        let view = MarkdownWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        readingPosition?.webView = view
        context.coordinator.readingPosition = readingPosition
        return view
    }
    func updateNSView(_ view: WKWebView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onEdit = onEdit
        coordinator.view = view
        coordinator.line = selectedLine
        if coordinator.source != source || coordinator.fontName != fontName || coordinator.fontSize != fontSize {
            coordinator.fontName = fontName
            coordinator.fontSize = fontSize
            coordinator.source = source
            coordinator.ready = false
            coordinator.jumpID = jumpID
            coordinator.load(view)
        } else if coordinator.jumpID != jumpID {
            coordinator.jumpID = jumpID
            coordinator.scroll(view)
        }
    }
    static func dismantleNSView(_ view: WKWebView, coordinator: Coordinator) {
        for name in ["editMarkdown", "commitMarkdown", "historyMarkdown", "selectionMenu"] { view.configuration.userContentController.removeScriptMessageHandler(forName: name) }
    }
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var onEdit: ((String) -> Void)?
        weak var view: WKWebView?
        var scrollAfterCommit: Double?
        var nextBlock: Int?
        var undoSources: [String] = []
        var redoSources: [String] = []
        var editStart: String?
        var contextBlock = 0
        @objc private func setHeading(_ item: NSMenuItem) {
            view?.evaluateJavaScript("window.apexTextInline.applyHeading(\(item.tag), \(contextBlock))", completionHandler: nil)
        }
        @objc private func chooseFont(_ item: NSMenuItem) { FontPreferences.shared.showPanel() }
        private func showSelectionMenu(_ body: [String: Any], in view: WKWebView) {
            guard let index = body["index"] as? Int, let x = body["x"] as? Double, let y = body["y"] as? Double else { return }
            contextBlock = index
            let menu = NSMenu()
            for level in 0...6 {
                let item = NSMenuItem(title: level == 0 ? "Paragraph" : "Heading \(level)", action: #selector(setHeading(_:)), keyEquivalent: "")
                item.tag = level; item.target = self
                if level <= 3 { item.keyEquivalent = String(level); item.keyEquivalentModifierMask = [.command, .option] }
                menu.addItem(item)
            }
            menu.addItem(.separator())
            let font = NSMenuItem(title: "Font…", action: #selector(chooseFont(_:)), keyEquivalent: "")
            font.target = self; menu.addItem(font)
            menu.popUp(positioning: nil, at: NSPoint(x: x, y: view.isFlipped ? y : view.bounds.height - y), in: view)
        }
        func load(_ view: WKWebView) {
            ready = false
            let renderer = MarkdownRenderer(source: source ?? "", fontName: fontName, fontSize: fontSize)
            view.loadHTMLString(onEdit == nil ? renderer.html : renderer.editableHTML, baseURL: nil)
        }
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.frameInfo.isMainFrame, let body = message.body as? [String: Any], let view else { return }
            if message.name == "selectionMenu" { showSelectionMenu(body, in: view); return }
            if message.name == "historyMarkdown" {
                let redo = body["redo"] as? Bool == true
                if let start = editStart, start != source { undoSources.append(start); editStart = nil }
                let replacement = redo ? redoSources.popLast() : undoSources.popLast()
                guard let replacement else { return }
                if redo { undoSources.append(source ?? "") } else { redoSources.append(source ?? "") }
                source = replacement; onEdit?(replacement); load(view)
                return
            }
            guard let updated = body["source"] as? String else { return }
            if updated != source {
                if editStart == nil { editStart = source }
                source = updated
                onEdit?(updated)
            }
            if message.name == "commitMarkdown" {
                if let start = editStart, start != updated { undoSources.append(start); redoSources.removeAll() }
                editStart = nil
                scrollAfterCommit = body["scroll"] as? Double
                nextBlock = body["nextBlock"] as? Int
                load(view)
            }
        }
        var readingPosition: ReadingPosition?
        var source: String?
        var fontName = ""
        var fontSize: CGFloat = 16
        var line: Int?
        var jumpID: UUID?
        var ready = false
        func scroll(_ view: WKWebView) {
            guard ready, let line else { return }
            view.evaluateJavaScript("document.getElementById('line-\(line)')?.scrollIntoView({block:'start'})", completionHandler: nil)
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            ready = true
            if onEdit != nil {
                let renderer = MarkdownRenderer(source: source ?? "", fontName: fontName, fontSize: fontSize)
                Task { @MainActor [weak self, weak webView] in
                    guard let self, let webView else { return }
                    _ = try? await webView.callAsyncJavaScript("window.apexTextInline.setup(source, ranges)", arguments: ["source": self.source ?? "", "ranges": renderer.editableRanges], in: nil, contentWorld: .page)
                    self.restorePosition(webView)
                    if let block = self.nextBlock {
                        self.nextBlock = nil
                        _ = try? await webView.evaluateJavaScript("window.apexTextInline.activate(\(block))")
                    }
                }
            } else { restorePosition(webView) }
        }
        private func restorePosition(_ webView: WKWebView) {
            if let y = scrollAfterCommit {
                scrollAfterCommit = nil
                webView.evaluateJavaScript("window.scrollTo(0, \(y))", completionHandler: nil)
            } else if let position = readingPosition, position.restore {
                position.restore = false
                webView.evaluateJavaScript(ReadingPosition.restoreScript(position.line), completionHandler: nil)
            } else { scroll(webView) }
        }
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
            if action.navigationType == .linkActivated {
                if let url = action.request.url, ["http", "https", "mailto"].contains(url.scheme?.lowercased() ?? "") { NSWorkspace.shared.open(url) }
                decisionHandler(.cancel)
            } else { decisionHandler(.allow) }
        }
    }
}
