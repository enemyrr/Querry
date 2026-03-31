//
//  CodeActions.swift
//
//
//  Created by Fauzaan on 31/01/2023.
//

import Combine
import AppKit
import SwiftUI  // Required for LanguageService `any View` types (InfoPopover, completion row/doc views)
import os

import LanguageSupport


private let logger = Logger(subsystem: "org.justtesting.CodeEditorView", category: "CodeActions")


// MARK: -
// MARK: Code info support

/// Popover used to display the result of an info code query.
///
/// NB: Retains `NSHostingController` because `LanguageService.info()` returns `any View`.
///
final class InfoPopover: NSPopover {

  init(displaying view: any View, width: CGFloat) {
    super.init()
    let rootView = ScrollView(.vertical){ AnyView(view).padding() }
                     .frame(width: width, alignment: .topLeading)
    contentViewController = NSHostingController(rootView: rootView)
    contentViewController?.preferredContentSize = CGSize(width: width, height: width * 1.1)
    behavior = .transient
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

extension CodeView {

  @MainActor
  func show(infoPopover: InfoPopover, for range: NSRange) {
    self.infoPopover?.close()
    self.infoPopover = infoPopover

    let screenRect         = firstRect(forCharacterRange: range, actualRange: nil),
        nonEmptyScreenRect = NSRect(origin: screenRect.origin, size: CGSize(width: 1, height: 1)),
        windowRect         = window!.convertFromScreen(nonEmptyScreenRect)

    infoPopover.show(relativeTo: convert(windowRect, from: nil), of: self, preferredEdge: .maxY)
  }

  func infoAction() {
    guard let languageService = optLanguageService else { return }

    let width = min((window?.frame.width ?? 250) * 0.75, 500)

    let range = selectedRange()
    Task {
      do {
        if let info = try await languageService.info(at: range.location) {
          show(infoPopover: InfoPopover(displaying: info.view, width: width), for: info.anchor ?? range)
        }
      } catch let error { logger.trace("Info action failed: \(error.localizedDescription)") }
    }
  }
}


// MARK: -
// MARK: Completions support

public enum CompletionProgress {
  case cancel
  case completion(String, NSRange?)
  case input(NSEvent)
}


// MARK: Completion cell view

/// NSTableCellView that wraps a LanguageService `any View` row via NSHostingView.
///
final class CompletionCellView: NSTableCellView {

  static let identifier = NSUserInterfaceItemIdentifier("CompletionCellView")

  private var hostingView: NSHostingView<AnyView>?

  func configure(with item: Completions.Completion, isSelected: Bool) {
    let newRoot = AnyView(AnyView(item.rowView(isSelected)).lineLimit(1))
    if let hosting = hostingView {
      hosting.rootView = newRoot
    } else {
      let hosting = NSHostingView(rootView: newRoot)
      hosting.translatesAutoresizingMaskIntoConstraints = false
      addSubview(hosting)
      NSLayoutConstraint.activate([
        hosting.topAnchor.constraint(equalTo: topAnchor),
        hosting.bottomAnchor.constraint(equalTo: bottomAnchor),
        hosting.leadingAnchor.constraint(equalTo: leadingAnchor),
        hosting.trailingAnchor.constraint(equalTo: trailingAnchor),
      ])
      hostingView = hosting
    }
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    hostingView?.removeFromSuperview()
    hostingView = nil
  }
}


// MARK: Completion panel

final class CompletionPanel: NSPanel, NSTableViewDelegate, NSTableViewDataSource {

  private(set) var completions: Completions = .none
  private var selectedItemID: Int?

  var progressHandler: ((CompletionProgress) -> Void)?

  private let scrollView = NSScrollView()
  private let tableView = NSTableView()
  private let divider = NSBox()
  private let docScrollView = NSScrollView()
  private var docHostingView: NSHostingView<AnyView>?

  private var didResignObserver: NSObjectProtocol?

  init() {
    super.init(contentRect: NSRect(x: 0, y: 0, width: 500, height: 300),
               styleMask: [.nonactivatingPanel, .fullSizeContentView], backing: .buffered, defer: true)
    collectionBehavior.insert(.fullScreenAuxiliary)
    isFloatingPanel             = true
    titleVisibility             = .hidden
    titlebarAppearsTransparent  = true
    isMovableByWindowBackground = false
    hidesOnDeactivate           = true
    animationBehavior           = .utilityWindow
    backgroundColor             = .clear

    standardWindowButton(.closeButton)?.isHidden       = true
    standardWindowButton(.miniaturizeButton)?.isHidden = true
    standardWindowButton(.zoomButton)?.isHidden        = true

    setupViews()

    self.didResignObserver = NotificationCenter.default.addObserver(
      forName: NSWindow.didResignKeyNotification,
      object: self,
      queue: nil
    ) { [weak self] _ in
      self?.close()
    }
  }

  deinit {
    if let didResignObserver { NotificationCenter.default.removeObserver(didResignObserver) }
  }

  private func setupViews() {
    let container = NSView()
    container.wantsLayer = true
    container.layer?.cornerRadius = 10
    container.layer?.masksToBounds = true
    container.layer?.borderColor = NSColor.gray.withAlphaComponent(0.5).cgColor
    container.layer?.borderWidth = 1

    // Table view
    let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("CompletionColumn"))
    column.resizingMask = .autoresizingMask
    tableView.addTableColumn(column)
    tableView.headerView = nil
    tableView.rowHeight = 24
    tableView.intercellSpacing = .zero
    tableView.backgroundColor = .windowBackgroundColor
    tableView.delegate = self
    tableView.dataSource = self
    tableView.selectionHighlightStyle = .regular
    tableView.allowsEmptySelection = false

    scrollView.documentView = tableView
    scrollView.hasVerticalScroller = true
    scrollView.autohidesScrollers = true
    scrollView.borderType = .noBorder
    scrollView.drawsBackground = false
    scrollView.translatesAutoresizingMaskIntoConstraints = false

    // Divider
    divider.boxType = .separator
    divider.translatesAutoresizingMaskIntoConstraints = false

    // Documentation area
    docScrollView.hasVerticalScroller = true
    docScrollView.autohidesScrollers = true
    docScrollView.borderType = .noBorder
    docScrollView.drawsBackground = true
    docScrollView.backgroundColor = .windowBackgroundColor
    docScrollView.translatesAutoresizingMaskIntoConstraints = false

    container.addSubview(scrollView)
    container.addSubview(divider)
    container.addSubview(docScrollView)
    container.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: container.topAnchor),
      scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 100),
      scrollView.heightAnchor.constraint(lessThanOrEqualToConstant: 300),

