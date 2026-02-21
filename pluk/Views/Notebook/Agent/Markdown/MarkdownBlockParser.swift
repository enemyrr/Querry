import Foundation

struct ListItem: Equatable {
    let text: String
    let isTask: Bool
    let isChecked: Bool
}

enum MarkdownBlock: Equatable {
    case paragraph(String)
    case heading(level: Int, text: String)
    case codeBlock(code: String, language: String)
    case unorderedList(items: [ListItem])
    case orderedList(items: [ListItem])
    case blockquote(String)
    case table(headers: [String], rows: [[String]])
    case horizontalRule
    case thinkingBlock(String)
}

@MainActor
enum MarkdownBlockParser {

    private enum State {
        case idle
        case inCodeBlock(language: String, lines: [String])
        case inThinkingBlock(lines: [String])
    }

    static func parse(_ text: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var state = State.idle
        var paragraphBuffer: [String] = []
        var listBuffer: [ListItem] = []
        var listIsOrdered = false
        var tableHeaders: [String] = []
        var tableRows: [[String]] = []
        var inTable = false

        func flushParagraph() {
            guard !paragraphBuffer.isEmpty else { return }
            blocks.append(.paragraph(paragraphBuffer.joined(separator: "\n")))
            paragraphBuffer.removeAll()
        }

        func flushList() {
            guard !listBuffer.isEmpty else { return }
            blocks.append(listIsOrdered ? .orderedList(items: listBuffer) : .unorderedList(items: listBuffer))
            listBuffer.removeAll()
        }

        func flushTable() {
            guard inTable else { return }
            blocks.append(.table(headers: tableHeaders, rows: tableRows))
            tableHeaders = []
            tableRows = []
            inTable = false
        }

        func flushAll() {
            flushParagraph()
            flushList()
            flushTable()
        }

        let lines = text.components(separatedBy: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            switch state {
            case .idle:
                if trimmed.hasPrefix("```") {
                    flushAll()
                    let lang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    state = .inCodeBlock(language: lang, lines: [])
                    continue
                }

                if trimmed == "<thinking>" {
                    flushAll()
                    state = .inThinkingBlock(lines: [])
                    continue
                }

                if trimmed.isEmpty {
                    flushAll()
                    continue
                }

                if let heading = parseHeading(trimmed) {
                    flushAll()
                    blocks.append(heading)
                    continue
                }

                if isHorizontalRule(trimmed) {
                    flushAll()
                    blocks.append(.horizontalRule)
                    continue
                }

                if trimmed.hasPrefix(">") {
                    flushAll()
                    let content = trimmed.hasPrefix("> ") ? String(trimmed.dropFirst(2)) : String(trimmed.dropFirst(1))
                    blocks.append(.blockquote(content))
                    continue
                }

                if trimmed.hasPrefix("|") && trimmed.hasSuffix("|") {
                    flushParagraph()
                    flushList()
                    let cells = parseTableRow(trimmed)
                    if !inTable {
                        tableHeaders = cells
                        inTable = true
                    } else if isSeparatorRow(trimmed) {
                        // skip
                    } else {
                        tableRows.append(cells)
                    }
                    continue
                } else if inTable {
                    flushTable()
                }

                if let taskItem = parseTaskListItem(trimmed) {
                    flushParagraph()
                    flushTable()
                    if !listBuffer.isEmpty && listIsOrdered {
                        let last = listBuffer.removeLast()
                        let checkbox = taskItem.isChecked ? "\u{2611} " : "\u{2610} "
                        let newText = last.text.isEmpty ? checkbox + taskItem.text : last.text + "\n" + checkbox + taskItem.text
                        listBuffer.append(ListItem(text: newText, isTask: last.isTask, isChecked: last.isChecked))
                        continue
                    }
                    listIsOrdered = false
                    listBuffer.append(taskItem)
                    continue
                }

                if let ulText = parseUnorderedListItem(trimmed) {
                    flushParagraph()
                    flushTable()
                    if !listBuffer.isEmpty && listIsOrdered {
                        let last = listBuffer.removeLast()
                        let newText = last.text.isEmpty ? "\u{2022} " + ulText : last.text + "\n\u{2022} " + ulText
                        listBuffer.append(ListItem(text: newText, isTask: last.isTask, isChecked: last.isChecked))
                        continue
                    }
                    listIsOrdered = false
                    listBuffer.append(ListItem(text: ulText, isTask: false, isChecked: false))
                    continue
                }

                if let olText = parseOrderedListItem(trimmed) {
                    flushParagraph()
                    flushTable()
                    if !listBuffer.isEmpty && !listIsOrdered { flushList() }
                    listIsOrdered = true
                    listBuffer.append(ListItem(text: olText, isTask: false, isChecked: false))
                    continue
                }

                if !listBuffer.isEmpty {
                    let last = listBuffer.removeLast()
                    let newText = last.text.isEmpty ? trimmed : last.text + "\n" + trimmed
                    listBuffer.append(ListItem(text: newText, isTask: last.isTask, isChecked: last.isChecked))
                    continue
                }

                flushList()
                flushTable()
                paragraphBuffer.append(trimmed)

            case .inCodeBlock(let language, var codeLines):
                if trimmed.hasPrefix("```") {
                    blocks.append(.codeBlock(code: codeLines.joined(separator: "\n"), language: language))
                    state = .idle
                } else {
                    codeLines.append(line)
                    state = .inCodeBlock(language: language, lines: codeLines)
                }

            case .inThinkingBlock(var thinkingLines):
                if trimmed == "</thinking>" {
                    blocks.append(.thinkingBlock(thinkingLines.joined(separator: "\n")))
                    state = .idle
                } else {
                    thinkingLines.append(line)
                    state = .inThinkingBlock(lines: thinkingLines)
                }
            }
        }

        switch state {
        case .idle:
            flushAll()
        case .inCodeBlock(let language, let codeLines):
            blocks.append(.codeBlock(code: codeLines.joined(separator: "\n"), language: language))
        case .inThinkingBlock(let thinkingLines):
            blocks.append(.thinkingBlock(thinkingLines.joined(separator: "\n")))
        }

        return blocks
    }

