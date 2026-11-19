import AppKit
import SwiftUI

struct UserGuideContent {
    static var markdown: String {
        guard let url = Bundle.module.url(forResource: "UserGuide", withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return "# ApexText User Guide\n\nThe bundled guide could not be loaded."
        }
        return text
    }
}

@MainActor final class UserGuideController {
    static let shared = UserGuideController()
    private var controller: NSWindowController?
    func show(shortcuts: Bool = false) {
        let content = UserGuideContent.markdown
        let initialLine = shortcuts ? MarkdownRenderer(source: content).headings.first(where: { $0.text == "Keyboard shortcut reference" })?.id : nil
        if let controller {
            controller.window?.contentView = NSHostingView(rootView: UserGuideView(source: content, selectedLine: initialLine))
            controller.showWindow(nil)
            controller.window?.makeKeyAndOrderFront(nil)
            return
        }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1050, height: 740), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "ApexText User Guide"
        window.minSize = NSSize(width: 760, height: 500)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: UserGuideView(source: content, selectedLine: initialLine))
        window.center()
        let controller = NSWindowController(window: window)
        self.controller = controller
        controller.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
    }
}

private struct UserGuideView: View {
    let source: String
    @State var selectedLine: Int?
    @State private var jumpID = UUID()
    @State private var query = ""
    private var topics: [OutlineEntry] {
        let headings = MarkdownRenderer(source: source).headings.filter { $0.level == 2 }
        let lines = source.components(separatedBy: "\n")
        return headings.enumerated().compactMap { index, heading in
            let end = index + 1 < headings.count ? headings[index + 1].id : lines.count
            let section = lines[heading.id..<end].joined(separator: "\n")
            return query.isEmpty || section.localizedCaseInsensitiveContains(query) ? heading : nil
        }
    }
    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 12) {
                Text("User Guide").font(.title2.bold())
                Text("ApexText · ApexVoid").font(.caption).foregroundStyle(.secondary)
                TextField("Search topics", text: $query).textFieldStyle(.roundedBorder)
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(topics) { topic in
                            Button { selectedLine = topic.id; jumpID = UUID() } label: {
                                Text(topic.text).font(.callout).multilineTextAlignment(.leading)
                                    .padding(7).frame(maxWidth: .infinity, alignment: .leading)
                                    .background(selectedLine == topic.id ? Color.accentColor.opacity(0.15) : .clear).cornerRadius(5)
                            }.buttonStyle(.plain)
                        }
                        if topics.isEmpty { Text("No matching topics").foregroundStyle(.secondary) }
                    }
                }
            }.padding(16).frame(minWidth: 220, idealWidth: 260, maxWidth: 320)
            MarkdownPreview(source: source, selectedLine: selectedLine, jumpID: jumpID).frame(minWidth: 400)
        }.frame(minWidth: 760, minHeight: 500)
    }
}
