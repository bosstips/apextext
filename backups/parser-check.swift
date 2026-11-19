import Foundation
struct MarkdownBlock: Identifiable {
    let id: Int
    let text: String
    var level: Int = 0
    var code: Bool = false

    static func parse(_ source: String) -> [MarkdownBlock] {
        let lines = source.components(separatedBy: "\n")
        var result: [MarkdownBlock] = []
        var i = 0
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { i += 1; continue }
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                let marker = trimmed.first!
                let count = trimmed.prefix(while: { $0 == marker }).count
                let start = i
                i += 1
                var content: [String] = []
                while i < lines.count {
                    let candidate = lines[i].trimmingCharacters(in: .whitespaces)
                    if candidate.prefix(while: { $0 == marker }).count >= count && candidate.allSatisfy({ $0 == marker }) { break }
                    content.append(lines[i]); i += 1
                }
                result.append(.init(id: start, text: content.joined(separator: "\n"), code: true))
                i += 1; continue
            }
            let hashes = trimmed.prefix(while: { $0 == "#" }).count
            if (1...6).contains(hashes), trimmed.count == hashes || trimmed.dropFirst(hashes).first == " " || trimmed.dropFirst(hashes).first == "\t" {
                result.append(.init(id: i, text: String(trimmed.dropFirst(hashes)).trimmingCharacters(in: .whitespaces), level: hashes))
            } else if i + 1 < lines.count {
                let underline = lines[i + 1].trimmingCharacters(in: .whitespaces)
                if !underline.isEmpty && (underline.allSatisfy { $0 == "=" } || underline.allSatisfy { $0 == "-" }) {
                    result.append(.init(id: i, text: line, level: underline.first == "=" ? 1 : 2)); i += 1
                } else { result.append(.init(id: i, text: line)) }
            } else { result.append(.init(id: i, text: line)) }
            i += 1
        }
        return result
    }
}

let blocks = MarkdownBlock.parse("# Title\nBody\n### Small\n```md\n# Code\n```\nEnd")
assert(blocks.count == 5)
assert(blocks[0].text == "Title")
assert(blocks[1].level == 0)
assert(blocks[2].level == 3)
assert(blocks[3].code && blocks[3].text == "# Code")
assert(blocks.filter { $0.level > 0 }.map { $0.id } == [0, 2])
print("Parser regression checks passed")
