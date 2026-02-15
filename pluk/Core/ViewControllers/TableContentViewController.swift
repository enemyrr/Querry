import AppKit
import Observation
import SwiftData
import SwiftUI

final class TableContentViewController: NSViewController {

    // MARK: - Dependencies

    private let tab: DatabaseTab
    private let instance: ConnectionInstance
    private let appViewModel: AppViewModel
    private let sidebarViewModel: SidebarViewModel
    private let tabManager: TabManager
    private let modelContainer: ModelContainer

    let dataController: TableDataController
    private var coordinator: TableCoordinator?

    // MARK: - Views

    private var filterBarHostingView: NSHostingView<AnyView>?
    private var contentArea: NSView!
    private var floatingBarHostingView: NSHostingView<AnyView>?
    private var currentContentView: NSView?
    private var filterLayoutTask: Task<Void, Never>?

    // MARK: - Notification Observers

    private var markRowObserver: Any?
    private var pasteObserver: Any?
    private var toggleFilterBuilderObserver: Any?
    private var filterBuilderDidCloseObserver: Any?

    // MARK: - Init

    init(
        tab: DatabaseTab,
        instance: ConnectionInstance,
        appViewModel: AppViewModel,
        sidebarViewModel: SidebarViewModel,
        tabManager: TabManager,
        modelContainer: ModelContainer
    ) {
        self.tab = tab
        self.instance = instance
        self.appViewModel = appViewModel
        self.sidebarViewModel = sidebarViewModel
        self.tabManager = tabManager
        self.modelContainer = modelContainer
        self.dataController = TableDataController(instance: instance, tab: tab)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    deinit {
        MainActor.assumeIsolated {
            dataController.cancel()
        }
        filterLayoutTask?.cancel()
        for observer in [markRowObserver, pasteObserver, toggleFilterBuilderObserver, filterBuilderDidCloseObserver].compactMap({ $0 }) {
            NotificationCenter.default.removeObserver(observer)
        }
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Environment Injection

    private func injectEnvironments<V: View>(_ view: V) -> some View {
        view
            .environment(instance)
            .environment(appViewModel)
            .environment(sidebarViewModel)
            .environment(tabManager)
            .environment(\.currentDatabaseType, instance.connection.databaseType)
            .modelContainer(modelContainer)
    }

    // MARK: - View Lifecycle

    override func loadView() {
        let root = NSView()
        root.wantsLayer = true
        root.autoresizingMask = [.width, .height]
        root.layer?.cornerRadius = 10
        root.layer?.masksToBounds = true
        self.view = root

        setupContentArea()
        setupFilterBar()
        setupFloatingBar()
        setupLayout()
        setupNotifications()
        startObserving()
        updateBackgroundColor()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppearanceChange),
            name: .appAppearanceDidChange,
            object: nil
        )
    }

    @objc private func handleAppearanceChange() {
        updateBackgroundColor()
    }

    private func updateBackgroundColor() {
        NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
            let isDark = NSAppearance.currentDrawing().isDarkMode
            view.layer?.backgroundColor = isDark
                ? NSColor.black.withAlphaComponent(0.25).cgColor
                : NSColor.white.cgColor
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        dataController.updateFilterConditions()
        scheduleFilterBarLayout(afterAnimation: true)
        Task {
            await dataController.loadDocumentsIfNeeded()
        }
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        filterLayoutTask?.cancel()
        dataController.cancel()
    }

    // MARK: - Setup

    private func setupContentArea() {
        contentArea = NSView()
        contentArea.wantsLayer = true
    }

    private func setupFilterBar() {
        let filterBar = FilterBarContainer(
            dataController: dataController,
            onLayoutInvalidated: { [weak self] in
                self?.scheduleFilterBarLayout(afterAnimation: true)
            }
        )
        let wrapped = injectEnvironments(filterBar)
        filterBarHostingView = NSHostingView(rootView: AnyView(wrapped))
    }

    private func setupFloatingBar() {
        let floatingBar = FloatingBarContainer(dataController: dataController, tab: tab)
        let wrapped = injectEnvironments(floatingBar)
        floatingBarHostingView = NSHostingView(rootView: AnyView(wrapped))
    }

