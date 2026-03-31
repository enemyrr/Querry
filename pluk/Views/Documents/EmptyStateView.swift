import AppKit

final class EmptyStateViewController: NSViewController, NSTextFieldDelegate {

    private let instance: ConnectionInstance

    // Search bar
    private let searchField = NSTextField()
    private let searchIcon = NSImageView()
    private let clearButton = NSButton()
    private let searchContainer = NSView()

    // Recent files (plain, no bg/border)
    private let recentHeaderLabel = NSTextField(labelWithString: "Recent Files")
    private let recentHeaderStack = NSStackView()
    private let recentStackView = NSStackView()

    // Search dropdown (with bg + border container)
    private let dropdownContainer = NSView()
    private let resultsHeaderLabel = NSTextField(labelWithString: "Top matches")
    private let dropdownScrollView = NSScrollView()
    private let dropdownStackView = NSStackView()

    private let noResultsLabel = NSTextField(labelWithString: "No results")

    private var activeIndex = 0
    private var eventMonitor: Any?
    private var dropdownHeightConstraint: NSLayoutConstraint?
    private var appearanceObservation: NSKeyValueObservation?

    init(instance: ConnectionInstance) {
        self.instance = instance
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        let root = NSView()
        root.wantsLayer = true
        self.view = root

        setupSearchBar()
        setupRecentArea()
        setupDropdownArea()
        setupLayout()
        setupEventMonitor()
    }

    // MARK: - Search Bar

    private func setupSearchBar() {
        searchContainer.wantsLayer = true
        searchContainer.layer?.cornerRadius = 12
        searchContainer.layer?.borderWidth = 1
        searchContainer.translatesAutoresizingMaskIntoConstraints = false
        updateContainerAppearance(searchContainer)

        searchIcon.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil)
        searchIcon.contentTintColor = .secondaryLabelColor
        searchIcon.translatesAutoresizingMaskIntoConstraints = false
        searchIcon.setContentHuggingPriority(.required, for: .horizontal)

        searchField.placeholderString = "Open Quickly"
        searchField.font = .systemFont(ofSize: 17)
        searchField.isBezeled = false
        searchField.drawsBackground = false
        searchField.focusRingType = .none
        searchField.delegate = self
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        searchField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        clearButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Clear")
        clearButton.contentTintColor = .secondaryLabelColor
        clearButton.isBordered = false
        clearButton.target = self
        clearButton.action = #selector(clearSearch)
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        clearButton.isHidden = true

        searchContainer.addSubview(searchIcon)
        searchContainer.addSubview(searchField)
        searchContainer.addSubview(clearButton)

        NSLayoutConstraint.activate([
            searchIcon.leadingAnchor.constraint(equalTo: searchContainer.leadingAnchor, constant: 16),
            searchIcon.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),
            searchIcon.widthAnchor.constraint(equalToConstant: 16),
            searchIcon.heightAnchor.constraint(equalToConstant: 16),

            searchField.leadingAnchor.constraint(equalTo: searchIcon.trailingAnchor, constant: 8),
            searchField.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),
            searchField.trailingAnchor.constraint(equalTo: clearButton.leadingAnchor, constant: -4),

