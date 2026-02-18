import AppKit
import SwiftUI

final class ChartConfigController: NSViewController {

    private let viewModel: ChartBlockViewModel
    private let connections: [Connection]
    private static let leftPanelWidth: CGFloat = 250
    private static let centerPanelWidth: CGFloat = 250

    private var splitView: CollapsibleSplitView!
    private var innerSplitView: NSSplitView!
    private var fieldsStackView: NSStackView!
    private var chartHostingView: NSHostingView<AnyView>?

    // Source selection (in left panel)
    private var connectionDropdown: SourceDropdownButton!
    private var connectionSpinner: NSProgressIndicator!
    private var tableDropdown: StyledDropdown!
    private var schemaDropdown: StyledDropdown!
    private var schemaLabel: NSTextField!
    private var fieldsLabelTopToSchemaConstraint: NSLayoutConstraint?
    private var fieldsLabelTopToTableConstraint: NSLayoutConstraint?
    private var collapseButton: HoverIconButton!
    private var expandButton: HoverIconButton!
    private var columnPanelContainer: NSView!
    private var headerConnectionDropdown: SourceDropdownButton!
    private var headerSpinner: NSProgressIndicator!
    private var headerBar: NSView!
    private var headerHeightConstraint: NSLayoutConstraint!

    // Axis config controls (in center panel)
    private var xAxisPopUp: StyledDropdown!
    private var yAxisPopUp: StyledDropdown!

    init(viewModel: ChartBlockViewModel, connections: [Connection]) {
        self.viewModel = viewModel
        self.connections = connections
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        let root = NSView()
        root.wantsLayer = true
        self.view = root

        setupSplitView()
        observeSchema()
        observeChartData()
        observeConnecting()
        observeCollections()
        observeSchemas()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        if !didSetInitialDividerPositions {
            didSetInitialDividerPositions = true
            splitView.setPosition(Self.leftPanelWidth, ofDividerAt: 0)
            innerSplitView.setPosition(Self.centerPanelWidth, ofDividerAt: 0)
        }
    }

    private var didSetInitialDividerPositions = false

    // MARK: - Split View

