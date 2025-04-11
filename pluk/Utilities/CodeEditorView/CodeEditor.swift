//
//  CodeEditor.swift
//
//  Created by Fauzaan on 23/08/2020.
//
//  SwiftUI 'CodeEditor' view

import Combine
import SwiftUI
import Rearrange
import LanguageSupport


// MARK: -
// MARK: Basic shared definition

/// SwiftUI code editor based on TextKit.
///
/// SwiftUI `Environment`:
/// * Environment value `codeEditorTheme`: determines the code highlighting theme to use
/// * Text-related values: affect the rendering of message views
///
public struct CodeEditor {

  /// Specification of a text editing position; i.e., text selection and scroll position.
  ///
  public struct Position: Equatable {

    /// Specification of a list of selection ranges.
    ///
    /// * A range with a zero length indicates an insertion point.
    /// * An empty array, corresponds to an insertion point at position 0.
    /// * On iOS, this can only always be one range.
    ///
    public var selections: [NSRange]

    /// The editor vertical scroll position.
    ///
    public var verticalScrollPosition: CGFloat

    public init(selections: [NSRange], verticalScrollPosition: CGFloat) {
      self.selections             = selections
      self.verticalScrollPosition = verticalScrollPosition
    }

    public init() {
      self.init(selections: [.zero], verticalScrollPosition: 0)
    }
  }

  let language:            LanguageConfiguration
  let breakUndoCoalescing: PassthroughSubject<(), Never>?

  @Binding private var text:     String
  @Binding private var position: Position
  @Binding private var messages: Set<TextLocated<Message>>

  @Environment(\.codeEditorLayoutConfiguration)      private var layoutConfiguration
  @Environment(\.codeEditorIndentationConfiguration) private var indentationConfiguration
  @Environment(\.codeEditorSetActions)               private var setActions
  @Environment(\.codeEditorSetInfo)                  private var setInfo

  // Values passed as parameters using the deprecated initialiser have got priority for backwards-campatibility.
  var definitiveLayout: LayoutConfiguration { return layoutConfiguration }
  var definitiveSetActions: SetActions { return setActions  }
  var definitiveSetInfo: SetInfo { return setInfo  }

  /// Creates a fully configured code editor.
  ///
  /// - Parameters:
  ///   - text: Binding to the edited text.
  ///   - position: Binding to the current edit position.
  ///   - messages: Binding to the messages reported at the appropriate lines of the edited text. NB: Messages
  ///               processing and display is relatively expensive. Hence, there should only be a limited number of
  ///               simultaneous messages and they shouldn't change too frequently.
  ///   - language: Language configuration for highlighting and similar.
  ///   - breakUndoCoalescing: Trigger indicating when to break undo coalescing to avoid coalescing undos across
  ///       saves.
  ///
  public init(text:                Binding<String>,
              position:            Binding<Position>,
              messages:            Binding<Set<TextLocated<Message>>>,
              language:            LanguageConfiguration = .none,
              breakUndoCoalescing: PassthroughSubject<(), Never>? = nil)
  {
    self._text               = text
    self._position           = position
    self._messages           = messages
    self.language            = language
    self.breakUndoCoalescing = breakUndoCoalescing
  }

  public class _Coordinator {
    @Binding fileprivate var text:     String
    @Binding fileprivate var position: Position

    fileprivate var setActions: SetActions
    fileprivate var setInfo:    SetInfo

    /// In order to avoid update cycles, where view code tries to update SwiftUI state variables (such as the view's
    /// bindings) during a SwiftUI view update, we use `updatingView` as a flag that indicates whether the view is
    /// being updated, and hence, whether state updates ought to be avoided or delayed.
    ///
    fileprivate var updatingView = false

    /// The current set of code actions, which, on setting, are immediately propagated to the context.
    ///
    fileprivate var actions: Actions = Actions() {
      didSet {
        setActions(actions)
      }
    }

    /// The current editor info, which, on setting, is immediately propagated to the context.
    ///
    fileprivate var info: Info = Info() {
      didSet {
        setInfo(info)
      }
    }

