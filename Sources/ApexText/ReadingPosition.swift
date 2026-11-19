import AppKit
import WebKit

@MainActor final class ReadingPosition: ObservableObject {
    weak var textView: NSTextView?
    weak var webView: WKWebView?
    var line: Double = 0
    var switching = false
    var restore = false

    static let captureScript = """
    (() => {
      window.apexTextInline?.flush();
      const blocks = [...document.querySelectorAll('[data-edit-block][data-source-start]')];
          const nodes = blocks.length ? blocks : [...document.querySelectorAll('[data-source-start]')];
      let best = nodes.find(e => e.getBoundingClientRect().bottom > 0);
      if (!best) best = nodes[nodes.length - 1];
      if (!best) return 0;
      const r = best.getBoundingClientRect(), start = +best.dataset.sourceStart, end = +best.dataset.sourceEnd;
      return start + Math.max(0, Math.min(0.999, -r.top / Math.max(1, r.height))) * (end - start + 1);
    })()
    """
    static func restoreScript(_ line: Double) -> String {
        """
        (() => {
          const line = \(line);
          const blocks = [...document.querySelectorAll('[data-edit-block][data-source-start]')];
          const nodes = blocks.length ? blocks : [...document.querySelectorAll('[data-source-start]')];
          const e = nodes.find(e => +e.dataset.sourceStart <= line && +e.dataset.sourceEnd + 1 > line)
            || nodes.find(e => +e.dataset.sourceStart >= line) || nodes[nodes.length - 1];
          if (!e) return;
          const r = e.getBoundingClientRect();
          const fraction = Math.max(0, Math.min(1, (line - +e.dataset.sourceStart) / (+e.dataset.sourceEnd - +e.dataset.sourceStart + 1)));
          window.scrollTo(0, window.scrollY + r.top + r.height * fraction);
        })()
        """
    }
    func capture(preview: Bool, synchronize: ((String) -> Void)? = nil, completion: @escaping () -> Void) {
        guard !switching else { return }
        switching = true
        if preview {
            guard let webView, !webView.isLoading else { switching = false; return }
            let script = """
            (() => {
              if (window.apexTextInline && (window.apexTextInline.isComposing() || document.querySelector('main')?.dataset.editorReady !== 'true')) return {composing: true};
              const line = \(Self.captureScript);
              return {line, source: window.apexTextInline?.getSource() ?? null};
            })()
            """
            webView.evaluateJavaScript(script) { [weak self] value, error in
                guard let self else { return }
                guard error == nil, let result = value as? [String: Any], result["composing"] as? Bool != true,
                      let value = result["line"] as? Double, value.isFinite else {
                    self.switching = false
                    return
                }
                self.line = value
                if let source = result["source"] as? String { synchronize?(source) }
                self.restore = true
                self.switching = false
                completion()
            }
        } else {
            guard textView?.hasMarkedText() != true else { switching = false; return }
            if let view = textView { synchronize?(view.string) }
            if let view = textView, let layout = view.layoutManager, let container = view.textContainer {
                let top = view.visibleRect.minY - view.textContainerOrigin.y
                let glyph = layout.glyphIndex(for: NSPoint(x: 0, y: max(0, top)), in: container)
                if glyph < layout.numberOfGlyphs {
                    let character = layout.characterIndexForGlyph(at: glyph)
                    let text = view.string as NSString
                    let before = text.substring(to: min(character, text.length))
                    let number = before.filter { $0 == "\n" }.count
                    let range = text.lineRange(for: NSRange(location: min(character, text.length), length: 0))
                    let rect = layout.boundingRect(forGlyphRange: layout.glyphRange(forCharacterRange: range, actualCharacterRange: nil), in: container)
                    line = Double(number) + max(0, min(0.999, (top - rect.minY) / max(1, rect.height)))
                }
            }
            restore = true
            switching = false
            completion()
        }
    }
    func restoreEditor(_ view: NSTextView) {
        guard let layout = view.layoutManager, let container = view.textContainer, let scroll = view.enclosingScrollView else { return }
        layout.ensureLayout(for: container)
        let lines = view.string.components(separatedBy: "\n")
        let number = min(max(0, Int(line)), max(0, lines.count - 1))
        let offset = lines.prefix(number).reduce(0) { $0 + ($1 as NSString).length + 1 }
        let range = (view.string as NSString).lineRange(for: NSRange(location: min(offset, (view.string as NSString).length), length: 0))
        let rect = layout.boundingRect(forGlyphRange: layout.glyphRange(forCharacterRange: range, actualCharacterRange: nil), in: container)
        let y = max(0, rect.minY + view.textContainerOrigin.y + rect.height * (line - floor(line)))
        scroll.contentView.scroll(to: NSPoint(x: 0, y: y))
        scroll.reflectScrolledClipView(scroll.contentView)
    }
}
