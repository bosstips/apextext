import AppKit
import SwiftUI

@MainActor final class FontPreferences: NSObject, ObservableObject {
    static let shared = FontPreferences()
    @Published private(set) var font: NSFont
    override init() {
        let name = UserDefaults.standard.string(forKey: "editorFontName") ?? ""
        let storedSize = UserDefaults.standard.double(forKey: "editorFontSize")
        let size = storedSize > 0 ? storedSize : 16
        font = NSFont(name: name, size: size) ?? .systemFont(ofSize: size)
        super.init()
    }
    func showPanel() {
        let manager = NSFontManager.shared
        manager.target = self
        manager.action = #selector(changeFont(_:))
        manager.setSelectedFont(font, isMultiple: false)
        manager.orderFrontFontPanel(nil)
    }
    @objc func changeFont(_ sender: NSFontManager) {
        font = sender.convert(font)
        UserDefaults.standard.set(font.fontName, forKey: "editorFontName")
        UserDefaults.standard.set(font.pointSize, forKey: "editorFontSize")
    }
}
