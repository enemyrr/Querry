import AppKit
import SwiftUI

final class SingleValueConfigController: NSViewController {

    private let viewModel: SingleValueBlockViewModel
    private let connections: [Connection]

    private var connectionPickerView: NSView?
    private var pickerDropdownRef: ConnectionPickerDropdown?
    private var singleValueHostingView: NSHostingView<AnyView>?

    init(viewModel: SingleValueBlockViewModel, connections: [Connection]) {
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

        if viewModel.config != nil {
            setupSingleValueDisplay()
        }

        observeConfig()
    }

    // MARK: - Connection Picker

    private func setupConnectionPicker() {
        let picker = NSView()
        picker.wantsLayer = true
        picker.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(picker)

        NSLayoutConstraint.activate([
            picker.topAnchor.constraint(equalTo: view.topAnchor),
            picker.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            picker.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            picker.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        let artwork = NotebookArtworkView()
        artwork.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "Start by selecting a data source")
        title.font = .systemFont(ofSize: 14, weight: .semibold)
        title.textColor = .labelColor
        title.alignment = .center

        let pickerDropdown = ConnectionPickerDropdown(
            connections: connections,
            onSelect: { [weak self] connection in
                guard let self else { return }
                Task { await self.viewModel.connectToSource(connection) }
            }
        )
        pickerDropdown.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [artwork, title, pickerDropdown])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        picker.addSubview(stack)

        NSLayoutConstraint.activate([
            artwork.widthAnchor.constraint(equalToConstant: 80),
            artwork.heightAnchor.constraint(equalToConstant: 80),
            pickerDropdown.widthAnchor.constraint(equalToConstant: 260),
            stack.centerXAnchor.constraint(equalTo: picker.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: picker.centerYAnchor, constant: -20),
        ])

        connectionPickerView = picker
        pickerDropdownRef = pickerDropdown
    }

    private func dismissConnectionPicker() {
        guard let picker = connectionPickerView else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            picker.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            picker.removeFromSuperview()
            self?.connectionPickerView = nil
            self?.setupSingleValueDisplay()
        }
    }

    // MARK: - Single Value Display

    private func setupSingleValueDisplay() {
        guard singleValueHostingView == nil else { return }

        let displayView = SingleValueDisplayView(viewModel: viewModel)
        let hosting = NSHostingView(rootView: AnyView(displayView))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hosting)
        singleValueHostingView = hosting

        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - Observation

    private func observeConfig() {
        withObservationTracking {
            _ = self.viewModel.config
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.viewModel.config != nil, self.connectionPickerView != nil {
                    self.dismissConnectionPicker()
                }
                self.observeConfig()
            }
        }
    }
}

// MARK: - Config Popover Controller

final class SingleValueConfigPopoverController: NSViewController {

    private let viewModel: SingleValueBlockViewModel
    private let connections: [Connection]

