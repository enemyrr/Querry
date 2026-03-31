import SwiftUI

struct FilterBuilderView: View {
    var columns: [DatabaseSchemaInfo]
    var tableName: String
    var databaseSchema: String?
    var onApplyFilter: (String) -> Void
    @Binding var conditions: [FilterCondition]
    var onLayoutInvalidated: (() -> Void)? = nil
    
    @Environment(ConnectionInstance.self) private var instance
    @State private var showFilterBuilder: Bool = false
    @FocusState private var focusedField: Int?
    
    private var hasValidCondition: Bool {
        conditions.contains { condition in
            !condition.field.isEmpty && !condition.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    
    private func generateSQLFilter() -> String {
        instance.databaseService.generateFilterQuery(from: conditions, tableName: tableName, databaseSchema: databaseSchema)
    }

    private var shouldShowFilterBuilder: Bool {
        conditions.contains { !$0.field.isEmpty && !$0.value.isEmpty }
    }
    
    private func syncVisibilityFromConditions() {
        if shouldShowFilterBuilder && !showFilterBuilder {
            showFilterBuilder = true
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if showFilterBuilder {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 28) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(conditions.indices, id: \.self) { index in
                                FilterRowView(
                                    columns: columns,
                                    condition: $conditions[index],
                                    isFirstRow: index == 0,
                                    onDelete: {
                                        if conditions.count > 1 {
                                            conditions.remove(at: index)
                                        } else {
                                            conditions = [FilterCondition(conjunction: .whereClause, field: columns.isEmpty ? "" : columns[0].columnName, filterOperator: .equals, value: "")]
                                            onApplyFilter("")
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                showFilterBuilder = false
                                            }
                                            NotificationCenter.default.post(name: .filterBuilderDidClose, object: nil)
                                        }
                                    },
                                    focusedField: $focusedField,
                                    fieldIndex: index
                                )
                            }
                        }
                        .background(alignment: .trailing) {
                            Rectangle()
                                .fill(Color(.separatorColor))
                                .frame(width: 1)
                                .offset(x: 14)
                        }
                        
                        HStack(spacing: 10) {
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
                                        field: columns.isEmpty ? "" : columns[0].columnName,
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
                                conditions = [FilterCondition(conjunction: .whereClause, field: columns.isEmpty ? "" : columns[0].columnName, filterOperator: .equals, value: "")]
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
                    .padding(.horizontal, 10)
                }
                .padding(.vertical, 8)
                .onAppear {
                    if !columns.isEmpty && conditions[0].field.isEmpty {
                        conditions[0].field = columns[0].columnName
                    }
                }
                .onChange(of: columns) { _, _ in
                    if !columns.isEmpty && conditions[0].field.isEmpty {
                        conditions[0].field = columns[0].columnName
                    }
                }
            }
        }
        .onAppear {
            syncVisibilityFromConditions()
            onLayoutInvalidated?()
        }
        .onChange(of: shouldShowFilterBuilder) { _, _ in
            syncVisibilityFromConditions()
        }
        .onChange(of: showFilterBuilder) { _, _ in
            onLayoutInvalidated?()
        }
        .onChange(of: conditions.count) { _, _ in
            onLayoutInvalidated?()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleFilterBuilder)) { _ in
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