    private func setupSplitView() {
        // Outer split: [left data panel] | [right side]
        splitView = CollapsibleSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.hideDivider = false
        splitView.delegate = self
        splitView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(splitView)

        NSLayoutConstraint.activate([
            splitView.topAnchor.constraint(equalTo: view.topAnchor),
            splitView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            splitView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        setupColumnPanel()
        setupRightSide()
    }

    private func setupRightSide() {
        let rightContainer = NSView()
        rightContainer.wantsLayer = true

        // Header bar (holds expand button, connection dropdown when collapsed, future filters)
        headerBar = NSView()
        headerBar.wantsLayer = true
        headerBar.translatesAutoresizingMaskIntoConstraints = false
        rightContainer.addSubview(headerBar)

        expandButton = HoverIconButton(symbolName: "rectangle.leftthird.inset.filled", target: self, action: #selector(toggleColumnPanel))
        expandButton.translatesAutoresizingMaskIntoConstraints = false
        expandButton.isHidden = true
        headerBar.addSubview(expandButton)

        headerConnectionDropdown = SourceDropdownButton(
            connections: connections,
            onSelect: { [weak self] connection in
                guard let self else { return }
                Task { await self.viewModel.connectToSource(connection) }
            }
        )
        headerConnectionDropdown.translatesAutoresizingMaskIntoConstraints = false
        headerConnectionDropdown.isHidden = true
        headerBar.addSubview(headerConnectionDropdown)

        headerSpinner = NSProgressIndicator()
        headerSpinner.style = .spinning
        headerSpinner.controlSize = .mini
        headerSpinner.isHidden = true
        headerSpinner.translatesAutoresizingMaskIntoConstraints = false
        headerBar.addSubview(headerSpinner)

        if let cfg = viewModel.config, !cfg.connectionName.isEmpty {
            let iconName = DatabaseType(rawValue: cfg.databaseType)?.icon
            headerConnectionDropdown.updateLabel(cfg.connectionName, iconName: iconName)
        }

        let headerDivider = NSBox()
        headerDivider.boxType = .separator
        headerDivider.translatesAutoresizingMaskIntoConstraints = false
        headerBar.addSubview(headerDivider)

        headerHeightConstraint = headerBar.heightAnchor.constraint(equalToConstant: 38)
        headerHeightConstraint.isActive = true

        NSLayoutConstraint.activate([
            headerDivider.leadingAnchor.constraint(equalTo: headerBar.leadingAnchor),
            headerDivider.trailingAnchor.constraint(equalTo: headerBar.trailingAnchor),
            headerDivider.bottomAnchor.constraint(equalTo: headerBar.bottomAnchor),
        ])

        // Inner split: [axis config] | [chart preview]
        innerSplitView = NSSplitView()
        innerSplitView.isVertical = true
        innerSplitView.dividerStyle = .thin
        innerSplitView.delegate = self
        innerSplitView.translatesAutoresizingMaskIntoConstraints = false
        rightContainer.addSubview(innerSplitView)

        NSLayoutConstraint.activate([
            headerBar.topAnchor.constraint(equalTo: rightContainer.topAnchor),
            headerBar.leadingAnchor.constraint(equalTo: rightContainer.leadingAnchor),
            headerBar.trailingAnchor.constraint(equalTo: rightContainer.trailingAnchor),

            expandButton.centerYAnchor.constraint(equalTo: headerBar.centerYAnchor),
            expandButton.leadingAnchor.constraint(equalTo: headerBar.leadingAnchor, constant: 8),
            expandButton.widthAnchor.constraint(equalToConstant: 22),
            expandButton.heightAnchor.constraint(equalToConstant: 22),

            headerConnectionDropdown.centerYAnchor.constraint(equalTo: headerBar.centerYAnchor),
            headerConnectionDropdown.leadingAnchor.constraint(equalTo: expandButton.trailingAnchor, constant: 4),
            headerConnectionDropdown.heightAnchor.constraint(equalToConstant: 22),

            headerSpinner.centerYAnchor.constraint(equalTo: headerBar.centerYAnchor),
            headerSpinner.leadingAnchor.constraint(equalTo: headerConnectionDropdown.trailingAnchor, constant: 6),

            innerSplitView.topAnchor.constraint(equalTo: headerBar.bottomAnchor),
            innerSplitView.leadingAnchor.constraint(equalTo: rightContainer.leadingAnchor),
            innerSplitView.trailingAnchor.constraint(equalTo: rightContainer.trailingAnchor),
            innerSplitView.bottomAnchor.constraint(equalTo: rightContainer.bottomAnchor),
        ])

        setupAxisConfigPanel()
        setupChartPanel()

        // Axis config holds its width, chart preview expands
        innerSplitView.setHoldingPriority(.defaultHigh, forSubviewAt: 0)
        innerSplitView.setHoldingPriority(.defaultLow, forSubviewAt: 1)

        splitView.addSubview(rightContainer)
        rightContainer.frame = NSRect(x: Self.leftPanelWidth, y: 0, width: 600, height: 380)
    }

    // MARK: - Column Panel (Left)

    private func setupColumnPanel() {
        let container = NSView()
        container.wantsLayer = true

        let hPad: CGFloat = 14

        connectionDropdown = SourceDropdownButton(
            connections: connections,
            onSelect: { [weak self] connection in
                guard let self else { return }
                Task { await self.viewModel.connectToSource(connection) }
            }
        )
        connectionDropdown.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(connectionDropdown)

        if let cfg = viewModel.config, !cfg.connectionName.isEmpty {
            let iconName = DatabaseType(rawValue: cfg.databaseType)?.icon
            connectionDropdown.updateLabel(cfg.connectionName, iconName: iconName)
        }

        connectionSpinner = NSProgressIndicator()
        connectionSpinner.style = .spinning
        connectionSpinner.controlSize = .mini
        connectionSpinner.isHidden = true
        connectionSpinner.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(connectionSpinner)

        collapseButton = HoverIconButton(symbolName: "rectangle.leftthird.inset.filled", target: self, action: #selector(toggleColumnPanel))
        collapseButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(collapseButton)

        let tableLabel = NSTextField(labelWithString: "Table")
        tableLabel.font = .systemFont(ofSize: 9, weight: .semibold)
        tableLabel.textColor = .tertiaryLabelColor
        tableLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(tableLabel)

        tableDropdown = StyledDropdown(placeholder: "Select a table") { [weak self] title in
            self?.viewModel.confirmTableSelection(tableName: title)
        }
        tableDropdown.translatesAutoresizingMaskIntoConstraints = false
        tableDropdown.isEnabled = false
        container.addSubview(tableDropdown)
        rebuildTableDropdown()

        schemaLabel = NSTextField(labelWithString: "Schema")
        schemaLabel.font = .systemFont(ofSize: 9, weight: .semibold)
        schemaLabel.textColor = .tertiaryLabelColor
        schemaLabel.translatesAutoresizingMaskIntoConstraints = false
        schemaLabel.isHidden = true
        container.addSubview(schemaLabel)

        schemaDropdown = StyledDropdown(placeholder: "Select schema") { [weak self] title in
            Task { await self?.viewModel.loadCollections(schema: title) }
        }
        schemaDropdown.translatesAutoresizingMaskIntoConstraints = false
        schemaDropdown.isHidden = true
        container.addSubview(schemaDropdown)

        let fieldsLabel = NSTextField(labelWithString: "Fields")
        fieldsLabel.font = .systemFont(ofSize: 9, weight: .semibold)
        fieldsLabel.textColor = .tertiaryLabelColor
        fieldsLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(fieldsLabel)

        fieldsStackView = NSStackView()
        fieldsStackView.orientation = .vertical
        fieldsStackView.alignment = .leading
        fieldsStackView.spacing = 0
        fieldsStackView.translatesAutoresizingMaskIntoConstraints = false

        let fieldsDocumentView = FlippedContentView()
        fieldsDocumentView.translatesAutoresizingMaskIntoConstraints = false
        fieldsDocumentView.addSubview(fieldsStackView)

        let scrollView = NSScrollView()
        scrollView.documentView = fieldsDocumentView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(scrollView)

        NSLayoutConstraint.activate([
            fieldsStackView.topAnchor.constraint(equalTo: fieldsDocumentView.topAnchor),
            fieldsStackView.leadingAnchor.constraint(equalTo: fieldsDocumentView.leadingAnchor),
            fieldsStackView.trailingAnchor.constraint(equalTo: fieldsDocumentView.trailingAnchor),
            fieldsStackView.bottomAnchor.constraint(equalTo: fieldsDocumentView.bottomAnchor),
            fieldsDocumentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
        ])

        let fieldsTopToSchema = fieldsLabel.topAnchor.constraint(equalTo: schemaDropdown.bottomAnchor, constant: 10)
        fieldsTopToSchema.isActive = false
        fieldsLabelTopToSchemaConstraint = fieldsTopToSchema

        let fieldsTopToTable = fieldsLabel.topAnchor.constraint(equalTo: tableDropdown.bottomAnchor, constant: 10)
        fieldsTopToTable.isActive = true
        fieldsLabelTopToTableConstraint = fieldsTopToTable

        NSLayoutConstraint.activate([
            collapseButton.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),
            collapseButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -(hPad - 2)),
            collapseButton.widthAnchor.constraint(equalToConstant: 22),
            collapseButton.heightAnchor.constraint(equalToConstant: 22),

            connectionDropdown.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),
            connectionDropdown.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: hPad - 2),
            connectionDropdown.heightAnchor.constraint(equalToConstant: 24),

            connectionSpinner.centerYAnchor.constraint(equalTo: connectionDropdown.centerYAnchor),
            connectionSpinner.leadingAnchor.constraint(equalTo: connectionDropdown.trailingAnchor, constant: 6),

            tableLabel.topAnchor.constraint(equalTo: connectionDropdown.bottomAnchor, constant: 14),
            tableLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: hPad),

            tableDropdown.topAnchor.constraint(equalTo: tableLabel.bottomAnchor, constant: 4),
            tableDropdown.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: hPad - 2),
            tableDropdown.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -(hPad - 2)),

