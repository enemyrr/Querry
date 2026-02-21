import AppKit

@MainActor
enum MarkdownInlineRenderer {

    private static let boldItalicPattern = try! NSRegularExpression(pattern: #"\*{3}(.+?)\*{3}"#)
    private static let boldPattern = try! NSRegularExpression(pattern: #"\*{2}(.+?)\*{2}"#)
    private static let italicPattern = try! NSRegularExpression(pattern: #"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)"#)
    private static let strikethroughPattern = try! NSRegularExpression(pattern: #"~~(.+?)~~"#)
    private static let inlineCodePattern = try! NSRegularExpression(pattern: #"`([^`]+)`"#)
    private static let linkPattern = try! NSRegularExpression(pattern: #"\[([^\]]+)\]\(([^)]+)\)"#)

    static func render(
        _ text: String,
        font: NSFont = .systemFont(ofSize: NSFont.systemFontSize),
        color: NSColor = .labelColor
    ) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4

        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle,
        ]
        let result = NSMutableAttributedString(string: text, attributes: baseAttributes)
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)

        var matches: [InlineMatch] = []

        for match in linkPattern.matches(in: text, range: fullRange) {
            let linkText = nsText.substring(with: match.range(at: 1))
            let urlString = nsText.substring(with: match.range(at: 2))
            var attrs = baseAttributes
            attrs[.foregroundColor] = NSColor.controlAccentColor
            attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
            if let url = URL(string: urlString) { attrs[.link] = url }
            matches.append(InlineMatch(range: match.range, replacement: NSAttributedString(string: linkText, attributes: attrs)))
        }

        collectMatches(pattern: boldItalicPattern, in: text, nsText: nsText, fullRange: fullRange, baseAttributes: baseAttributes, overrides: [.font: boldItalicFont(size: font.pointSize)], into: &matches)
        collectMatches(pattern: boldPattern, in: text, nsText: nsText, fullRange: fullRange, baseAttributes: baseAttributes, overrides: [.font: NSFont.boldSystemFont(ofSize: font.pointSize)], into: &matches)
        collectMatches(pattern: italicPattern, in: text, nsText: nsText, fullRange: fullRange, baseAttributes: baseAttributes, overrides: [.font: makeItalicFont(from: font)], into: &matches)
        collectMatches(pattern: strikethroughPattern, in: text, nsText: nsText, fullRange: fullRange, baseAttributes: baseAttributes, overrides: [.strikethroughStyle: NSUnderlineStyle.single.rawValue], into: &matches)
        collectMatches(pattern: inlineCodePattern, in: text, nsText: nsText, fullRange: fullRange, baseAttributes: baseAttributes, overrides: [
            .font: NSFont.monospacedSystemFont(ofSize: font.pointSize - 1, weight: .regular),
            .foregroundColor: NSColor.systemPink,
            .backgroundColor: NSColor.quaternaryLabelColor,
        ], into: &matches)

        matches.sort(by: >)
        for m in matches {
            result.replaceCharacters(in: m.range, with: m.replacement)
        }

        return result
    }

    private static func collectMatches(
        pattern: NSRegularExpression,
        in text: String,
        nsText: NSString,
        fullRange: NSRange,
        baseAttributes: [NSAttributedString.Key: Any],
        overrides: [NSAttributedString.Key: Any],
        into matches: inout [InlineMatch]
    ) {
        for match in pattern.matches(in: text, range: fullRange) {
            guard !overlaps(match.range, with: matches) else { continue }
            let content = nsText.substring(with: match.range(at: 1))
            let attrs = baseAttributes.merging(overrides) { _, new in new }
            matches.append(InlineMatch(range: match.range, replacement: NSAttributedString(string: content, attributes: attrs)))
        }
    }

    private static func overlaps(_ range: NSRange, with existing: [InlineMatch]) -> Bool {
        existing.contains { NSIntersectionRange(range, $0.range).length > 0 }
    }

    private struct InlineMatch: Comparable {
        let range: NSRange
        let replacement: NSAttributedString
        static func < (lhs: InlineMatch, rhs: InlineMatch) -> Bool {
            lhs.range.location < rhs.range.location
        }
    }

    private static func makeItalicFont(from font: NSFont) -> NSFont {
        let descriptor = font.fontDescriptor.withSymbolicTraits(.italic)
        return NSFont(descriptor: descriptor, size: font.pointSize) ?? font
    }

    private static func boldItalicFont(size: CGFloat) -> NSFont {
        let descriptor = NSFont.systemFont(ofSize: size, weight: .bold)
            .fontDescriptor
            .withSymbolicTraits(.italic)
        return NSFont(descriptor: descriptor, size: size) ?? NSFont.boldSystemFont(ofSize: size)
    }
}

extension NSTextField {

    func configureForMarkdownDisplay() {
        isEditable = false
        isSelectable = true
        allowsEditingTextAttributes = true
        isBordered = false
        isBezeled = false
        drawsBackground = false
        lineBreakMode = .byCharWrapping
        maximumNumberOfLines = 0
        cell?.wraps = true
        cell?.isScrollable = false
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }
}