            clearButton.trailingAnchor.constraint(equalTo: searchContainer.trailingAnchor, constant: -12),
            clearButton.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),
            clearButton.widthAnchor.constraint(equalToConstant: 20),
            clearButton.heightAnchor.constraint(equalToConstant: 20),

            searchContainer.heightAnchor.constraint(equalToConstant: 48),
        ])
    }

    private func updateContainerAppearance(_ container: NSView) {
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        container.layer?.backgroundColor = isDark
            ? NSColor.white.withAlphaComponent(0.06).cgColor
            : NSColor.white.cgColor
        container.layer?.borderColor = NSColor.separatorColor.cgColor
    }

    // MARK: - Recent Files Area (plain, no container styling)

    private func setupRecentArea() {
        recentHeaderLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        recentHeaderLabel.textColor = .labelColor
        recentHeaderLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        recentHeaderLabel.translatesAutoresizingMaskIntoConstraints = false

        recentHeaderStack.orientation = .horizontal
        recentHeaderStack.distribution = .fill
        recentHeaderStack.addArrangedSubview(recentHeaderLabel)
        recentHeaderStack.translatesAutoresizingMaskIntoConstraints = false
        recentHeaderStack.edgeInsets = NSEdgeInsets(top: 14, left: 16, bottom: 10, right: 16)

        recentStackView.orientation = .vertical
        recentStackView.spacing = 4
        recentStackView.translatesAutoresizingMaskIntoConstraints = false
    }

    // MARK: - Search Dropdown Area (with bg + border)

    private func setupDropdownArea() {
        dropdownContainer.wantsLayer = true
        dropdownContainer.layer?.cornerRadius = 12
        dropdownContainer.layer?.borderWidth = 0.5
        dropdownContainer.layer?.borderColor = NSColor.separatorColor.cgColor
        dropdownContainer.translatesAutoresizingMaskIntoConstraints = false
        updateContainerAppearance(dropdownContainer)

        resultsHeaderLabel.font = .preferredFont(forTextStyle: .callout)
        resultsHeaderLabel.textColor = .secondaryLabelColor
        resultsHeaderLabel.translatesAutoresizingMaskIntoConstraints = false

        dropdownStackView.orientation = .vertical
        dropdownStackView.spacing = 4
        dropdownStackView.translatesAutoresizingMaskIntoConstraints = false

        dropdownScrollView.contentView.drawsBackground = false
        dropdownScrollView.documentView = dropdownStackView
        dropdownScrollView.drawsBackground = false
        dropdownScrollView.hasVerticalScroller = true
        dropdownScrollView.autohidesScrollers = true
        dropdownScrollView.translatesAutoresizingMaskIntoConstraints = false

        noResultsLabel.font = .systemFont(ofSize: 13)
        noResultsLabel.textColor = .secondaryLabelColor
        noResultsLabel.alignment = .center
        noResultsLabel.translatesAutoresizingMaskIntoConstraints = false

        dropdownContainer.addSubview(resultsHeaderLabel)
        dropdownContainer.addSubview(dropdownScrollView)
        dropdownContainer.addSubview(noResultsLabel)
    }


    // MARK: - Layout

    private func setupLayout() {
        view.addSubview(searchContainer)
        view.addSubview(recentHeaderStack)
        view.addSubview(recentStackView)
        view.addSubview(dropdownContainer)

        NSLayoutConstraint.activate([
            searchContainer.topAnchor.constraint(equalTo: view.topAnchor),
            searchContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            // Recent header (plain)
            recentHeaderStack.topAnchor.constraint(equalTo: searchContainer.bottomAnchor, constant: 8),
            recentHeaderStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            recentHeaderStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            // Recent list
            recentStackView.topAnchor.constraint(equalTo: recentHeaderStack.bottomAnchor),
            recentStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            recentStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            recentStackView.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor),

            // Dropdown container (with bg + border)
            dropdownContainer.topAnchor.constraint(equalTo: searchContainer.bottomAnchor, constant: 12),
            dropdownContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dropdownContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dropdownContainer.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor),

            // Results header inside dropdown
            resultsHeaderLabel.topAnchor.constraint(equalTo: dropdownContainer.topAnchor, constant: 18),
            resultsHeaderLabel.leadingAnchor.constraint(equalTo: dropdownContainer.leadingAnchor, constant: 16),

            // Scroll view inside dropdown
            dropdownScrollView.topAnchor.constraint(equalTo: resultsHeaderLabel.bottomAnchor, constant: 8),
            dropdownScrollView.leadingAnchor.constraint(equalTo: dropdownContainer.leadingAnchor, constant: 8),
            dropdownScrollView.trailingAnchor.constraint(equalTo: dropdownContainer.trailingAnchor, constant: -2),
            dropdownScrollView.bottomAnchor.constraint(equalTo: dropdownContainer.bottomAnchor, constant: -8),

            dropdownStackView.widthAnchor.constraint(equalTo: dropdownScrollView.widthAnchor, constant: -6),

            // No results label inside dropdown
            noResultsLabel.topAnchor.constraint(equalTo: resultsHeaderLabel.bottomAnchor),
            noResultsLabel.centerXAnchor.constraint(equalTo: dropdownContainer.centerXAnchor),
            noResultsLabel.bottomAnchor.constraint(equalTo: dropdownContainer.bottomAnchor, constant: -35),
        ])
    }

    // MARK: - Content

    private var currentSearchQuery: String {
        if let editorText = searchField.currentEditor()?.string {
            return editorText
        }
        return searchField.stringValue
    }

    private func filteredCollections(matching searchQuery: String) -> [any CollectionWrapper] {
        guard !searchQuery.isEmpty else { return [] }
        guard let collections = instance.collections[instance.connectedDatabase?.name ?? ""] else {
            return []
        }
        return collections.filter { $0.name.localizedStandardContains(searchQuery) }
    }

    private func clearRows(in stackView: NSStackView) {
        for row in stackView.arrangedSubviews {
            stackView.removeArrangedSubview(row)
            row.removeFromSuperview()
        }
    }

    private func reloadContent() {
        clearRows(in: dropdownStackView)
        clearRows(in: recentStackView)

        let searchQuery = currentSearchQuery
        if !searchQuery.isEmpty {
            let collections = filteredCollections(matching: searchQuery)
            let hasResults = !collections.isEmpty

            // Hide recent, show dropdown container (for results or no-results)
            recentHeaderStack.isHidden = true
            recentStackView.isHidden = true
            dropdownContainer.isHidden = false
            resultsHeaderLabel.isHidden = !hasResults
            noResultsLabel.isHidden = hasResults
            dropdownScrollView.isHidden = !hasResults

            if activeIndex >= collections.count {
                activeIndex = 0
            }

            for (index, collection) in collections.enumerated() {
                let row = makeCollectionRow(
                    name: collection.name,
                    type: collection.type,
                    schema: collection.schema,
                    index: index,
                    isActive: index == activeIndex
                ) { [weak self] in
                    self?.openCollection(collection)
                }
                dropdownStackView.addArrangedSubview(row)
            }

            dropdownHeightConstraint?.isActive = false
            dropdownHeightConstraint = nil
            if hasResults {
                let maxHeight = min(CGFloat(collections.count) * 38 + CGFloat(collections.count - 1) * 4, 320)
                let constraint = dropdownScrollView.heightAnchor.constraint(equalToConstant: maxHeight)
                constraint.isActive = true
                dropdownHeightConstraint = constraint
            }

        } else {
            // Hide dropdown, show recent
            dropdownContainer.isHidden = true
            noResultsLabel.isHidden = true

            let recentTables = instance.recentTablesService?.fetchRecent(limit: 6) ?? []
            let hasRecent = !recentTables.isEmpty

            recentHeaderStack.isHidden = !hasRecent
            recentStackView.isHidden = !hasRecent

            for (index, entry) in recentTables.enumerated() {
                let row = makeCollectionRow(
                    name: entry.tableName,
                    type: entry.tableType,
                    schema: entry.schemaName,
                    index: index,
                    isActive: false
                ) { [weak self] in
                    self?.openRecentEntry(entry)
                }
                recentStackView.addArrangedSubview(row)
            }

        }

        view.needsLayout = true
        view.layoutSubtreeIfNeeded()
    }

    // MARK: - Row Builder

    private func makeCollectionRow(
        name: String,
        type: String,
        schema: String?,
        index: Int,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> NSView {
        let row = ClickableRowView(action: action)
        row.wantsLayer = true
        row.layer?.cornerRadius = 8
        row.translatesAutoresizingMaskIntoConstraints = false

        row.isActive = isActive
        if isActive {
            row.layer?.backgroundColor = NSColor.separatorColor.cgColor.copy(alpha: NSColor.separatorColor.alphaComponent * 0.5)
        }

        let icon = NSImageView()
        let symbolName = type == "view" ? "eye.fill" : "tablecells"
        icon.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        icon.contentTintColor = .secondaryLabelColor
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.setContentHuggingPriority(.required, for: .horizontal)

        let nameLabel = NSTextField(labelWithString: name)
        nameLabel.font = .systemFont(ofSize: 13)
        nameLabel.textColor = .labelColor
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.maximumNumberOfLines = 1
        nameLabel.cell?.truncatesLastVisibleLine = true
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        nameLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        let typeLabel = NSTextField(labelWithString: "")
        let cell = VerticallyCenteredTextFieldCell(textCell: type.capitalized)
        cell.font = .systemFont(ofSize: 11)
        cell.alignment = .center
        typeLabel.cell = cell
        typeLabel.font = .systemFont(ofSize: 11)
        typeLabel.textColor = .secondaryLabelColor
        typeLabel.alignment = .center
        typeLabel.isBezeled = false
        typeLabel.isEditable = false
        typeLabel.drawsBackground = false
        typeLabel.wantsLayer = true
        typeLabel.layer?.borderWidth = 1
        typeLabel.layer?.borderColor = NSColor.separatorColor.cgColor
        typeLabel.layer?.cornerRadius = 4
        typeLabel.translatesAutoresizingMaskIntoConstraints = false
        typeLabel.setContentHuggingPriority(.required, for: .horizontal)

        row.addSubview(icon)
        row.addSubview(nameLabel)
        row.addSubview(typeLabel)

        var constraints = [
            row.heightAnchor.constraint(equalToConstant: 38),

            icon.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 15),
            icon.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 20),
            icon.heightAnchor.constraint(equalToConstant: 16),

            nameLabel.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
            nameLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            typeLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
            typeLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            typeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 35),
            typeLabel.heightAnchor.constraint(equalToConstant: 22),
        ]

        if let schema, !schema.isEmpty {
            let schemaLabel = NSTextField(labelWithString: schema)
            schemaLabel.font = .systemFont(ofSize: 11)
            schemaLabel.textColor = .tertiaryLabelColor
            schemaLabel.lineBreakMode = .byTruncatingTail
            schemaLabel.maximumNumberOfLines = 1
            schemaLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            schemaLabel.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(schemaLabel)

            constraints.append(contentsOf: [
                schemaLabel.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 6),
                schemaLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                schemaLabel.trailingAnchor.constraint(lessThanOrEqualTo: typeLabel.leadingAnchor, constant: -8),
            ])
        } else {
            constraints.append(
                nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: typeLabel.leadingAnchor, constant: -8)
            )
        }

        NSLayoutConstraint.activate(constraints)
        return row
    }

    // MARK: - Actions

    @objc private func clearSearch() {
        searchField.stringValue = ""
        activeIndex = 0
        clearButton.isHidden = true
        reloadContent()
    }


    private func openCollection(_ collection: any CollectionWrapper) {
        let isFunction = collection.type == "function" || collection.type == "procedure"
        if isFunction, let pgWrapper = collection as? PostgreSQLCollectionWrapper {
            openFunction(name: pgWrapper.name, oid: pgWrapper.oid, schema: pgWrapper.schema)
        } else {
            instance.createNewTab(name: collection.name, databaseSchema: collection.schema)
        }
        clearSearch()
    }

    private func openRecentEntry(_ entry: RecentTableEntry) {
        let isFunction = entry.tableType == "function" || entry.tableType == "procedure"
        if isFunction {
            // Look up the collection to get the oid
            let dbName = instance.connectedDatabase?.name ?? ""
            if let collections = instance.collections[dbName],
               let pgWrapper = collections.first(where: { $0.name == entry.tableName && $0.schema == entry.schemaName }) as? PostgreSQLCollectionWrapper {
                openFunction(name: pgWrapper.name, oid: pgWrapper.oid, schema: pgWrapper.schema)
            }
        } else {
            instance.createNewTab(name: entry.tableName, databaseSchema: entry.schemaName)
        }
    }

    private func openFunction(name: String, oid: String, schema: String?) {
        Task {
            guard let driver = instance.databaseService.driver as? PostgreSQLDriver else { return }
            do {
                let definition = try await driver.getFunctionDefinition(oid: oid)
                instance.createFunctionEditorTab(name: name, definition: definition, oid: oid, schema: schema)
            } catch {
                debugLog("Failed to open function: \(error)")
            }
        }
    }

    // MARK: - NSTextFieldDelegate

    func controlTextDidChange(_ obj: Notification) {
        clearButton.isHidden = currentSearchQuery.isEmpty
        activeIndex = 0
        reloadContent()
        scrollToActiveRow()
        Task { @MainActor [weak self] in
            await Task.yield()
            self?.scrollToActiveRow()
        }
    }

    // MARK: - Event Monitor

    private func setupEventMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self, self.view.window?.isKeyWindow == true else { return event }

            switch event.keyCode {
            case 17 where event.modifierFlags.contains(.command):
                self.instance.createSQLEditorTab()
                return nil
            default:
                break
            }

            let searchQuery = self.currentSearchQuery
            guard !searchQuery.isEmpty else { return event }
            let collections = self.filteredCollections(matching: searchQuery)
            guard !collections.isEmpty else { return event }

            switch event.keyCode {
            case 125: // Down arrow
                let newIndex = min(self.activeIndex + 1, collections.count - 1)
                if newIndex != self.activeIndex {
                    self.updateActiveIndex(from: self.activeIndex, to: newIndex)
                }
                return nil
            case 126: // Up arrow
                let newIndex = max(self.activeIndex - 1, 0)
                if newIndex != self.activeIndex {
                    self.updateActiveIndex(from: self.activeIndex, to: newIndex)
                }
                return nil
            case 36: // Enter/Return
                if collections.indices.contains(self.activeIndex) {
                    self.openCollection(collections[self.activeIndex])
                }
                return nil
            default:
                return event
            }
        }
    }

    private func updateActiveIndex(from oldIndex: Int, to newIndex: Int) {
        let views = dropdownStackView.arrangedSubviews
        if let oldRow = views[safe: oldIndex] as? ClickableRowView {
            oldRow.isActive = false
            oldRow.layer?.backgroundColor = nil
        }
        activeIndex = newIndex
        if let newRow = views[safe: newIndex] as? ClickableRowView {
            newRow.isActive = true
            newRow.layer?.backgroundColor = NSColor.separatorColor.cgColor.copy(alpha: NSColor.separatorColor.alphaComponent * 0.5)
        }
        scrollToActiveRow()
    }

    private func scrollToActiveRow() {
        guard dropdownScrollView.isHidden == false else { return }
        guard activeIndex < dropdownStackView.arrangedSubviews.count else { return }
        view.layoutSubtreeIfNeeded()
        let row = dropdownStackView.arrangedSubviews[activeIndex]
        dropdownScrollView.contentView.scrollToVisible(row.frame)
        dropdownScrollView.reflectScrolledClipView(dropdownScrollView.contentView)
    }

    func tearDown() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(searchField)
        reloadContent()

        // Service may not be initialized yet (set up async in ConnectionInstance.init)
        if instance.recentTablesService == nil {
            Task { @MainActor in
                await Task.yield()
                self.reloadContent()
            }
        }
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        updateContainerAppearance(searchContainer)
        updateContainerAppearance(dropdownContainer)

        appearanceObservation = view.observe(\.effectiveAppearance) { [weak self] _, _ in
            guard let self else { return }
            self.updateContainerAppearance(self.searchContainer)
            self.updateContainerAppearance(self.dropdownContainer)
            self.reloadContent()
        }
    }
}