            schemaLabel.topAnchor.constraint(equalTo: tableDropdown.bottomAnchor, constant: 14),
            schemaLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: hPad),

            schemaDropdown.topAnchor.constraint(equalTo: schemaLabel.bottomAnchor, constant: 4),
            schemaDropdown.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: hPad - 2),
            schemaDropdown.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -(hPad - 2)),

            fieldsLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: hPad),

            scrollView.topAnchor.constraint(equalTo: fieldsLabel.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: hPad - 2),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -(hPad - 2)),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        rebuildFieldsList()

        splitView.addSubview(container)
        container.frame = NSRect(x: 0, y: 0, width: Self.leftPanelWidth, height: 380)
        columnPanelContainer = container
    }

    private var isColumnPanelCollapsed = false

    @objc private func toggleColumnPanel() {
        isColumnPanelCollapsed.toggle()
        splitView.hideDivider = isColumnPanelCollapsed
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            context.allowsImplicitAnimation = true
            if self.isColumnPanelCollapsed {
                self.splitView.setPosition(0, ofDividerAt: 0)
            } else {
                self.splitView.setPosition(Self.leftPanelWidth, ofDividerAt: 0)
            }
        }
        splitView.needsDisplay = true
        expandButton.isHidden = !isColumnPanelCollapsed
        headerConnectionDropdown.isHidden = !isColumnPanelCollapsed
    }

    private func updateSchemaVisibility() {
        let schemas = viewModel.availableSchemas
        let hasSchemas = !schemas.isEmpty

        schemaLabel.isHidden = !hasSchemas
        schemaDropdown.isHidden = !hasSchemas

        if hasSchemas {
            let items = schemas.map(\.name)
            schemaDropdown.setItems(items)
            if let selected = viewModel.selectedPickerSchema {
                schemaDropdown.selectItem(selected)
            }
            fieldsLabelTopToTableConstraint?.isActive = false
            fieldsLabelTopToSchemaConstraint?.isActive = true
        } else {
            fieldsLabelTopToSchemaConstraint?.isActive = false
            fieldsLabelTopToTableConstraint?.isActive = true
        }
    }

    // MARK: - Axis Config Panel (Center)

    private func setupAxisConfigPanel() {
        let container = NSView()
        container.wantsLayer = true

        let hPad: CGFloat = 14

        // X-axis
        let xLabel = NSTextField(labelWithString: "X-axis")
        xLabel.font = .systemFont(ofSize: 9, weight: .semibold)
        xLabel.textColor = .tertiaryLabelColor
        xLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(xLabel)

        xAxisPopUp = StyledDropdown(placeholder: "Select column") { [weak self] title in
            self?.viewModel.setXAxis(title)
        }
        xAxisPopUp.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(xAxisPopUp)

        // Y-axis
        let yLabel = NSTextField(labelWithString: "Y-axis")
        yLabel.font = .systemFont(ofSize: 9, weight: .semibold)
        yLabel.textColor = .tertiaryLabelColor
        yLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(yLabel)

        yAxisPopUp = StyledDropdown(placeholder: "Select column") { [weak self] title in
            self?.viewModel.setYAxis(title)
        }
        yAxisPopUp.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(yAxisPopUp)

        NSLayoutConstraint.activate([
            xLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),
            xLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: hPad),

            xAxisPopUp.topAnchor.constraint(equalTo: xLabel.bottomAnchor, constant: 4),
            xAxisPopUp.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: hPad - 2),
            xAxisPopUp.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -(hPad - 2)),

            yLabel.topAnchor.constraint(equalTo: xAxisPopUp.bottomAnchor, constant: 14),
            yLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: hPad),

            yAxisPopUp.topAnchor.constraint(equalTo: yLabel.bottomAnchor, constant: 4),
            yAxisPopUp.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: hPad - 2),
            yAxisPopUp.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -(hPad - 2)),
        ])

        innerSplitView.addSubview(container)
        container.frame = NSRect(x: 0, y: 0, width: Self.centerPanelWidth, height: 380)
    }

    private func rebuildTableDropdown() {
        let collections = viewModel.availableCollections
        if collections.isEmpty {
            tableDropdown.setItems([])
            tableDropdown.isEnabled = false
        } else {
            tableDropdown.setItems(collections.map(\.name))
            tableDropdown.isEnabled = true
            if let cfg = viewModel.config, !cfg.tableName.isEmpty {
                tableDropdown.selectItem(cfg.tableName)
            }
        }
    }

    // MARK: - Chart Panel (Right)

    private func setupChartPanel() {
        let container = NSView()
        container.wantsLayer = true

        let chartView = ChartPreviewView(viewModel: viewModel)
        let hosting = NSHostingView(rootView: AnyView(chartView))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hosting)
        chartHostingView = hosting

        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: container.topAnchor),
            hosting.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hosting.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        innerSplitView.addSubview(container)
        container.frame = NSRect(x: Self.centerPanelWidth, y: 0, width: 400, height: 380)
    }

    // MARK: - Observation

    private func observeSchema() {
        withObservationTracking {
            _ = self.viewModel.schemaResult
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.rebuildFieldsList()
                self.rebuildAxisPopups()
                self.observeSchema()
            }
        }
    }

    private func observeConnecting() {
        withObservationTracking {
            _ = self.viewModel.isConnecting
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.updateConnectionState()
                self.observeConnecting()
            }
        }
    }

    private func updateConnectionState() {
        let connecting = viewModel.isConnecting
        connectionDropdown.isEnabled = !connecting
        if connecting {
            connectionSpinner.isHidden = false
            connectionSpinner.startAnimation(nil)
            headerSpinner.isHidden = false
            headerSpinner.startAnimation(nil)
        } else {
            connectionSpinner.stopAnimation(nil)
            connectionSpinner.isHidden = true
            headerSpinner.stopAnimation(nil)
            headerSpinner.isHidden = true
        }
        if let cfg = viewModel.config, !cfg.connectionName.isEmpty {
            let iconName = DatabaseType(rawValue: cfg.databaseType)?.icon
            connectionDropdown.updateLabel(cfg.connectionName, iconName: iconName)
            headerConnectionDropdown.updateLabel(cfg.connectionName, iconName: iconName)
        }
    }

    private func observeCollections() {
        withObservationTracking {
            _ = self.viewModel.availableCollections.count
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.rebuildTableDropdown()
                self.observeCollections()
            }
        }
    }

    private func observeSchemas() {
        withObservationTracking {
            _ = self.viewModel.availableSchemas.count
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.updateSchemaVisibility()
                self.observeSchemas()
            }
        }
    }

    private func observeChartData() {
        withObservationTracking {
            _ = self.viewModel.chartData.count
            _ = self.viewModel.isLoadingChart
            _ = self.viewModel.chartError
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.observeChartData()
            }
        }
    }

    private func rebuildAxisPopups() {
        guard let schema = viewModel.schemaResult else { return }
        let allColumns = schema.columns.map(\.columnName)
        let measureColumns = viewModel.measureColumns.map(\.columnName)

        xAxisPopUp.setItems(allColumns)
        if let selected = viewModel.config?.xAxisColumn {
            xAxisPopUp.selectItem(selected)
        }

        yAxisPopUp.setItems(measureColumns)
        if let selected = viewModel.config?.yAxisColumn {
            yAxisPopUp.selectItem(selected)
        }
    }

    private var displayedColumns: [DatabaseSchemaInfo] {
        viewModel.schemaResult?.columns ?? []
    }

    private func iconName(for column: DatabaseSchemaInfo) -> String {
        if viewModel.isNumericColumn(column) {
            return "number"
        }
        let type = column.dataType.lowercased()
        if type.contains("date") || type.contains("time") || type.contains("timestamp") {
            return "calendar"
        }
        if type.contains("bool") {
            return "checkmark.circle"
        }
        return "textformat"
    }

    private func rebuildFieldsList() {
        guard fieldsStackView != nil else { return }

        for subview in fieldsStackView.arrangedSubviews {
            fieldsStackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }

        for info in displayedColumns {
            let row = FieldRowCell()
            row.translatesAutoresizingMaskIntoConstraints = false
            row.configure(name: info.columnName, iconName: iconName(for: info), dataType: info.dataType)
            fieldsStackView.addArrangedSubview(row)
            NSLayoutConstraint.activate([
                row.leadingAnchor.constraint(equalTo: fieldsStackView.leadingAnchor),
                row.trailingAnchor.constraint(equalTo: fieldsStackView.trailingAnchor),
                row.heightAnchor.constraint(equalToConstant: 26),
            ])
        }
    }
}

