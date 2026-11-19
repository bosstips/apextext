import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct MarkdownDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText, UTType(filenameExtension: "md") ?? .plainText] }
    var text: String = "# Welcome\n\nA quiet place for your ideas.\n\n## Start writing\n\nWrite with **Markdown**.\n"
    init() {}
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents, let value = String(data: data, encoding: .utf8) else { throw CocoaError(.fileReadInapplicableStringEncoding) }
        text = value
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: Data(text.utf8)) }
}

@main struct ApexTextApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: MarkdownDocument()) { file in Editor(document: file.$document, fileURL: file.fileURL) }
            .commands {
                CommandGroup(after: .textEditing) {
                    Button("Find and Replace") { NSApp.sendAction(#selector(NSTextView.performFindPanelAction(_:)), to: nil, from: FindSender()) }.keyboardShortcut("f")
                }
                CommandGroup(replacing: .help) {
                    Button("ApexText User Guide") { UserGuideController.shared.show() }
                    Button("Keyboard Shortcuts") { UserGuideController.shared.show(shortcuts: true) }
                }
                CommandGroup(replacing: .appInfo) {
                    Button("About ApexText") {
                        NSApp.orderFrontStandardAboutPanel(options: [
                            .applicationName: "ApexText",
                            .credits: NSAttributedString(string: "Author: ApexVoid")
                        ])
                    }
                }
                CommandGroup(after: .toolbar) {
                    Divider()
                    Button("Font…") { FontPreferences.shared.showPanel() }
                }
            }
    }
}
final class FindSender: NSObject { @objc var tag: Int { 1 } }

