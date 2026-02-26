import AppKit
import SwiftUI

final class NotebookMainPaneController: NSViewController {

    private let dataController: NotebookDataController

    private var mainContentView: NSView!
    private var toolbarHostingView: NSHostingView<AnyView>?
    private var headerController: NotebookHeaderViewController?
    private var emptyStateController: NotebookEmptyStateController?
    private var blocksController: NotebookBlocksController?
    private var dashboardController: DashboardGridController?

    init(dataController: NotebookDataController) {
        self.dataController = dataController
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func loadView() {
        let wrapper = NSView()
        wrapper.wantsLayer = true
        wrapper.layer?.masksToBounds = false
        self.view = wrapper

        mainContentView = NSView()
        mainContentView.wantsLayer = true
        mainContentView.layer?.cornerRadius = 16
        mainContentView.layer?.masksToBounds = true
        mainContentView.shadow = makeShadow()
        mainContentView.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(mainContentView)

        let padding: CGFloat = 4
        NSLayoutConstraint.activate([
            mainContentView.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: padding),
            mainContentView.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: padding),
            mainContentView.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -padding),
            mainContentView.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -padding),
        ])

        updateBackgroundColor()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppearanceChange),
            name: .appAppearanceDidChange,
            object: nil
        )

        setupHeader()
        setupEmptyState()
        setupBlocksView()
        setupDashboard()
        setupToolbar()
        setupConstraints()
        updateBlocksVisibility()
        observeBlocksState()
        observeViewMode()
        observePublishedState()
    }

    func updateCornerRadius(_ radius: CGFloat, animated: Bool) {
        if animated {
            let animation = CABasicAnimation(keyPath: "cornerRadius")
            animation.fromValue = mainContentView.layer?.cornerRadius ?? 16
            animation.toValue = radius
            animation.duration = 0.2
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            mainContentView.layer?.add(animation, forKey: "cornerRadius")
        }
        mainContentView.layer?.cornerRadius = radius
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        updateToolbarInset()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        guard let window = view.window else { return }
        window.makeFirstResponder(window)
    }

    // MARK: - Setup

    private func addHostingView<V: View>(_ rootView: V) -> NSHostingView<AnyView> {
        let hosting = NSHostingView(rootView: AnyView(rootView))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        mainContentView.addSubview(hosting)
        return hosting
    }

    private func setupToolbar() {
        toolbarHostingView = addHostingView(NotebookToolbar(dataController: dataController))
    }

    private func setupHeader() {
        let headerVC = NotebookHeaderViewController(dataController: dataController)
        addChild(headerVC)
        headerVC.view.translatesAutoresizingMaskIntoConstraints = false
        headerController = headerVC
    }

    private func setupEmptyState() {
        let emptyStateVC = NotebookEmptyStateController(dataController: dataController)
        addChild(emptyStateVC)
        emptyStateVC.view.translatesAutoresizingMaskIntoConstraints = false
        mainContentView.addSubview(emptyStateVC.view)
        emptyStateController = emptyStateVC
    }

    private func setupBlocksView() {
        let blocksVC = NotebookBlocksController(
            dataController: dataController,
            headerView: headerController?.view
        )
        blocksVC.onScrollOffsetChanged = { [weak self] offset in
            guard let self else { return }
            self.dataController.isScrolled = offset > 0
        }
        addChild(blocksVC)
        blocksVC.view.translatesAutoresizingMaskIntoConstraints = false
        mainContentView.addSubview(blocksVC.view)
        blocksController = blocksVC
    }

    private func setupDashboard() {
        let dashVC = DashboardGridController(dataController: dataController)
        addChild(dashVC)
        dashVC.view.translatesAutoresizingMaskIntoConstraints = false
        dashVC.view.isHidden = true
        mainContentView.addSubview(dashVC.view)
        dashboardController = dashVC
    }

    private func setupConstraints() {
        guard let toolbar = toolbarHostingView,
              let emptyState = emptyStateController?.view,
              let blocks = blocksController?.view,
              let dashboard = dashboardController?.view else { return }

        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: mainContentView.topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: mainContentView.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: mainContentView.trailingAnchor),

            emptyState.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            emptyState.leadingAnchor.constraint(equalTo: mainContentView.leadingAnchor),
            emptyState.trailingAnchor.constraint(equalTo: mainContentView.trailingAnchor),
            emptyState.bottomAnchor.constraint(equalTo: mainContentView.bottomAnchor),

            blocks.topAnchor.constraint(equalTo: mainContentView.topAnchor),
            blocks.leadingAnchor.constraint(equalTo: mainContentView.leadingAnchor),
            blocks.trailingAnchor.constraint(equalTo: mainContentView.trailingAnchor),
            blocks.bottomAnchor.constraint(equalTo: mainContentView.bottomAnchor),

            dashboard.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            dashboard.leadingAnchor.constraint(equalTo: mainContentView.leadingAnchor),
            dashboard.trailingAnchor.constraint(equalTo: mainContentView.trailingAnchor),
            dashboard.bottomAnchor.constraint(equalTo: mainContentView.bottomAnchor),
        ])
    }

    // MARK: - Block State Management

    private func updateBlocksVisibility() {
        let hasBlocks = dataController.hasBlocks
        let isDashboard = dataController.viewMode == .dashboard

        emptyStateController?.view.isHidden = hasBlocks || isDashboard
        blocksController?.view.isHidden = !hasBlocks || isDashboard
        dashboardController?.view.isHidden = !isDashboard
    }

    private func observeBlocksState() {
        withObservationTracking {
            _ = self.dataController.hasBlocks
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.updateBlocksVisibility()
                self.observeBlocksState()
            }
        }
    }

    private func observeViewMode() {
        withObservationTracking {
            _ = self.dataController.viewMode
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.updateBlocksVisibility()
                self.observeViewMode()
            }
        }
    }

    private func observePublishedState() {
        withObservationTracking {
            _ = self.dataController.isDashboardPublished
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.updateBlocksVisibility()
                self.observePublishedState()
            }
        }
    }

    // MARK: - Toolbar Inset

    private func updateToolbarInset() {
        guard let toolbar = toolbarHostingView else { return }
        let toolbarHeight = toolbar.fittingSize.height
        blocksController?.setTopContentInset(toolbarHeight)
    }

    // MARK: - Appearance

    @objc private func handleAppearanceChange() {
        updateBackgroundColor()
    }

    private func updateBackgroundColor() {
        NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
            let isDark = NSAppearance.currentDrawing().isDarkMode
            mainContentView.layer?.backgroundColor = isDark
                ? NSColor.black.withAlphaComponent(0.25).cgColor
                : NSColor.white.cgColor
        }
    }

    private func makeShadow() -> NSShadow {
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.10)
        shadow.shadowBlurRadius = 1
        shadow.shadowOffset = .zero
        return shadow
    }
}
