import AppKit
import SwiftUI

struct FilterBuilderView: View {
    private enum Layout {
        static let rowHeight: CGFloat = 28
        static let rowSpacing: CGFloat = 8
        static let verticalPadding: CGFloat = 8
    }

    var columns: [DatabaseSchemaInfo]
    var fallbackColumns: [QueryColumnInfo] = []
    let tabID: UUID
    var tableName: String
    var databaseSchema: String?
    var onApplyFilter: (String) -> Void
    @Binding var conditions: [FilterCondition]
    var onLayoutInvalidated: (() -> Void)? = nil
    var onHeightChanged: ((CGFloat) -> Void)? = nil
    
    @Environment(ConnectionInstance.self) private var instance
    @State private var showFilterBuilder: Bool = false
    @State private var hostingWindow: NSWindow?
    @FocusState private var focusedField: Int?
    
    private var hasValidCondition: Bool {
        conditions.contains { condition in
            !condition.field.isEmpty && !condition.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var filterableColumns: [DatabaseSchemaInfo] {
        if !columns.isEmpty {
            return columns
        }

        return fallbackColumns.enumerated().map { index, column in
            DatabaseSchemaInfo(
                ordinalPosition: index + 1,
                columnName: column.name,
                dataType: column.dataType,
                formatType: column.format ?? column.dataType,
                typeOid: 0
            )
        }
    }

    private var defaultColumnName: String {
        filterableColumns.first?.columnName ?? ""
    }
    
    private func generateSQLFilter() -> String {
        instance.databaseService.generateFilterQuery(from: conditions, tableName: tableName, databaseSchema: databaseSchema)
    }

    private var shouldShowFilterBuilder: Bool {
        conditions.contains { !$0.field.isEmpty && !$0.value.isEmpty }
    }

    private func syncInitialFieldIfNeeded() {
        guard !filterableColumns.isEmpty, conditions[0].field.isEmpty else {
            return
        }

        conditions[0].field = defaultColumnName
    }
    
    private func syncVisibilityFromConditions() {
        if shouldShowFilterBuilder && !showFilterBuilder {
            showFilterBuilder = true
        }
    }

    private var estimatedVisibleHeight: CGFloat {
        guard showFilterBuilder else {
            return 0
        }

        let rowCount = max(conditions.count, 1)
        let contentHeight = CGFloat(rowCount) * Layout.rowHeight
        let spacingHeight = CGFloat(max(rowCount - 1, 0)) * Layout.rowSpacing
        return contentHeight + spacingHeight + (Layout.verticalPadding * 2)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if showFilterBuilder {
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .top, spacing: 28) {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(conditions.indices, id: \.self) { index in
                                    FilterRowView(
                                        columns: filterableColumns,
                                        condition: $conditions[index],
                                        isFirstRow: index == 0,
                                        onDelete: {
                                            if conditions.count > 1 {
                                                conditions.remove(at: index)
                                            } else {
                                                conditions = [FilterCondition(conjunction: .whereClause, field: defaultColumnName, filterOperator: .equals, value: "")]
                                                onApplyFilter("")
                                                withAnimation(.easeInOut(duration: 0.2)) {
                                                    showFilterBuilder = false
                                                }
                                                NotificationCenter.default.post(
                                                    name: .filterBuilderDidClose,
                                                    object: hostingWindow,
                                                    userInfo: ["tabID": tabID]
                                                )
                                            }
                                        },
                                        focusedField: $focusedField,
                                        fieldIndex: index
                                    )
                                    .frame(height: Layout.rowHeight, alignment: .top)
                                }
                            }
                            .background(alignment: .trailing) {
                                Rectangle()
                                    .fill(Color(.separatorColor))
                                    .frame(width: 1)
                                    .offset(x: 14)
                            }
                            
                            HStack(alignment: .top, spacing: 10) {
                                Button("Apply") {
                                    onApplyFilter(generateSQLFilter())
                                }
                                .buttonStyle(FilterSubmitButtonStyle())
                                .disabled(!hasValidCondition)
                                .keyboardShortcut(.return, modifiers: [])
                                .transition(.slide)
                                
                                Button {
                                    if conditions.count < 8 {
                                        let newCondition = FilterCondition(
                                            conjunction: .and,
                                            field: defaultColumnName,
                                            filterOperator: .equals,
                                            value: ""
                                        )
                                        conditions.append(newCondition)
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "plus")
                                        Text("Add Filter").lineLimit(1)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color(.separatorColor).opacity(0.5))
                                    .clipShape(.rect(cornerRadius: 8))
                                    .fixedSize()
                                }
                                .buttonStyle(.plain)
                                .disabled(conditions.count >= 8)

                                Button("Clear filters") {
                                    conditions = [FilterCondition(conjunction: .whereClause, field: defaultColumnName, filterOperator: .equals, value: "")]
                                    onApplyFilter("")
                                }
                                .buttonStyle(FilterClearButtonStyle())
                                .fixedSize()
                            }
                            .background(
                                Button("") {
                                    onApplyFilter(generateSQLFilter())
                                }
                                .keyboardShortcut(.return, modifiers: .command)
                                .hidden()
                            )
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 10)
                        Spacer(minLength: 0)
                    }
                    .frame(maxHeight: .infinity, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.vertical, Layout.verticalPadding)
                .background {
                    GeometryReader { proxy in
                        Color.clear
                            .preference(key: FilterBuilderHeightPreferenceKey.self, value: proxy.size.height)
                    }
                }
                .onAppear {
                    syncInitialFieldIfNeeded()
                }
                .onChange(of: filterableColumns) { _, _ in
                    syncInitialFieldIfNeeded()
                }
            }
        }
        .onAppear {
            syncVisibilityFromConditions()
            onLayoutInvalidated?()
            onHeightChanged?(estimatedVisibleHeight)
        }
        .onPreferenceChange(FilterBuilderHeightPreferenceKey.self) { height in
            onHeightChanged?(height)
        }
        .onChange(of: shouldShowFilterBuilder) { _, _ in
            syncVisibilityFromConditions()
        }
        .onChange(of: showFilterBuilder) { _, _ in
            onLayoutInvalidated?()
            onHeightChanged?(estimatedVisibleHeight)
        }
        .onChange(of: conditions.count) { _, _ in
            onHeightChanged?(estimatedVisibleHeight)
        }
        .background(WindowReader { window in
            hostingWindow = window
        })
        .onReceive(NotificationCenter.default.publisher(for: .toggleFilterBuilder)) { notification in
            guard let sourceWindow = notification.object as? NSWindow,
                  let hostingWindow,
                  sourceWindow === hostingWindow,
                  notification.userInfo?["tabID"] as? UUID == tabID else { return }

            withAnimation(.easeInOut(duration: 0.2)) {
                showFilterBuilder.toggle()

                if showFilterBuilder {
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(250))
                        focusedField = 0
                    }
                }
            }
        }
    }
}

private struct FilterBuilderHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