      divider.topAnchor.constraint(equalTo: scrollView.bottomAnchor),
      divider.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      divider.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      divider.heightAnchor.constraint(equalToConstant: 1),

      docScrollView.topAnchor.constraint(equalTo: divider.bottomAnchor),
      docScrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      docScrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      docScrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
      docScrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 50),
      docScrollView.heightAnchor.constraint(lessThanOrEqualToConstant: 200),
    ])

    contentView = container
  }

  override var canBecomeKey: Bool { true }

  override func close() {
    if isKeyWindow { progressHandler?(.cancel) }
    super.close()
  }

  override func keyDown(with event: NSEvent) {
    if event.keyCode == keyCodeDownArrow || event.keyCode == keyCodeUpArrow {

      let row = tableView.selectedRow
      let newRow: Int
      if event.keyCode == keyCodeDownArrow {
        newRow = min(row + 1, tableView.numberOfRows - 1)
      } else {
        newRow = max(row - 1, 0)
      }
      tableView.selectRowIndexes(IndexSet(integer: newRow), byExtendingSelection: false)
      tableView.scrollRowToVisible(newRow)

    } else if event.keyCode == keyCodeReturn {

      let row = tableView.selectedRow
      if row >= 0 && row < completions.items.count {
        let item = completions.items[row]
        progressHandler?(.completion(item.insertText, item.insertRange))
      } else {
        progressHandler?(.cancel)
      }

    } else if event.keyCode == keyCodeESC {

      progressHandler?(.cancel)

    } else if !event.modifierFlags.intersection([.command, .control, .option]).isEmpty {

      progressHandler?(.input(event))
      close()

    } else {

      progressHandler?(.input(event))

    }
  }

  // MARK: Set completions

  func set(completions: Completions,
           anchoredAt screenRect: CGRect? = nil,
           handler: @escaping (CompletionProgress) -> Void)
  {
    var completions = completions
    completions.items.sort()

    self.completions     = completions
    self.progressHandler = handler

    if let screenRect {
      setFrameTopLeftPoint(CGPoint(x: screenRect.minX, y: screenRect.minY))
    }

    selectedItemID = if let selected = (completions.items.first{ $0.selected }) { selected.id }
                     else { completions.items.first?.id }

    if completions.items.isEmpty {
      close()
    } else {
      tableView.reloadData()

      if let selectedID = selectedItemID,
         let index = completions.items.firstIndex(where: { $0.id == selectedID })
      {
        tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        tableView.scrollRowToVisible(index)
      }

      if !isVisible {
        makeKeyAndOrderFront(nil)
      }

      updateDocumentation()

      Task { @MainActor in
        for (offset, item) in self.completions.items.enumerated() {
          if let refinedItem = try? await item.refine() {
            self.completions.items[offset] = refinedItem
          }
        }
        tableView.reloadData()
      }
    }
  }

  // MARK: NSTableViewDataSource

  func numberOfRows(in tableView: NSTableView) -> Int {
    completions.items.count
  }

  // MARK: NSTableViewDelegate

  func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
    guard row < completions.items.count else { return nil }

    let cell = tableView.makeView(withIdentifier: CompletionCellView.identifier, owner: self)
                as? CompletionCellView
               ?? CompletionCellView()
    cell.identifier = CompletionCellView.identifier

    let item = completions.items[row]
    let isSelected = item.id == selectedItemID
    cell.configure(with: item, isSelected: isSelected)
    return cell
  }

  func tableViewSelectionDidChange(_ notification: Notification) {
    let row = tableView.selectedRow
    if row >= 0 && row < completions.items.count {
      selectedItemID = completions.items[row].id
    }
    updateDocumentation()
  }

  private func updateDocumentation() {
    docHostingView?.removeFromSuperview()
    docHostingView = nil

    guard let selectedID = selectedItemID,
          let item = completions.items.first(where: { $0.id == selectedID })
    else { return }

    let docView = AnyView(
      HStack {
        AnyView(item.documentationView)
        Spacer()
      }
      .padding()
    )
    let hosting = NSHostingView(rootView: docView)
    hosting.translatesAutoresizingMaskIntoConstraints = false
    docScrollView.documentView = hosting
    docHostingView = hosting
  }
}