    init(text: Binding<String>,
         position: Binding<Position>,
         setAction: SetActions,
         setInfo: SetInfo)
    {
      self._text      = text
      self._position  = position
      self.setActions = setAction
      self.setInfo    = setInfo
    }
    
    /// Update the bindings and callbacks that parameterise the editor view to be able to update them during a view
    /// update.
    ///
    func updateBindings(text: Binding<String>,
                        position: Binding<Position>,
                        setAction: SetActions,
                        setInfo: SetInfo)
    {
      self._text      = text
      self._position  = position
      self.setActions = setAction
      self.setInfo    = setInfo
    }
  }
}


// MARK: Layout configuration

extension CodeEditor {

  /// Specification of the editor layout.
  ///
  public struct LayoutConfiguration: Equatable, RawRepresentable {

    /// Determines whether line of text may extend beyond the width of the text area or are getting wrapped.
    ///
    public var wrapText: Bool

    /// Controls whether the height should adjust dynamically based on content.
    public var dynamicHeight: Bool
      
    /// Creates a layout configuration.
    ///
    /// - Parameters:
    ///   - wrapText: Whether lines of text may extend beyond the width of the text area or are getting wrapped.
    ///
      public init(wrapText: Bool, dynamicHeight: Bool = false) {
      self.wrapText    = wrapText
      self.dynamicHeight = dynamicHeight
    }

    public static let standard = LayoutConfiguration(wrapText: true)

    // MARK: For 'RawRepresentable'

    public var rawValue: String { "\(wrapText ? "t" : "f")" }

    public init?(rawValue: String) {
      guard rawValue.count == 2
      else { return nil }

      self.wrapText    = rawValue[rawValue.index(after: rawValue.startIndex)] == "t"
        
        if rawValue.count > 2 {
            self.dynamicHeight = rawValue[rawValue.index(rawValue.startIndex, offsetBy: 2)] == "t"
        } else {
            self.dynamicHeight = false
        }
    }
  }
}

extension EnvironmentValues {
  @Entry public var codeEditorLayoutConfiguration: CodeEditor.LayoutConfiguration = .standard
}


// MARK: Indentation configuration

extension CodeEditor {

  public struct IndentationConfiguration: Equatable, RawRepresentable {

    public enum Preference: Equatable {
      case preferSpaces
      case preferTabs

      init (tag: String) {
        switch tag {
        case "s": self = .preferSpaces
        case "t": self = .preferTabs
        default:  self = .preferSpaces
        }
      }

      var tag: String {
        switch self {
        case .preferSpaces: return "s"
        case .preferTabs:   return "t"
        }
      }
    }

    public enum TabKey: Equatable {
      case identsInWhitespace
      case indentsAlways
      case insertsTab

      init(tag: String) {
        switch tag {
        case "w": self = .identsInWhitespace
        case "a": self = .indentsAlways
        case "t": self = .insertsTab
        default:  self = .identsInWhitespace
        }
      }

      var tag: String {
        switch self {
        case .identsInWhitespace: return "w"
        case .indentsAlways:      return "a"
        case .insertsTab:         return "t"
        }
      }
    }

    /// Prefer identation by tabs or spaces.
    ///
    public var preference: Preference
    
    /// Number of spaces for one tab character.
    ///
    public var tabWidth: Int
    
    /// Number of spaces to indent nested code.
    ///
    public var indentWidth: Int
    
    /// Specifies the behaviour of the tab key.
    ///
    public var tabKey: TabKey
    
    /// Whether to indent the cursor after moving to a new line on typing return.
    ///
    public var indentOnReturn: Bool

    public init (preference: Preference, tabWidth: Int, indentWidth: Int, tabKey: TabKey, indentOnReturn: Bool) {
      self.preference     = preference
      self.tabWidth       = tabWidth
      self.indentWidth    = indentWidth
      self.tabKey         = tabKey
      self.indentOnReturn = indentOnReturn
    }

