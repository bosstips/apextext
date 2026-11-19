import SwiftUI
import AppKit

struct FileSidebar: View {
    @Binding var folder: URL?
    let currentFile: URL?
    var openFile: (URL) -> Void = { _ in }
    @State private var generation = UUID()
    private var root: URL? { folder ?? currentFile?.deletingLastPathComponent() }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(root?.lastPathComponent ?? "Local Folder").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                Spacer()

            }.buttonStyle(.borderless)
            if let root {
                ScrollView {
                    FolderContents(url: root, currentFile: currentFile, openFile: openFile).id(generation)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ContentUnavailableView {
                    Label("No Folder Selected", systemImage: "folder")
                } actions: { Button("Open Folder", action: chooseFolder) }
            }
        }
    }
    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.title = "Open Folder"
        panel.prompt = "Open"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK { folder = panel.url; generation = UUID() }
    }
}

struct FolderContents: View {
    let url: URL
    let currentFile: URL?
    var openFile: (URL) -> Void = { _ in }
    @State private var entries: [URL] = []
    @State private var error: String?
    static func children(of url: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey], options: [.skipsHiddenFiles]).filter {
            let values = try? $0.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values?.isSymbolicLink != true else { return false }
            return values?.isDirectory == true || ["md", "markdown", "mdown", "txt"].contains($0.pathExtension.lowercased())
        }.sorted {
            let left = (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            let right = (try? $1.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            if left != right { return left }
            return $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if error != nil { Text("Unable to read this folder.").font(.caption).foregroundStyle(.secondary) }
            else if entries.isEmpty { Text("No Markdown files").font(.caption).foregroundStyle(.secondary) }
            ForEach(entries, id: \.self) { entry in
                FileTreeRow(url: entry, currentFile: currentFile, openFile: openFile)
            }
        }.task(id: url) {
            do { entries = try Self.children(of: url); error = nil }
            catch { self.error = error.localizedDescription }
        }
    }
}

struct FileTreeRow: View {
    let url: URL
    let currentFile: URL?
    var openFile: (URL) -> Void = { _ in }
    @State private var expanded = false
    @State private var openError: String?
    private var isDirectory: Bool { (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                if isDirectory { expanded.toggle() }
                else {
                    openFile(url)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isDirectory ? (expanded ? "chevron.down" : "chevron.right") : "doc.text").frame(width: 14)
                    Text(url.lastPathComponent).lineLimit(1).truncationMode(.middle)
                }.font(.callout).padding(.vertical, 5).padding(.horizontal, 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(currentFile == url ? Color.accentColor.opacity(0.15) : .clear).cornerRadius(5)
            }.buttonStyle(.plain).help(url.path)
            if isDirectory && expanded { FolderContents(url: url, currentFile: currentFile, openFile: openFile).padding(.leading, 14) }
        }.alert("Unable to Open File", isPresented: Binding(get: { openError != nil }, set: { if !$0 { openError = nil } })) {
            Button("OK") { openError = nil }
        } message: { Text(openError ?? "") }
    }
}