    private func setupLayout() {
        guard let filterBarHostingView, let floatingBarHostingView else { return }

        view.addSubview(filterBarHostingView)
        view.addSubview(contentArea)
        view.addSubview(floatingBarHostingView)

        showContentMode()
        layoutContentViews()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        layoutContentViews()
    }

    private func layoutContentViews() {
        guard let filterBarHostingView, let floatingBarHostingView else { return }

        let bounds = view.bounds
        var measurementFrame = filterBarHostingView.frame
        measurementFrame.size.width = bounds.width
        filterBarHostingView.frame = measurementFrame
        filterBarHostingView.layoutSubtreeIfNeeded()
        let filterHeight = max(0, filterBarHostingView.fittingSize.height.rounded(.up))

        filterBarHostingView.frame = NSRect(
            x: 0,
            y: bounds.height - filterHeight,
            width: bounds.width,
            height: filterHeight
        )

        let contentHeight = max(0, bounds.height - filterHeight)

        contentArea.frame = NSRect(
            x: 0,
            y: 0,
            width: bounds.width,
            height: contentHeight
        )

        floatingBarHostingView.frame = NSRect(
            x: 0,
            y: 0,
            width: bounds.width,
            height: contentHeight
        )
    }

    private func setupNotifications() {
        markRowObserver = NotificationCenter.default.addObserver(
            forName: .markRowAsDeleted,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let userInfo = notification.userInfo,
                  let rowIndex = userInfo["rowIndex"] as? Int,
                  let tableName = userInfo["tableName"] as? String else { return }
            Task { @MainActor in
                self.dataController.handleMarkRowAsDeleted(rowIndex: rowIndex, tableName: tableName)
            }
        }

        pasteObserver = NotificationCenter.default.addObserver(
            forName: .didRequestPaste,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.dataController.handlePasteRows()
            }
        }

        toggleFilterBuilderObserver = NotificationCenter.default.addObserver(
            forName: .toggleFilterBuilder,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleFilterBarLayout(afterAnimation: true)
        }

