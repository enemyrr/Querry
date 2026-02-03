//
//  SettingsWindowController.swift
//  Pluk
//

import Cocoa
import SwiftUI

// MARK: - Window Controller

final class SettingsWindowController: NSWindowController, NSToolbarDelegate {
    static let shared = SettingsWindowController()
    private var splitViewController: SettingsSplitViewController?
    private var navigationHistory = SettingsNavigationHistory()

    private static let backForwardIdentifier = NSToolbarItem.Identifier("backForward")
    private static let titleIdentifier = NSToolbarItem.Identifier("title")
    private var titleTextField: NSTextField?

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 450),
            styleMask: [.titled, .closable, .fullSizeContentView, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = ""
        window.titleVisibility = .hidden
        window.toolbarStyle = .unified
        window.setContentSize(NSSize(width: 680, height: 450))
        window.contentMinSize = NSSize(width: 680, height: 450)
        window.contentMaxSize = NSSize(width: 680, height: 450)
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)

        let toolbar = NSToolbar(identifier: "SettingsToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        window.toolbar = toolbar

        let splitVC = SettingsSplitViewController(
            navigationHistory: navigationHistory,
            onPaneChange: { [weak self] pane, isUserSelection in
                self?.titleTextField?.stringValue = pane.rawValue
                if isUserSelection {
                    self?.navigationHistory.push(pane)
                }
                self?.updateToolbarButtons()
            }
        )
        self.splitViewController = splitVC
        window.contentViewController = splitVC

        navigationHistory.push(.general)
    }

    private func updateTitle(_ title: String) {
        titleTextField?.stringValue = title
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func updateToolbarButtons() {
        window?.toolbar?.items.forEach { item in
            if item.itemIdentifier == Self.backForwardIdentifier,
               let segmented = item.view as? NSSegmentedControl {
                segmented.setEnabled(navigationHistory.canGoBack, forSegment: 0)
                segmented.setEnabled(navigationHistory.canGoForward, forSegment: 1)
            }
        }
    }

    @objc private func backForwardAction(_ sender: NSSegmentedControl) {
        if sender.selectedSegment == 0 {
            if let pane = navigationHistory.goBack() {
                splitViewController?.navigateTo(pane)
                titleTextField?.stringValue = pane.rawValue
            }
        } else {
            if let pane = navigationHistory.goForward() {
                splitViewController?.navigateTo(pane)
                titleTextField?.stringValue = pane.rawValue
            }
        }
        updateToolbarButtons()
    }

    // MARK: - NSToolbarDelegate

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.backForwardIdentifier, Self.titleIdentifier, .flexibleSpace]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.backForwardIdentifier, Self.titleIdentifier, .flexibleSpace]
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        if itemIdentifier == Self.backForwardIdentifier {
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)

            let segmented = NSSegmentedControl()
            segmented.segmentStyle = .separated
            segmented.trackingMode = .momentary
            segmented.segmentCount = 2

            segmented.setImage(NSImage(systemSymbolName: "chevron.left", accessibilityDescription: "Back")?.withSymbolConfiguration(.init(pointSize: 11, weight: .medium)), forSegment: 0)
            segmented.setImage(NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "Forward")?.withSymbolConfiguration(.init(pointSize: 11, weight: .medium)), forSegment: 1)

            segmented.setWidth(24, forSegment: 0)
            segmented.setWidth(24, forSegment: 1)
            segmented.controlSize = .small

            segmented.setEnabled(false, forSegment: 0)
            segmented.setEnabled(false, forSegment: 1)

            segmented.target = self
            segmented.action = #selector(backForwardAction(_:))

            item.view = segmented
            return item
        }

        if itemIdentifier == Self.titleIdentifier {
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)

            let textField = NSTextField(labelWithString: "General")
            textField.font = .systemFont(ofSize: 15, weight: .semibold)
            textField.textColor = .labelColor
            textField.alignment = .left

            self.titleTextField = textField
            item.view = textField
            return item
        }

        return nil
    }
}

// MARK: - Navigation History

@MainActor
final class SettingsNavigationHistory {
    private var history: [SettingsPane] = []
    private var currentIndex: Int = -1

    var canGoBack: Bool { currentIndex > 0 }
    var canGoForward: Bool { currentIndex < history.count - 1 }