    public static let standard = IndentationConfiguration(preference: .preferSpaces,
                                                          tabWidth: 2,
                                                          indentWidth: 2,
                                                          tabKey: .identsInWhitespace,
                                                          indentOnReturn: true)

    // MARK: For 'RawRepresentable'

    public var rawValue: String {
      "\(preference.tag),\(tabWidth),\(indentWidth),\(tabKey.tag),\(indentOnReturn ? "t" : "f")"
    }

    public init?(rawValue: String) {
      let pieces = rawValue.split(separator: ",")
      guard pieces.count == 5
      else { return nil }

      self.preference     = Preference(tag: String(pieces[0]))
      self.tabWidth       = Int(pieces[1]) ?? 2
      self.indentWidth    = Int(pieces[2]) ?? 2
      self.tabKey         = TabKey(tag: String(pieces[3]))
      self.indentOnReturn = pieces[4] == "t"
    }
  }
}

extension EnvironmentValues {
  @Entry public var codeEditorIndentationConfiguration: CodeEditor.IndentationConfiguration = .standard
}

// MARK: - Code actions

extension CodeEditor {

  /// Collects all currently available code actions.
  ///
  public struct Actions {

    public struct Language {

      /// The name of the language.
      ///
      public let name: String

      /// The extra actions currently available.
      ///
      public var extraActions: [ExtraAction] = []
    }

    /// Language-specific actions, if any.
    ///
    public var language: Language = Language(name: "Text")

    /// Display semantic information about the current selection.
    ///
    public var info: (() -> Void)?

    /// Display completions for the partial word in front of the selection.
    ///
    public var completions: (() -> Void)?
  }
}

extension CodeEditor {

  public struct SetActions {
    let setActions: (Actions) -> Void

    public static let ignore: SetActions = .init({ _ in })

    public init(_ setActions: @escaping (Actions) -> Void) {
      self.setActions = setActions
    }

    func callAsFunction(_ actions: Actions) {
      setActions(actions)
    }
  }
}

extension EnvironmentValues {
  @Entry public var codeEditorSetActions: CodeEditor.SetActions = .ignore
}


// MARK: Editor state information

extension CodeEditor {

  /// User-level info about the editor state.
  ///
  public struct Info {

    /// Summarises the current selection state.
    ///
    public enum SelectionSummary {

      /// The selection is an insertion point at the given line and columnn (1-based).
      ///
      case insertionPoint(Int, Int)

      /// Selection of one or more characters on a single line.
      ///
      case characters(Int)

      /// Continous selection spanning the given number of lines (one or more).
      ///
      case lines(Int)

      /// Selection coverering two or more separate ranges.
      ///
      case ranges(Int)

      // NB: Internal as `LineMap` is internal.
      init(selections: [NSRange], with lineMap: LineMap<LineInfo>) {
          if let range = selections.first,
           selections.count == 1,
           let line    = lineMap.lineOf(index: range.location),
           let oneLine = lineMap.lookup(line: line)
        {
          if range.length == 0 {
            self = .insertionPoint(line + 1, range.location - oneLine.range.location + 1)
          } else {

            let lastLine = lineMap.lineOf(index: range.upperBound) ?? lineMap.lines.count
            if line == lastLine {
              self = .characters(range.length)
            } else {
              self = .lines(lastLine - line + 1)
            }

          }
        } else if selections.count > 1 {
          self = .ranges(selections.count)
        } else {
          self = .insertionPoint(1, 1)
        }
      }
    }

    /// Name of the configured language.
    ///
    public var language: String

    /// A summary of the current selection.
    ///
    public var selectionSummary: SelectionSummary

    public init(language: String = "Text", selectionSummary: SelectionSummary = .insertionPoint(1, 1)) {
      self.language         = language
      self.selectionSummary = selectionSummary
    }
  }
}

extension CodeEditor {

  public struct SetInfo {
    let setInfo: (Info) -> Void

    public static let ignore: SetInfo = .init({ _ in })