        filterBuilderDidCloseObserver = NotificationCenter.default.addObserver(
            forName: .filterBuilderDidClose,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleFilterBarLayout(afterAnimation: true)
        }
    }

    // MARK: - Content Mode Switching

    private func showContentMode() {
        currentContentView?.removeFromSuperview()

        let tableCoordinator = TableCoordinator(
            schema: dataController.cachedSchema,
            queryResult: dataController.currentQueryResult,
            tableName: tab.name,
            onSort: { [weak self] column, ascending in
                guard let self else { return }
                self.dataController.sortColumn = column.isEmpty ? nil : column
                self.dataController.sortAscending = ascending
                if let databaseType = self.instance.databaseType {
                    Task { @MainActor in
                        AnalyticsService.shared.trackSortApplied(databaseType: databaseType)
                    }
                }
                self.dataController.loadingTask?.cancel()
                self.dataController.loadingTask = Task {
                    self.dataController.skipNextRealtimeEvent = true
                    await self.dataController.loadOrSubscribe(forceFetch: true, fetchSchema: false, page: 1, limit: 300, filter: self.dataController.currentActiveFilter)
                }
            },
            modificationTracker: dataController.modificationTracker,
            onDeleteNewRow: { [weak self] index in
                self?.dataController.deleteNewlyAddedRecord(atIndex: index)
                self?.dataController.needsToSelectLastRow = false
            },
            onForeignKeyNavigation: { [weak self] tableName, columnName, value in
                guard let self else { return }
                self.instance.createNewTab(name: tableName, filterColumn: columnName, filterValue: value, databaseSchema: self.tab.databaseSchema)
            },
            highlightedFields: dataController.updatedFields,
            highlightedRows: dataController.updatedRows,
            cacheNamespace: instance.connection.persistentModelID.storeIdentifier ?? "",
            onRowSelected: { [weak self] rowData in
                self?.tab.selectedRowData = rowData
            },
            onUndoRowInsert: { [weak self] rowIndex in
                self?.dataController.undoRowInsert(atIndex: rowIndex)
            }
        )
        tableCoordinator.currentTab = tab

        self.coordinator = tableCoordinator

        let tableContainer = tableCoordinator.setupTableView()
        tableContainer.translatesAutoresizingMaskIntoConstraints = false
        contentArea.addSubview(tableContainer)

        NSLayoutConstraint.activate([
            tableContainer.topAnchor.constraint(equalTo: contentArea.topAnchor),
            tableContainer.leadingAnchor.constraint(equalTo: contentArea.leadingAnchor),
            tableContainer.trailingAnchor.constraint(equalTo: contentArea.trailingAnchor),
            tableContainer.bottomAnchor.constraint(equalTo: contentArea.bottomAnchor),
        ])

        currentContentView = tableContainer
    }

    private func showSchemaMode() {
        let schemaView = SchemaModeView(
            schema: dataController.cachedSchema,
            indexes: dataController.cachedIndexes,
            tableName: tab.name,
            schemaName: tab.databaseSchema,
            modificationTracker: Binding(
                get: { [weak self] in self?.dataController.schemaModificationTracker ?? SchemaModificationTracker() },
                set: { [weak self] in self?.dataController.schemaModificationTracker = $0 }
            )
        )
        showSwiftUIContent(schemaView)
    }

    private func showDefinitionMode() {
        let defView = DefinitionModeView(
            schema: dataController.cachedSchema,
            tableName: tab.name
        )
        showSwiftUIContent(defView)
    }

    private func showSwiftUIContent(_ content: some View) {
        currentContentView?.removeFromSuperview()
        coordinator = nil

        let wrapped = injectEnvironments(content)
        let hostingView = NSHostingView(rootView: AnyView(wrapped))
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        contentArea.addSubview(hostingView)

        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: contentArea.topAnchor),
            hostingView.leadingAnchor.constraint(equalTo: contentArea.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: contentArea.trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: contentArea.bottomAnchor),
        ])

        currentContentView = hostingView
    }

    private func switchToViewMode(_ mode: DatabaseTab.ViewMode) {
        switch mode {
        case .content:
            showContentMode()
        case .schema:
            showSchemaMode()
        case .definition:
            showDefinitionMode()
        }
    }

    // MARK: - Observation

    private func startObserving() {
        observeViewState()
        observeViewMode()
        observeHighlighting()
        observeErrors()
        observeFilterConditions()
    }

    private func scheduleFilterBarLayout(afterAnimation: Bool = false) {
        filterLayoutTask?.cancel()
        filterLayoutTask = Task { @MainActor [weak self] in
            guard let self else { return }
            self.layoutContentViews()
            await Task.yield()
            self.layoutContentViews()
            if afterAnimation {
                try? await Task.sleep(for: .milliseconds(250))
                self.layoutContentViews()
            }
        }
    }

    private func observeFilterConditions() {
        withObservationTracking {
            _ = dataController.filterConditions
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.scheduleFilterBarLayout()
                self?.observeFilterConditions()
            }
        }
    }

    private func observeViewState() {
        withObservationTracking {
            _ = self.dataController.viewState
            _ = self.dataController.cachedDocuments
            _ = self.dataController.cachedSchema
            _ = self.dataController.needsToSelectLastRow
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.updateTableFromData()
                self?.observeViewState()
            }
        }
    }

    private func observeViewMode() {
        withObservationTracking {
            _ = self.tab.viewMode
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.switchToViewMode(self.tab.viewMode)
                self.observeViewMode()
            }
        }
    }

    private func observeHighlighting() {
        withObservationTracking {
            _ = self.dataController.updatedFields
            _ = self.dataController.updatedRows
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.coordinator?.updateHighlighting(
                    fields: self.dataController.updatedFields,
                    rows: self.dataController.updatedRows
                )
                self.observeHighlighting()
            }
        }
    }

    private func observeErrors() {
        withObservationTracking {
            _ = self.dataController.showingErrorAlert
            _ = self.dataController.showingViewStateError
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                if self.dataController.showingErrorAlert, let error = self.dataController.currentError {
                    self.showNSAlert(title: "Operation Failed", message: error.localizedDescription)
                    self.dataController.showingErrorAlert = false
                }
                if self.dataController.showingViewStateError {
                    self.showNSAlert(title: "Error", message: self.dataController.viewStateErrorMessage)
                    self.dataController.showingViewStateError = false
                }
                self.observeErrors()
            }
        }
    }

    private func showNSAlert(title: String, message: String) {
        guard let window = view.window else { return }
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: window)
    }

    private func updateTableFromData() {
        guard let coordinator else { return }

        if dataController.needsToSelectLastRow {
            coordinator.needsToSelectLastRow = true
        }
        coordinator.currentTab = tab
        coordinator.updateRows(dataController.currentQueryResult, newSchema: dataController.cachedSchema)
        coordinator.updateHighlighting(fields: dataController.updatedFields, rows: dataController.updatedRows)

        dataController.handleViewStateChange()
    }
}

