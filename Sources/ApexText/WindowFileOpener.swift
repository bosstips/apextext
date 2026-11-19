import AppKit

/// Uses the existing native document and window; canClose performs the native
/// save/discard/cancel flow before replacing its contents.
@MainActor final class WindowFileOpener: NSObject, ObservableObject {
    private var pending: (NSDocument, URL, (Result<Void, Error>) -> Void)?
    func open(_ url: URL, document suppliedDocument: NSDocument? = nil, completion: @escaping (Result<Void, Error>) -> Void) {
        guard pending == nil else { return }
        guard let document = suppliedDocument ?? (NSApp.keyWindow?.windowController?.document as? NSDocument) else {
            completion(.failure(NSError(domain: "ApexText", code: 1, userInfo: [NSLocalizedDescriptionKey: "The current document is not available."])))
            return
        }
        if document.fileURL?.standardizedFileURL == url.standardizedFileURL { completion(.success(())); return }
        do {
            let data = try Data(contentsOf: url)
            guard String(data: data, encoding: .utf8) != nil else { throw CocoaError(.fileReadInapplicableStringEncoding) }
        } catch { completion(.failure(error)); return }
        pending = (document, url, completion)
        document.canClose(withDelegate: self, shouldClose: #selector(ready(_:shouldClose:contextInfo:)), contextInfo: nil)
    }
    @objc private func ready(_ document: NSDocument, shouldClose: Bool, contextInfo: UnsafeMutableRawPointer?) {
        guard let request = pending else { return }
        pending = nil
        guard shouldClose else { return }
        do {
            try document.revert(toContentsOf: request.1, ofType: document.fileType ?? "public.plain-text")
            document.fileURL = request.1
            document.undoManager?.removeAllActions()
            document.updateChangeCount(.changeCleared)
            NSDocumentController.shared.noteNewRecentDocumentURL(request.1)
            request.2(.success(()))
        } catch { request.2(.failure(error)) }
    }
}
