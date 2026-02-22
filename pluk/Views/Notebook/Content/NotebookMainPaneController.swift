import AppKit
import SwiftUI

final class NotebookMainPaneController: NSViewController {

    private let dataController: NotebookDataController

    private var mainContentView: NSView!
    private var headerController: NotebookHeaderViewController?
    private var toolbarHostingView: NSHostingView<AnyView>?
    private var emptyStateController: NotebookEmptyStateController?
    private var blocksController: NotebookBlocksController?
    private var isHeaderCompact = false
    private var didApplyInitialHeaderState = false

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
        setupToolbar()
        setupEmptyState()
        setupBlocksView()
        setupConstraints()
        updateBlocksVisibility()
        observeBlocksState()
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

    private func setupHeader() {
        let headerVC = NotebookHeaderViewController(dataController: dataController)
        addChild(headerVC)
        headerVC.view.translatesAutoresizingMaskIntoConstraints = false
        mainContentView.addSubview(headerVC.view)
        headerController = headerVC
    }

    private func setupToolbar() {
        toolbarHostingView = addHostingView(NotebookToolbar(dataController: dataController))
        toolbarHostingView?.setContentCompressionResistancePriority(.required, for: .horizontal)
        toolbarHostingView?.setContentHuggingPriority(.required, for: .horizontal)
    }

    private func setupEmptyState() {
        let emptyStateVC = NotebookEmptyStateController(dataController: dataController)
        addChild(emptyStateVC)
        emptyStateVC.view.translatesAutoresizingMaskIntoConstraints = false
        mainContentView.addSubview(emptyStateVC.view)
        emptyStateController = emptyStateVC
    }

    private func setupBlocksView() {
        let blocksVC = NotebookBlocksController(dataController: dataController)
        blocksVC.onScrollOffsetChanged = { [weak self] offset in
            self?.handleBlocksScroll(offset)
        }
        addChild(blocksVC)
        blocksVC.view.translatesAutoresizingMaskIntoConstraints = false
        mainContentView.addSubview(blocksVC.view)
        blocksController = blocksVC
    }

    private func setupConstraints() {
        guard let header = headerController?.view,
              let toolbar = toolbarHostingView,
              let emptyState = emptyStateController?.view,
              let blocks = blocksController?.view else { return }

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: mainContentView.topAnchor),
            header.leadingAnchor.constraint(equalTo: mainContentView.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: toolbar.leadingAnchor),

            toolbar.topAnchor.constraint(equalTo: mainContentView.topAnchor),
            toolbar.trailingAnchor.constraint(equalTo: mainContentView.trailingAnchor),

            emptyState.topAnchor.constraint(equalTo: header.bottomAnchor),
            emptyState.leadingAnchor.constraint(equalTo: mainContentView.leadingAnchor),
            emptyState.trailingAnchor.constraint(equalTo: mainContentView.trailingAnchor),
            emptyState.bottomAnchor.constraint(equalTo: mainContentView.bottomAnchor),

            blocks.topAnchor.constraint(equalTo: header.bottomAnchor),
            blocks.leadingAnchor.constraint(equalTo: mainContentView.leadingAnchor),
            blocks.trailingAnchor.constraint(equalTo: mainContentView.trailingAnchor),
            blocks.bottomAnchor.constraint(equalTo: mainContentView.bottomAnchor),
        ])
    }

    // MARK: - Block State Management

    private func updateBlocksVisibility() {
        let hasBlocks = dataController.hasBlocks
        emptyStateController?.view.isHidden = hasBlocks
        blocksController?.view.isHidden = !hasBlocks

        if !hasBlocks {
            isHeaderCompact = false
        }

        headerController?.setCompactMode(
            hasBlocks && isHeaderCompact,
            animated: didApplyInitialHeaderState
        )
        didApplyInitialHeaderState = true
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

    private func handleBlocksScroll(_ offset: CGFloat) {
        guard dataController.hasBlocks else { return }

        let shouldBeCompact = isHeaderCompact ? offset >= 18 : offset > 36
        guard shouldBeCompact != isHeaderCompact else { return }

        isHeaderCompact = shouldBeCompact
        headerController?.setCompactMode(shouldBeCompact, animated: true)
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
