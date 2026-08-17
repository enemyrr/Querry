import Foundation

/// A custom logger that only prints in DEBUG builds.
///
/// This function mimics the behavior of Swift's `print()` function but is conditionally
/// compiled to be included only in DEBUG builds. In release builds, calls to this
/// function are compiled out, having no effect on performance.
///
/// - Parameters:
///   - items: Zero or more items to print.
///   - separator: A string to print between each item. The default is a single space (" ").
///   - terminator: The string to print after all items have been printed. The default is a newline ("\n").
public func debugLog(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    #if DEBUG
    let output = items.map { "\($0)" }.joined(separator: separator)
    Swift.print(output, terminator: terminator)
    #endif
}