    init(viewModel: SingleValueBlockViewModel, connections: [Connection]) {
        self.viewModel = viewModel
        self.connections = connections
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        let container = NSView()
        container.wantsLayer = true
        container.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            container.widthAnchor.constraint(equalToConstant: 260),
        ])

        addConnectionRow(to: stack)

        if !viewModel.availableSchemas.isEmpty {
            addSchemaRow(to: stack)
        }

        if !viewModel.availableEnvironments.isEmpty {
            addEnvironmentRow(to: stack)
        }

        addTableRow(to: stack)
        addColumnRow(to: stack)
        addAggregationRow(to: stack)

        self.view = container
    }

    // MARK: - Rows

    private func addConnectionRow(to stack: NSStackView) {
        let label = sectionLabel("Connection")
        let dropdown = SourceDropdownButton(
            connections: connections,
            onSelect: { [weak self] connection in
                guard let self else { return }
                Task { await self.viewModel.connectToSource(connection) }
            }
        )
        dropdown.translatesAutoresizingMaskIntoConstraints = false

        if let cfg = viewModel.config, !cfg.connectionName.isEmpty {
            let iconName = DatabaseType(rawValue: cfg.databaseType)?.icon
            dropdown.updateLabel(cfg.connectionName, iconName: iconName)
        }

        stack.addArrangedSubview(label)
        stack.addArrangedSubview(dropdown)
        pinWidth(dropdown, to: stack)
    }

    private func addSchemaRow(to stack: NSStackView) {
        let label = sectionLabel("Schema")
        let dropdown = StyledDropdown(placeholder: "Select schema") { [weak self] schema in
            guard let self else { return }
            Task { await self.viewModel.loadCollections(schema: schema) }
        }
        dropdown.translatesAutoresizingMaskIntoConstraints = false
        dropdown.setItems(viewModel.availableSchemas.map(\.name))
        if let selected = viewModel.selectedPickerSchema {
            dropdown.selectItem(selected)
        }

        stack.addArrangedSubview(label)
        stack.addArrangedSubview(dropdown)
        pinWidth(dropdown, to: stack)
    }

    private func addEnvironmentRow(to stack: NSStackView) {
        let label = sectionLabel("Environment")
        let dropdown = StyledDropdown(placeholder: "Select environment") { [weak self] env in
            guard let self else { return }
            Task { await self.viewModel.switchEnvironment(env) }
        }
        dropdown.translatesAutoresizingMaskIntoConstraints = false
        dropdown.setItems(viewModel.availableEnvironments)
        if let selected = viewModel.selectedEnvironment {
            dropdown.selectItem(selected)
        }

        stack.addArrangedSubview(label)
        stack.addArrangedSubview(dropdown)
        pinWidth(dropdown, to: stack)
    }

    private func addTableRow(to stack: NSStackView) {
        let label = sectionLabel("Table")
        let dropdown = StyledDropdown(placeholder: "Select table") { [weak self] table in
            self?.viewModel.confirmTableSelection(tableName: table)
        }
        dropdown.translatesAutoresizingMaskIntoConstraints = false
        dropdown.setItems(viewModel.availableCollections.map(\.name))
        if let tableName = viewModel.config?.tableName, !tableName.isEmpty {
            dropdown.selectItem(tableName)
        }

        stack.addArrangedSubview(label)
        stack.addArrangedSubview(dropdown)
        pinWidth(dropdown, to: stack)
    }

    private func addColumnRow(to stack: NSStackView) {
        let label = sectionLabel("Column")
        let columns = viewModel.schemaResult?.columns.map(\.columnName) ?? []
        let dropdown = StyledDropdown(placeholder: "Select column") { [weak self] column in
            self?.viewModel.setColumn(column)
        }
        dropdown.translatesAutoresizingMaskIntoConstraints = false
        dropdown.setItems(columns)
        if let column = viewModel.config?.column {
            dropdown.selectItem(column)
        }

        stack.addArrangedSubview(label)
        stack.addArrangedSubview(dropdown)
        pinWidth(dropdown, to: stack)
    }

    private func addAggregationRow(to stack: NSStackView) {
        let label = sectionLabel("Aggregation")
        let allAggs = AggregationFunction.allCases

        let selectedColumn = viewModel.config?.column
        let dataType = viewModel.schemaResult?.columns.first(where: { $0.columnName == selectedColumn })?.dataType

        let availableAggs: [AggregationFunction]
        if let dataType {
            availableAggs = AggregationFunction.availableAggregations(for: dataType)
        } else {
            availableAggs = allAggs
        }

        let dropdown = StyledDropdown(placeholder: "Select aggregation") { [weak self] aggName in
            guard let agg = AggregationFunction.allCases.first(where: { $0.displayName == aggName }) else { return }
            self?.viewModel.setAggregation(agg)
        }
        dropdown.translatesAutoresizingMaskIntoConstraints = false
        dropdown.setItems(availableAggs.map(\.displayName))

        if let currentAgg = viewModel.config?.aggregation {
            dropdown.selectItem(currentAgg.displayName)
        }

        stack.addArrangedSubview(label)
        stack.addArrangedSubview(dropdown)
        pinWidth(dropdown, to: stack)
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .tertiaryLabelColor
        return label
    }

    private func pinWidth(_ subview: NSView, to stack: NSStackView) {
        NSLayoutConstraint.activate([
            subview.leadingAnchor.constraint(equalTo: stack.leadingAnchor, constant: 12),
            subview.trailingAnchor.constraint(equalTo: stack.trailingAnchor, constant: -12),
        ])
    }
}

// MARK: - Single Value Display View (SwiftUI)

struct SingleValueDisplayView: View {
    @Bindable var viewModel: SingleValueBlockViewModel
    @State private var labelText: String = ""

    var body: some View {
        VStack(spacing: 8) {
            if viewModel.isLoadingSingleValue {
                ProgressView()
                    .controlSize(.small)
            } else if let error = viewModel.singleValueError {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else if let value = viewModel.singleValueResult {
                Text(formattedValue(value))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())

                TextField("Add label", text: $labelText)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.plain)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 200)
                    .onSubmit {
                        viewModel.setLabel(labelText)
                    }
                    .onChange(of: labelText) {
                        viewModel.setLabel(labelText)
                    }
                    .onChange(of: viewModel.config?.label) { _, newValue in
                        let incoming = newValue ?? ""
                        if incoming != labelText {
                            labelText = incoming
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            labelText = viewModel.config?.label ?? ""
        }
    }

    private func formattedValue(_ value: Double) -> String {
        if value >= 1_000_000 {
            return (value / 1_000_000).formatted(.number.precision(.fractionLength(1))) + "M"
        } else if value >= 10_000 {
            return (value / 1_000).formatted(.number.precision(.fractionLength(0))) + "K"
        } else if value >= 1_000 {
            return (value / 1_000).formatted(.number.precision(.fractionLength(1))) + "K"
        } else if value == value.rounded() {
            return Int(value).formatted(.number)
        } else {
            return value.formatted(.number.precision(.fractionLength(2)))
        }
    }
}