// MARK: - NSSplitViewDelegate

extension ChartConfigController: NSSplitViewDelegate {
    func splitView(_ sv: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        if sv === splitView {
            return isColumnPanelCollapsed ? 0 : Self.leftPanelWidth
        }
        if sv === innerSplitView {
            return Self.centerPanelWidth
        }
        return proposedMinimumPosition
    }

    func splitView(_ sv: NSSplitView, canCollapseSubview subview: NSView) -> Bool {
        if sv === splitView, subview === columnPanelContainer {
            return true
        }
        return false
    }

    func splitView(_ sv: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        return proposedMaximumPosition
    }

}

// MARK: - Field Row Cell (matches sidebar table row style)

private final class FieldRowCell: NSTableCellView {

    private let hoverBackground = NSView()
    private let iconView = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let typeLabel = NSTextField(labelWithString: "")
    private var trackingArea: NSTrackingArea?
    private var isHovering = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func setupViews() {
        hoverBackground.wantsLayer = true
        hoverBackground.layer?.cornerRadius = 6
        hoverBackground.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hoverBackground)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.symbolConfiguration = .init(pointSize: 11, weight: .regular)
        iconView.alphaValue = 0.7
        addSubview(iconView)

        nameLabel.font = .systemFont(ofSize: 12)
        nameLabel.textColor = .labelColor
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(nameLabel)