    public init(_ setInfo: @escaping (Info) -> Void) {
      self.setInfo = setInfo
    }

    func callAsFunction(_ info: Info) {
      setInfo(info)
    }
  }
}

extension EnvironmentValues {

  @Entry public var codeEditorSetInfo: CodeEditor.SetInfo = .ignore
}

// MARK: -
// MARK: AppKit version

extension CodeEditor: NSViewRepresentable {

  public func makeNSView(context: Context) -> NSScrollView {

    // We pass this function down into `CodeStorageDelegate` to facilitate updates to the `text` binding. For details,
    // see [Note Propagating text changes into SwiftUI].
    func setText(_ text: String) {
      guard !context.coordinator.updatingView else { return }

      // NB: Don't use `self.text` here as the closure will capture it without an option to update it when the view
      //     gets updated with a new 'text' bdining.
      if context.coordinator.text != text { context.coordinator.text = text }
    }

    context.coordinator.updatingView = true
    defer {
      context.coordinator.updatingView = false
    }

    // Set up scroll view
    let scrollView = NSScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 40))
    scrollView.borderType          = .noBorder
    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalRuler  = false
    scrollView.autoresizingMask    = [.width, .height]
      
      
    // Set up text view with gutter
    let codeView = CodeView(frame: CGRect(x: 0, y: 0, width: 100, height: 40),
                            with: language,
                            viewLayout: definitiveLayout,
                            indentation: indentationConfiguration,
                            theme: context.environment.codeEditorTheme,
                            setText: setText(_:),
                            setMessages: { messages = $0 })
    codeView.isVerticallyResizable   = true
    codeView.isHorizontallyResizable = false
    codeView.autoresizingMask        = .width
      
    context.coordinator.info.language = language.name

    scrollView.drawsBackground = false
    scrollView.contentView.drawsBackground = false
      
    scrollView.contentInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
 
    // Embed text view in scroll view
    scrollView.documentView = codeView

    // NB: We are not setting `codeView.text` here. That will happen via `updateNSView(:)`.
    // This implies that we must take care to not report that initial updates as a change to any connected language
    // service.
    if let codeStorageDelegate = codeView.optCodeStorage?.delegate as? CodeStorageDelegate {
      codeStorageDelegate.skipNextChangeNotificationToLanguageService = true
    }

    if let delegate = codeView.delegate as? CodeViewDelegate {

      // The property `delegate.textDidChange` is expected to alreayd have been set during initialisation of the
      // `CodeView`. Hence, we add to it; instead of just overwriting it.
      let currentTextDidChange = delegate.textDidChange
      delegate.textDidChange = { [currentTextDidChange] textView in
        context.coordinator.textDidChange(textView)
        currentTextDidChange?(textView)
      }
      delegate.selectionDidChange = { textView in
        selectionDidChange(textView)
        context.coordinator.selectionDidChange(textView)
      }

    }
    codeView.selectedRanges = position.selections.map{ NSValue(range: $0) }
    if let codeStorageDelegate = codeView.optCodeStorage?.delegate as? CodeStorageDelegate
    {
      context.coordinator.info.selectionSummary = Info.SelectionSummary(selections: position.selections,
                                                                        with: codeStorageDelegate.lineMap)
    }

    scrollView.verticalScrollPosition = position.verticalScrollPosition

    // The minimap needs to be vertically positioned in dependence on the scroll position of the main code view by
    // observing the bounds of the content view.
    context.coordinator.boundsChangedNotificationObserver
      = NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification,
                                               object: scrollView.contentView,
                                               queue: .main){ [weak scrollView] _ in

          // FIXME: we would like to get less fine-grained updates here, but `NSScrollView.didEndLiveScrollNotification` doesn't happen when moving the cursor around
          if let scrollView {
            context.coordinator.scrollPositionDidChange(scrollView)
          }
        }

    // Report the initial message set
    Task { @MainActor in codeView.update(messages: messages) }

    // Break undo coalescing whenever we get a trigger over the corresponding subject.
    context.coordinator.breakUndoCoalescingCancellable = breakUndoCoalescing?.sink { [weak codeView] _ in
      codeView?.breakUndoCoalescing()
    }

    // Set the initial actions
    //
    // NB: It is important that the actions don't capture the code view strongly.
    context.coordinator.actions = Actions(language: Actions.Language(name: language.name),
                                          info: { [weak codeView] in codeView?.infoAction() },
                                          completions: { [weak codeView] in codeView?.completionAction() })

    let coordinator = context.coordinator
    if let extraActions = codeView.optLanguageService?.extraActions.value {
      coordinator.actions.language.extraActions = extraActions
    }
    coordinator.extraActionsCancellable = language.languageService?.extraActions
      .receive(on: DispatchQueue.main)
      .sink { [coordinator] actions in

        coordinator.actions.language.extraActions = actions
      }

    return scrollView
  }

  public func updateNSView(_ scrollView: NSScrollView, context: Context) {
    guard let codeView = scrollView.documentView as? CodeView else { return }
    context.coordinator.updatingView = true
    defer {
      context.coordinator.updatingView = false
    }

    codeView.breakUndoCoalescing()

    let theme      = context.environment.codeEditorTheme,
        selections = position.selections.map{ NSValue(range: $0) }

    context.coordinator.updateBindings(text: $text,
                                       position: $position,
                                       setAction: definitiveSetActions,
                                       setInfo: definitiveSetInfo)
    if codeView.lastMessages != messages { codeView.update(messages: messages) }
    if text != codeView.string {  // Hoping for the string comparison fast path...

      if language.languageService !== codeView.language.languageService {
        (codeView.optCodeStorage?.delegate as? CodeStorageDelegate)?.skipNextChangeNotificationToLanguageService = true
      }
      codeView.string = text
      // FIXME: Stupid hack to force redrawing when the language doesn't change. (A language change already forces
      // FIXME: redrawing.)
      if language == codeView.language {
        Task { @MainActor in
          codeView.font = theme.font
        }
      }

    }
    if selections != codeView.selectedRanges {
      codeView.selectedRanges = selections
      if let codeStorageDelegate = codeView.optCodeStorage?.delegate as? CodeStorageDelegate
      {
        context.coordinator.info.selectionSummary = Info.SelectionSummary(selections: position.selections,
                                                                          with: codeStorageDelegate.lineMap)
      }
    }
      
    // Only apply dynamic height adjustment if requested through the layout configuration
    if definitiveLayout.dynamicHeight {
        if let codeStorageDelegate = codeView.optCodeStorage?.delegate as? CodeStorageDelegate {
            let lineCount = codeStorageDelegate.lineMap.lines.count
            let lineHeight = codeView.font?.lineHeight ?? 14
            
            let calculatedHeight = CGFloat(lineCount) * lineHeight
            let minHeight: CGFloat = 100
            let finalHeight = max(calculatedHeight, minHeight)
            // Find and update the existing height constraint
            if let heightConstraint = scrollView.constraints.first(where: {
                $0.firstAttribute == .height &&
                $0.secondItem == nil
            }) {
                // Update existing constraint
                heightConstraint.constant = finalHeight
            } else {
                // Create new constraint if none exists
                scrollView.translatesAutoresizingMaskIntoConstraints = false
                let heightConstraint = NSLayoutConstraint(
                    item: scrollView,
                    attribute: .height,
                    relatedBy: .equal,
                    toItem: nil,
                    attribute: .notAnAttribute,
                    multiplier: 1,
                    constant: finalHeight
                )
                heightConstraint.isActive = true
            }
        }
    }
      
    if abs(position.verticalScrollPosition - scrollView.verticalScrollPosition) > 0.0001 {
      scrollView.verticalScrollPosition = position.verticalScrollPosition
    }
    if theme.id != codeView.theme.id { codeView.theme = theme }
    if definitiveLayout != codeView.viewLayout { codeView.viewLayout = definitiveLayout }
    if indentationConfiguration != codeView.indentation { codeView.indentation = indentationConfiguration }
    // Equality on language configurations implies the same name and the same language service.
    if language != codeView.language {

      let languageServiceChanged = language.languageService !== codeView.language.languageService
      codeView.language                 = language
      context.coordinator.info.language = language.name

      if languageServiceChanged {

        let coordinator = context.coordinator
        if let extraActions = codeView.optLanguageService?.extraActions.value {
          coordinator.actions.language.extraActions = extraActions
        }
        coordinator.extraActionsCancellable = language.languageService?.extraActions
          .receive(on: DispatchQueue.main)
          .sink { [coordinator] actions in

            coordinator.actions.language.extraActions = actions
          }

      }
    }
  }

  public func makeCoordinator() -> Coordinator {
    return Coordinator(text: $text, position: $position, setAction: definitiveSetActions, setInfo: definitiveSetInfo)
  }

  public final class Coordinator: _Coordinator {
    var boundsChangedNotificationObserver: NSObjectProtocol?
    var extraActionsCancellable:           Cancellable?
    var breakUndoCoalescingCancellable:    Cancellable?

    deinit {
      if let observer = boundsChangedNotificationObserver { NotificationCenter.default.removeObserver(observer) }
    }

    // Update of `self.text` happens in `CodeStorageDelegate` — see [Note Propagating text changes into SwiftUI].
    func textDidChange(_ textView: NSTextView) { }

    func selectionDidChange(_ textView: NSTextView) {
      guard !updatingView else { return }

      let newValue = textView.selectedRanges.map{ $0.rangeValue }
      if self.position.selections != newValue {

        self.position.selections  = newValue
        if let codeStorageDelegate = ((textView as? CodeView)?.optCodeStorage as? CodeStorage)?.delegate
                                       as? CodeStorageDelegate
        {
          self.info.selectionSummary = Info.SelectionSummary(selections: newValue, with: codeStorageDelegate.lineMap)
        }

      }
    }

    @MainActor
    func scrollPositionDidChange(_ scrollView: NSScrollView) {
      guard !updatingView else { return }

      if abs(position.verticalScrollPosition - scrollView.verticalScrollPosition) > 0.0001 {
        position.verticalScrollPosition = scrollView.verticalScrollPosition
      }
    }
  }
}