    // MARK: - Line Parsers

    private static func parseHeading(_ trimmed: String) -> MarkdownBlock? {
        guard trimmed.hasPrefix("#") else { return nil }
        if trimmed.hasPrefix("### ") { return .heading(level: 3, text: String(trimmed.dropFirst(4))) }
        if trimmed.hasPrefix("## ") { return .heading(level: 2, text: String(trimmed.dropFirst(3))) }
        if trimmed.hasPrefix("# ") { return .heading(level: 1, text: String(trimmed.dropFirst(2))) }
        return nil
    }

    private static func isHorizontalRule(_ trimmed: String) -> Bool {
        let cleaned = trimmed.replacing(" ", with: "")
        guard cleaned.count >= 3 else { return false }
        return cleaned.allSatisfy({ $0 == "-" }) ||
               cleaned.allSatisfy({ $0 == "*" }) ||
               cleaned.allSatisfy({ $0 == "_" })
    }

    private static func parseTaskListItem(_ trimmed: String) -> ListItem? {
        if trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ") {
            return ListItem(text: String(trimmed.dropFirst(6)), isTask: true, isChecked: true)
        }
        if trimmed.hasPrefix("- [ ] ") {
            return ListItem(text: String(trimmed.dropFirst(6)), isTask: true, isChecked: false)
        }
        return nil
    }

    private static func parseUnorderedListItem(_ trimmed: String) -> String? {
        for prefix in ["- ", "* ", "+ "] {
            if trimmed.hasPrefix(prefix) {
                return String(trimmed.dropFirst(prefix.count))
            }
        }
        return nil
    }

    private static func parseOrderedListItem(_ trimmed: String) -> String? {
        guard let dotIndex = trimmed.firstIndex(of: ".") ?? trimmed.firstIndex(of: ")") else { return nil }
        let numberPart = trimmed[trimmed.startIndex..<dotIndex]
        guard !numberPart.isEmpty, numberPart.allSatisfy(\.isNumber) else { return nil }
        let afterDot = trimmed.index(after: dotIndex)
        guard afterDot < trimmed.endIndex else { return "" }
        guard trimmed[afterDot] == " " else { return nil }
        return String(trimmed[trimmed.index(after: afterDot)...])
    }

    private static func parseTableRow(_ trimmed: String) -> [String] {
        var row = trimmed
        if row.hasPrefix("|") { row = String(row.dropFirst()) }
        if row.hasSuffix("|") { row = String(row.dropLast()) }
        return row.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func isSeparatorRow(_ trimmed: String) -> Bool {
        var row = trimmed
        if row.hasPrefix("|") { row = String(row.dropFirst()) }
        if row.hasSuffix("|") { row = String(row.dropLast()) }
        return row.components(separatedBy: "|").allSatisfy { cell in
            cell.trimmingCharacters(in: .whitespaces).replacing("-", with: "").replacing(":", with: "").isEmpty
        }
    }
}