// MARK: - SwiftUI Bridge Views

private struct FilterBarContainer: View {
    @Bindable var dataController: TableDataController
    var onLayoutInvalidated: () -> Void

    var body: some View {
        FilterBuilderView(
            columns: dataController.cachedSchema?.columns ?? [],
            tableName: dataController.tab.name,
            databaseSchema: dataController.tab.databaseSchema,
            onApplyFilter: { filter in
                dataController.currentActiveFilter = filter.isEmpty ? nil : filter
                if let databaseType = dataController.instance.databaseType, !filter.isEmpty {
                    Task { @MainActor in
                        AnalyticsService.shared.trackFilterApplied(databaseType: databaseType)
                    }
                }
                Task {
                    dataController.skipNextRealtimeEvent = true
                    await dataController.loadOrSubscribe(forceFetch: true, fetchSchema: false, page: 1, limit: 300, filter: filter)
                }
            },
            conditions: $dataController.filterConditions,
            onLayoutInvalidated: onLayoutInvalidated
        )
    }
}

private struct FloatingBarContainer: View {
    @Bindable var dataController: TableDataController
    @Bindable var tab: DatabaseTab

    var body: some View {
        FloatingActionBar(
            viewState: dataController.viewState,
            tableName: tab.name,
            tabViewMode: $tab.viewMode,
            modificationTracker: dataController.modificationTracker,
            isProcessingUpdates: dataController.isProcessingUpdates,
            onRefresh: { currentPage, itemsPerPage, fetchSchema in
                Task {
                    dataController.skipNextRealtimeEvent = true
                    await dataController.loadOrSubscribe(
                        forceFetch: true,
                        fetchSchema: fetchSchema,
                        page: currentPage,
                        limit: itemsPerPage,
                        filter: dataController.currentActiveFilter
                    )
                }
            },
            onLoadDocuments: { filter in
                Task {
                    dataController.skipNextRealtimeEvent = true
                    await dataController.loadOrSubscribe(forceFetch: true, fetchSchema: false, page: 1, limit: 300, filter: filter)
                }
            },
            onCommitModifications: {
                Task {
                    dataController.isProcessingUpdates = true
                    await dataController.commitModifications()
                    dataController.isProcessingUpdates = false
                }
            },
            onNewRecord: {
                dataController.handleNewRecord()
            },
            onDiscardChanges: {
                dataController.handleDiscardChanges()
            },
            databaseType: dataController.instance.databaseType,
            currentQueryResult: dataController.currentQueryResult,
            schema: dataController.cachedSchema,
            schemaModificationTracker: dataController.schemaModificationTracker,
            onCommitSchemaModifications: {
                Task {
                    dataController.isProcessingSchemaUpdates = true
                    await dataController.commitSchemaModifications()
                    dataController.isProcessingSchemaUpdates = false
                }
            },
            onNewField: {
                dataController.handleNewField()
            }
        )
        .padding(.bottom, 6)
        .frame(maxHeight: .infinity, alignment: .bottom)
    }
}