// MARK: -
// MARK: Shared code

// MARK: Themes

/// Environment key for the current code editor theme.
///
public struct CodeEditorTheme: EnvironmentKey {
  public static var defaultValue: Theme = Theme.defaultLight
}

extension EnvironmentValues {

  /// The current code editor theme.
  ///
  public var codeEditorTheme: Theme {
    get { self[CodeEditorTheme.self] }
    set { self[CodeEditorTheme.self] = newValue }
  }
}


// MARK: Positions

extension CodeEditor.Position: RawRepresentable, Codable {

  public init?(rawValue: String) {

    func parseNSRange(lexeme: String) -> NSRange? {
      let components = lexeme.components(separatedBy: ":")
      guard components.count == 2,
            let location = Int(components[0]),
            let length   = Int(components[1])
      else { return nil }
      return NSRange(location: location, length: length)
    }

    let components = rawValue.components(separatedBy: "|")
    if components.count == 2 {

      selections             = components[0].components(separatedBy: ";").compactMap{ parseNSRange(lexeme: $0) }
      verticalScrollPosition = CGFloat(Double(components[1]) ?? 0)

    } else { self = CodeEditor.Position() }
  }

  public var rawValue: String {
    let selectionsString             = selections.map{ "\($0.location):\($0.length)" }.joined(separator: ";"),
        verticalScrollPositionString = String(describing: verticalScrollPosition)
    return selectionsString + "|" + verticalScrollPositionString
  }
}


// MARK: -
// MARK: Previews

struct CodeEditor_Previews: PreviewProvider {

  static var previews: some View {
    CodeEditor(text: .constant("-- Hello World!"),
               position: .constant(CodeEditor.Position()),
               messages: .constant(Set()),
               language: .haskell())
  }
}