struct Editor: View {
    @Binding var document: MarkdownDocument
    var fileURL: URL?
    @StateObject private var readingPosition = ReadingPosition()
    @StateObject private var fileOpener = WindowFileOpener()
    @ObservedObject private var fonts = FontPreferences.shared
    @State private var sidebar = "Outline"
    @State private var folder: URL?
    @State private var openError: String?
    @State private var mode = EditorMode.preview
    @State private var focus = false
    @State private var selectedLine: Int? = nil
    @State private var jumpID = UUID()
    private func openInCurrentWindow(_ url: URL, preserveFolder: Bool) {
        fileOpener.open(url) { result in
            switch result {
            case .success:
                if !preserveFolder { folder = nil; sidebar = "Outline"; focus = false }
                selectedLine = nil
                readingPosition.line = 0
                readingPosition.restore = true
                jumpID = UUID()
            case .failure(let error): openError = error.localizedDescription
            }
        }
    }
    private var headings: [OutlineEntry] { MarkdownRenderer(source: document.text).headings }
    private var sidebarMenu: some View {
                    Menu {
                        Button { sidebar = "Outline"; focus = false } label: {
                            Label("Outline", systemImage: sidebar == "Outline" ? "checkmark" : "list.bullet.indent")
                        }
                        Button { sidebar = "Folder"; focus = false } label: {
                            Label("Folder", systemImage: sidebar == "Folder" ? "checkmark" : "folder")
                        }
                        Divider()
                        Button("Open File") {
                            let panel = NSOpenPanel()
                            panel.title = "Open File"
                            panel.prompt = "Open"
                            panel.canChooseDirectories = false
                            panel.canChooseFiles = true
                            panel.allowsMultipleSelection = false
                            panel.allowedContentTypes = MarkdownDocument.readableContentTypes
                            if panel.runModal() == .OK, let url = panel.url {
                                openInCurrentWindow(url, preserveFolder: false)
                            }
                        }
                        Button("Open Folder") {
                            let panel = NSOpenPanel()
                            panel.title = "Open Folder"
                            panel.prompt = "Open"
                            panel.canChooseDirectories = true
                            panel.canChooseFiles = false
                            panel.allowsMultipleSelection = false
                            if panel.runModal() == .OK { folder = panel.url; sidebar = "Folder"; focus = false }
                        }
                        Divider()
                        Button(focus ? "Show Sidebar" : "Hide Sidebar") { focus.toggle() }
                            .keyboardShortcut("\\", modifiers: .command)
                        Divider()
                        Button("Quit ApexText") { NSApp.terminate(nil) }
                    } label: {
                        Label(folder == nil ? "File" : "Open Folder", systemImage: folder == nil ? "doc.text" : "folder")
                            
                    }
                    .menuStyle(.borderlessButton)
                    .help("Sidebar")
    }
    var body: some View {
        HSplitView {
            if !focus {
                VStack(alignment: .leading, spacing: 16) {
                    if sidebar == "Folder" {
                        FileSidebar(folder: $folder, currentFile: fileURL, openFile: { openInCurrentWindow($0, preserveFolder: true) })
                    } else {
                    Text("Outline").font(.caption).foregroundStyle(.secondary)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(headings) { item in
                                Button { selectedLine = item.id; jumpID = UUID() } label: {
                                    Text(item.text).font(.callout).lineLimit(2)
                                        .padding(.leading, CGFloat(item.level - 1) * 10)
                                        .padding(6).frame(maxWidth: .infinity, alignment: .leading)
                                        .background(selectedLine == item.id ? Color.accentColor.opacity(0.15) : Color.clear)
                                        .cornerRadius(5)
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                    }
                }.padding(12).frame(minWidth: 190, idealWidth: 240, maxWidth: 340).background(.bar)
            }
            if mode != .source {
                MarkdownPreview(source: document.text, selectedLine: selectedLine, jumpID: jumpID, fontName: fonts.font.fontName, fontSize: fonts.font.pointSize, readingPosition: readingPosition, onEdit: mode == .inline ? { document.text = $0 } : nil).id(mode).frame(minWidth: 400)
            } else {
                NativeEditor(text: $document.text, selectedLine: selectedLine, jumpID: jumpID, font: fonts.font, readingPosition: readingPosition).frame(minWidth: 400)
            }
        }
        .frame(minWidth: 760, minHeight: 520)
        .alert("Unable to Open File", isPresented: Binding(get: { openError != nil }, set: { if !$0 { openError = nil } })) {
            Button("OK") { openError = nil }
        } message: { Text(openError ?? "") }
        .toolbar {
            ToolbarItem(placement: .navigation) { sidebarMenu }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    readingPosition.capture(preview: mode != .source, synchronize: { document.text = $0 }) { mode = mode.next }
                } label: {
                    Image(systemName: mode.next.symbol)
                        .frame(width: 22, height: 22)
                }
                .help("Switch to " + mode.next.title)
                .accessibilityLabel("Switch to " + mode.next.title)
                .accessibilityValue(mode.title)
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack { Text("Markdown · UTF-8"); Spacer(); Text("\(document.text.count) characters   \(document.text.components(separatedBy: "\n").count) lines") }.font(.caption).foregroundStyle(.secondary).padding(.horizontal, 18).padding(.vertical, 8).background(.bar)
        }
    }
}

struct NativeEditor: NSViewRepresentable {
    @Binding var text: String
    var selectedLine: Int?
    var jumpID: UUID
    var font: NSFont
    var readingPosition: ReadingPosition
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = MarkdownTextView.scrollableTextView()
        let view = scroll.documentView as! NSTextView
        view.isRichText = false
        view.font = font
        view.textContainerInset = NSSize(width: 24, height: 28)
        view.isAutomaticQuoteSubstitutionEnabled = false
        view.isAutomaticDashSubstitutionEnabled = false
        view.allowsUndo = true
        view.usesFindBar = true
        view.isIncrementalSearchingEnabled = true
        view.delegate = context.coordinator
        view.string = text
        readingPosition.textView = view
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        let view = scroll.documentView as! NSTextView
        if view.font != font { view.font = font }
        if view.string != text && !view.hasMarkedText() { view.string = text }
        if readingPosition.restore {
            readingPosition.restore = false
            context.coordinator.lastJump = jumpID
            DispatchQueue.main.async { readingPosition.restoreEditor(view) }
        } else if context.coordinator.lastJump != jumpID, let selectedLine {
            context.coordinator.lastJump = jumpID
            let lines = text.components(separatedBy: "\n")
            let offset = lines.prefix(max(0, selectedLine)).reduce(0) { $0 + ($1 as NSString).length + 1 }
            let range = NSRange(location: min(offset, (text as NSString).length), length: 0)
            view.setSelectedRange(range)
            view.scrollRangeToVisible(range)
        }
    }
    final class Coordinator: NSObject, NSTextViewDelegate {
        var lastJump: UUID?
        var parent: NativeEditor
        init(_ parent: NativeEditor) { self.parent = parent }
        func textDidChange(_ notification: Notification) { guard let view = notification.object as? NSTextView else { return }; parent.text = view.string }
    }
}

extension Notification.Name {
    static let apexTextOpenFile = Notification.Name("ApexText.openFile")
}
