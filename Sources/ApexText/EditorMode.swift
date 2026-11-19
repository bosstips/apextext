enum EditorMode: CaseIterable, Hashable {
    case preview, inline, source

    var next: Self {
        switch self {
        case .preview: .inline
        case .inline: .source
        case .source: .preview
        }
    }
    var title: String {
        switch self {
        case .preview: "Preview"
        case .inline: "Inline Edit"
        case .source: "Source Edit"
        }
    }
    var symbol: String {
        switch self {
        case .preview: "eye"
        case .inline: "pencil"
        case .source: "chevron.left.forwardslash.chevron.right"
        }
    }
}