// MARK: - Clickable Row

private final class ClickableRowView: NSView {
    private let action: () -> Void
    private var trackingArea: NSTrackingArea?
    private var isHovering = false
    var isActive = false

    init(action: @escaping () -> Void) {
        self.action = action
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        trackingArea = area
        refreshHoverState()
    }

    private func refreshHoverState() {
        guard let window else {
            if isHovering {
                isHovering = false
                layer?.backgroundColor = nil
            }
            return
        }
        let mouseLocation = window.mouseLocationOutsideOfEventStream
        let localPoint = convert(mouseLocation, from: nil)
        let shouldHover = bounds.contains(localPoint)
        if shouldHover != isHovering {
            isHovering = shouldHover
            layer?.backgroundColor = (shouldHover || isActive)
                ? NSColor.separatorColor.cgColor.copy(alpha: NSColor.separatorColor.alphaComponent * 0.5)
                : nil
        }
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        layer?.backgroundColor = NSColor.separatorColor.cgColor.copy(alpha: NSColor.separatorColor.alphaComponent * 0.5)
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        layer?.backgroundColor = isActive
            ? NSColor.separatorColor.cgColor.copy(alpha: NSColor.separatorColor.alphaComponent * 0.5)
            : nil
    }

    override func updateLayer() {
        super.updateLayer()
        layer?.backgroundColor = (isHovering || isActive)
            ? NSColor.separatorColor.cgColor.copy(alpha: NSColor.separatorColor.alphaComponent * 0.5)
            : nil
    }

    override func mouseUp(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        if bounds.contains(location) {
            action()
        }
    }
}

// MARK: - Vertically Centered Text Field Cell

private final class VerticallyCenteredTextFieldCell: NSTextFieldCell {
    override func titleRect(forBounds rect: NSRect) -> NSRect {
        var titleRect = super.titleRect(forBounds: rect)
        let textHeight = cellSize(forBounds: rect).height
        titleRect.origin.y = rect.origin.y + (rect.height - textHeight) / 2
        titleRect.size.height = textHeight
        return titleRect
    }

    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        super.drawInterior(withFrame: titleRect(forBounds: cellFrame), in: controlView)
    }
}