        typeLabel.font = .systemFont(ofSize: 9)
        typeLabel.textColor = .tertiaryLabelColor
        typeLabel.alignment = .right
        typeLabel.lineBreakMode = .byTruncatingTail
        typeLabel.translatesAutoresizingMaskIntoConstraints = false
        typeLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        addSubview(typeLabel)

        NSLayoutConstraint.activate([
            hoverBackground.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            hoverBackground.leadingAnchor.constraint(equalTo: leadingAnchor),
            hoverBackground.trailingAnchor.constraint(equalTo: trailingAnchor),
            hoverBackground.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -1),

            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 14),
            iconView.heightAnchor.constraint(equalToConstant: 14),

            nameLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 6),
            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            typeLabel.leadingAnchor.constraint(greaterThanOrEqualTo: nameLabel.trailingAnchor, constant: 4),
            typeLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            typeLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            typeLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 60),
        ])
    }

    func configure(name: String, iconName: String, dataType: String) {
        nameLabel.stringValue = name
        iconView.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
        iconView.contentTintColor = .secondaryLabelColor
        typeLabel.stringValue = dataType.lowercased()
    }

    // MARK: - Hover

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea { removeTrackingArea(existing) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp],
            owner: self
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        updateHover()
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        updateHover()
    }

    private func updateHover() {
        if isHovering {
            let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            hoverBackground.layer?.backgroundColor = isDark
                ? NSColor.white.withAlphaComponent(0.06).cgColor
                : NSColor.black.withAlphaComponent(0.04).cgColor
        } else {
            hoverBackground.layer?.backgroundColor = nil
        }
    }
}