    func push(_ pane: SettingsPane) {
        if currentIndex >= 0 && currentIndex < history.count && history[currentIndex] == pane {
            return
        }

        if currentIndex < history.count - 1 {
            history.removeLast(history.count - currentIndex - 1)
        }

        history.append(pane)
        currentIndex = history.count - 1
    }

    func goBack() -> SettingsPane? {
        guard canGoBack else { return nil }
        currentIndex -= 1
        return history[currentIndex]
    }

    func goForward() -> SettingsPane? {
        guard canGoForward else { return nil }
        currentIndex += 1
        return history[currentIndex]
    }
}

// MARK: - Split View Controller

final class SettingsSplitViewController: NSSplitViewController {
    private let sidebarViewModel: SettingsSidebarViewModel

    init(navigationHistory: SettingsNavigationHistory, onPaneChange: @escaping (SettingsPane, Bool) -> Void) {
        self.sidebarViewModel = SettingsSidebarViewModel(onPaneChange: onPaneChange)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let sidebarItem = NSSplitViewItem(sidebarWithViewController: NSHostingController(
            rootView: SettingsSidebarView(viewModel: sidebarViewModel)
        ))
        sidebarItem.canCollapse = false
        sidebarItem.minimumThickness = 180
        sidebarItem.maximumThickness = 180
        addSplitViewItem(sidebarItem)

        let detailItem = NSSplitViewItem(viewController: NSHostingController(
            rootView: SettingsDetailView(viewModel: sidebarViewModel)
        ))
        detailItem.minimumThickness = 400
        addSplitViewItem(detailItem)
    }

    func navigateTo(_ pane: SettingsPane) {
        sidebarViewModel.selectPane(pane, isUserSelection: false)
    }
}

// MARK: - View Model

@Observable
@MainActor
final class SettingsSidebarViewModel {
    var selectedPane: SettingsPane = .general

    private let onPaneChange: ((SettingsPane, Bool) -> Void)?
    private var isUserSelection = true

    init(onPaneChange: ((SettingsPane, Bool) -> Void)? = nil) {
        self.onPaneChange = onPaneChange
    }

    func selectPane(_ pane: SettingsPane, isUserSelection: Bool) {
        self.isUserSelection = isUserSelection
        self.selectedPane = pane
        onPaneChange?(pane, isUserSelection)
        self.isUserSelection = true
    }
}

// MARK: - Settings Pane

enum SettingsPane: String, CaseIterable, Identifiable {
    case general = "General"
    case keymap = "Keymap"
    case about = "About"

    // MARK: - Future Settings Panes (uncomment to enable)
    // These panes have UI implemented but are disabled for initial release.
    // To enable: uncomment the case, add to icon switch, and uncomment in SettingsDetailView
    //
    // case tabs = "Tabs"           // TabsSettingsView.swift - Tab behavior, restoration, display
    // case fontIcons = "Font & Icons"  // FontIconsSettingsView.swift - Editor fonts, icons, themes
    // case security = "Security"   // SecuritySettingsView.swift - Credentials, SSL, privacy
    // case ai = "AI"               // AISettingsView.swift - AI features, model config, privacy

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: "gear"
        case .keymap: "keyboard"
        case .about: "info.circle"
        // Future pane icons:
        // case .tabs: "square.on.square"
        // case .fontIcons: "textformat"
        // case .security: "lock.shield"
        // case .ai: "sparkles"
        }
    }
}

// MARK: - Sidebar View

struct SettingsSidebarView: View {
    @Bindable var viewModel: SettingsSidebarViewModel

    var body: some View {
        List(SettingsPane.allCases, selection: Binding(
            get: { viewModel.selectedPane },
            set: { newValue in
                if let pane = newValue {
                    viewModel.selectPane(pane, isUserSelection: true)
                }
            }
        )) { pane in
            Label(pane.rawValue, systemImage: pane.icon)
                .tag(pane)
        }
        .listStyle(.sidebar)
    }
}

// MARK: - Detail View

struct SettingsDetailView: View {
    var viewModel: SettingsSidebarViewModel

    var body: some View {
        switch viewModel.selectedPane {
        case .general:
            GeneralSettingsView()
        case .keymap:
            KeymapSettingsView()
        case .about:
            AboutSettingsView()

        // MARK: - Future Settings Views (uncomment when panes are enabled)
        // case .tabs:
        //     TabsSettingsView()
        // case .fontIcons:
        //     FontIconsSettingsView()
        // case .security:
        //     SecuritySettingsView()
        // case .ai:
        //     AISettingsView()
        }
    }
}
