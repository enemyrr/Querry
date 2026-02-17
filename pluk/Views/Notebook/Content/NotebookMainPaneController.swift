import AppKit
import SwiftUI

final class NotebookMainPaneController: NSViewController {

    private let dataController: NotebookDataController

    private var mainContentView: NSView!
    private var headerHostingView: NSHostingView<AnyView>?
    private var toolbarHostingView: NSHostingView<AnyView>?
    private var emptyStateHostingView: NSHostingView<AnyView>?

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
        setupConstraints()
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
        view.window?.makeFirstResponder(nil)
    }

    // MARK: - Setup

    private func addHostingView<V: View>(_ rootView: V) -> NSHostingView<AnyView> {
        let hosting = NSHostingView(rootView: AnyView(rootView))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        mainContentView.addSubview(hosting)
        return hosting
    }

    private func setupHeader() {
        headerHostingView = addHostingView(NotebookHeaderView(dataController: dataController))
        headerHostingView?.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    private func setupToolbar() {
        toolbarHostingView = addHostingView(NotebookToolbar(dataController: dataController))
        toolbarHostingView?.setContentCompressionResistancePriority(.required, for: .horizontal)
        toolbarHostingView?.setContentHuggingPriority(.required, for: .horizontal)
    }

    private func setupEmptyState() {
        emptyStateHostingView = addHostingView(NotebookEmptyStateView(dataController: dataController))
    }

    private func setupConstraints() {
        guard let header = headerHostingView,
              let toolbar = toolbarHostingView,
              let emptyState = emptyStateHostingView else { return }

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
        ])
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
                : NSColor(red: 253.0 / 255, green: 253.0 / 255, blue: 253.0 / 255, alpha: 1).cgColor
        }
    }

    private func makeShadow() -> NSShadow {
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.08)
        shadow.shadowBlurRadius = 2
        shadow.shadowOffset = .zero
        return shadow
    }
}