// MARK: -
// MARK: CodeView completion extensions

extension CodeView {

  @MainActor
  func show(completions: Completions, for range: NSRange) {

    completionPanel.set(completions: completions,
                        anchoredAt: firstRect(forCharacterRange: range, actualRange: nil)) {
      [weak self] completionProgress in

      switch completionProgress {

      case .cancel:
        self?.completionPanel.progressHandler = nil
        self?.completionPanel.close()

      case .completion(let insertText, let insertRange):
        self?.insertText(insertText, replacementRange: insertRange ?? range)
        self?.completionPanel.progressHandler = nil
        self?.completionPanel.close()

      case .input(let event):
        self?.interpretKeyEvents([event])
      }
    }
  }

  func computeAndShowCompletions(at location: Int) async throws {
    guard let languageService = optLanguageService else { return }

    do {
      let reason: CompletionTriggerReason = if completionPanel.isKeyWindow { .incomplete } else { .standard },
          completions                     = try await languageService.completions(at: location, reason: reason)
      try Task.checkCancellation()
      show(completions: completions, for: rangeForUserCompletion)
    } catch let error { logger.trace("Completion action failed: \(error.localizedDescription)") }
  }

  func completionAction() {
    completionTask?.cancel()

    if completionPanel.isKeyWindow {
      completionPanel.close()
    } else {
      completionTask = Task {
        try await computeAndShowCompletions(at: selectedRange().location)
      }
    }
  }

  func considerCompletionFor(range: NSRange) {
    guard let codeStorageDelegate = optCodeStorage?.delegate as? CodeStorageDelegate else { return }

    completionTask?.cancel()

    if range.length > 0 && codeStorageDelegate.processingOneCharacterAddition {

      completionTask = Task {
        if range.length < 3 && !completionPanel.isKeyWindow { try await Task.sleep(for: .seconds(0.2)) }
        try await computeAndShowCompletions(at: range.max)
      }

    } else if range.length == 0 && completionPanel.isKeyWindow {
      completionPanel.close()
    }
  }
}