private final class FlippedContentView: NSView {
    override var isFlipped: Bool { true }
}

// MARK: - Collapsible Split View

private final class CollapsibleSplitView: NSSplitView {
    var hideDivider = false

    override var dividerThickness: CGFloat {
        hideDivider ? 0 : super.dividerThickness
    }

    override func drawDivider(in rect: NSRect) {
        if hideDivider { return }
        super.drawDivider(in: rect)
    }
}

// MARK: - Hover Icon Button

private final class HoverIconButton: NSView {

    private let iconView: NSImageView
    private let action: Selector
    private weak var target: AnyObject?
    private var trackingArea: NSTrackingArea?
    private var isHovering = false

    init(symbolName: String, target: AnyObject, action: Selector) {
        self.iconView = NSImageView()
        self.target = target
        self.action = action
        super.init(frame: .zero)

        wantsLayer = true
        layer?.cornerRadius = 6

        iconView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        iconView.symbolConfiguration = .init(pointSize: 11, weight: .medium)
        iconView.contentTintColor = .tertiaryLabelColor
        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)

        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var isHidden: Bool {
        didSet {
            if isHidden && isHovering {
                isHovering = false
                updateHover()
            }
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea { removeTrackingArea(existing) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp],
            owner: self
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        updateHover()
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        updateHover()
    }

    override func mouseDown(with event: NSEvent) {
        _ = target?.perform(action, with: self)
    }

    private func updateHover() {
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        if isHovering {
            layer?.backgroundColor = isDark
                ? NSColor.white.withAlphaComponent(0.06).cgColor
                : NSColor.black.withAlphaComponent(0.04).cgColor
        } else {
            layer?.backgroundColor = nil
        }
    }
}

// MARK: - Chart Preview (SwiftUI, embedded via NSHostingView)

private struct ChartPreviewView: View {
    var viewModel: ChartBlockViewModel

