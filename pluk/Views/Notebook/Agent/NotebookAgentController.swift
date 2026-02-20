import AppKit

final class NotebookAgentController: NSViewController {

    private let dataController: NotebookDataController

    private var headerView: AgentHeaderView!
    private var emptyStateView: AgentEmptyStateView!
    private var chatInputView: AgentChatInputView!

    init(dataController: NotebookDataController) {
        self.dataController = dataController
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        let root = NSView()
        root.wantsLayer = true
        self.view = root

        setupHeader()
        setupEmptyState()
        setupChatInput()
        setupConstraints()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        chatInputView.focusInput()
    }

    // MARK: - Setup

    private func setupHeader() {
        headerView = AgentHeaderView()
        headerView.onClose = { [weak self] in
            self?.dataController.isRightSidebarVisible = false
        }
        headerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerView)
    }

    private func setupEmptyState() {
        emptyStateView = AgentEmptyStateView()
        emptyStateView.onSuggestionSelected = { [weak self] message in
            self?.chatInputView.text = message
        }
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyStateView)
    }

    private func setupChatInput() {
        chatInputView = AgentChatInputView()
        chatInputView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(chatInputView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            emptyStateView.topAnchor.constraint(greaterThanOrEqualTo: headerView.bottomAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: chatInputView.topAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            chatInputView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            chatInputView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            chatInputView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
}