    var body: some View {
        Group {
            if viewModel.isLoadingChart {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Loading chart data...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if let error = viewModel.chartError {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else if viewModel.chartData.isEmpty {
                ChartEmptyStateView(
                    xAxisColumn: viewModel.config?.xAxisColumn,
                    yAxisColumn: viewModel.config?.yAxisColumn
                )
            } else {
                BarChartView(data: viewModel.chartData)
                    .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Chart Empty State

private struct ChartEmptyStateView: View {
    let xAxisColumn: String?
    let yAxisColumn: String?

    private let axisInset: CGFloat = 52
    private let gridSpacing: CGFloat = 28

    var body: some View {
        GeometryReader { geo in
            let originX = axisInset
            let originY = geo.size.height - axisInset
            let endX = geo.size.width - 12
            let endY: CGFloat = 12

            Canvas { context, size in
                drawGrid(context: context, originX: originX, originY: originY, endX: endX, endY: endY)
                drawAxes(context: context, originX: originX, originY: originY, endX: endX, endY: endY)
            }

            // Y-axis label
            yAxisLabel
                .position(x: axisInset / 2, y: geo.size.height / 2)

            // X-axis label
            xAxisLabel
                .position(x: (originX + endX) / 2, y: originY + (axisInset / 2) + 2)

        }
    }

    // MARK: - Grid

    private func drawGrid(context: GraphicsContext, originX: CGFloat, originY: CGFloat, endX: CGFloat, endY: CGFloat) {
        var gridPath = Path()

        var x = originX + gridSpacing
        while x < endX {
            gridPath.move(to: CGPoint(x: x, y: endY))
            gridPath.addLine(to: CGPoint(x: x, y: originY))
            x += gridSpacing
        }

        var y = originY - gridSpacing
        while y > endY {
            gridPath.move(to: CGPoint(x: originX, y: y))
            gridPath.addLine(to: CGPoint(x: endX, y: y))
            y -= gridSpacing
        }

        context.stroke(gridPath, with: .color(.secondary.opacity(0.08)), lineWidth: 0.5)
    }

    // MARK: - Axes

    private func drawAxes(context: GraphicsContext, originX: CGFloat, originY: CGFloat, endX: CGFloat, endY: CGFloat) {
        let axisColor = Color.secondary.opacity(0.3)
        let dashStyle = StrokeStyle(lineWidth: 1, dash: [6, 4])

        // Y-axis
        var yAxis = Path()
        yAxis.move(to: CGPoint(x: originX, y: originY))
        yAxis.addLine(to: CGPoint(x: originX, y: endY))
        context.stroke(yAxis, with: .color(axisColor), style: dashStyle)

        // Y arrow
        var yArrow = Path()
        yArrow.move(to: CGPoint(x: originX - 5, y: endY + 8))
        yArrow.addLine(to: CGPoint(x: originX, y: endY))
        yArrow.addLine(to: CGPoint(x: originX + 5, y: endY + 8))
        context.stroke(yArrow, with: .color(axisColor), style: StrokeStyle(lineWidth: 1))

        // X-axis
        var xAxis = Path()
        xAxis.move(to: CGPoint(x: originX, y: originY))
        xAxis.addLine(to: CGPoint(x: endX, y: originY))
        context.stroke(xAxis, with: .color(axisColor), style: dashStyle)

        // X arrow
        var xArrow = Path()
        xArrow.move(to: CGPoint(x: endX - 8, y: originY - 5))
        xArrow.addLine(to: CGPoint(x: endX, y: originY))
        xArrow.addLine(to: CGPoint(x: endX - 8, y: originY + 5))
        context.stroke(xArrow, with: .color(axisColor), style: StrokeStyle(lineWidth: 1))
    }

    // MARK: - Labels

    @ViewBuilder
    private var yAxisLabel: some View {
        if let col = yAxisColumn {
            axisTag(col)
                .rotationEffect(.degrees(-90))
        } else {
            Text("No Y-axis")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .foregroundStyle(.quaternary)
                )
                .rotationEffect(.degrees(-90))
        }
    }

    @ViewBuilder
    private var xAxisLabel: some View {
        HStack(spacing: 6) {
            if let col = xAxisColumn {
                Text("X-axis")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                axisTag(col)
            } else {
                Text("No X-axis")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                            .foregroundStyle(.quaternary)
                    )
            }
        }
    }

    private func axisTag(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quinary)
            .clipShape(.rect(cornerRadius: 4))
    }

}
