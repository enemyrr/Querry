import SwiftUI

struct FilterBuilderView: View {
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
    @State private var measuredHeight: CGFloat = 0

    var body: some View {
        FilterBuilderRepresentable(
            columns: columns,
            fallbackColumns: fallbackColumns,
            tabID: tabID,
            conditions: $conditions,
            generateFilterQuery: { conditions in
                instance.databaseService.generateFilterQuery(
                    from: conditions,
                    tableName: tableName,
                    databaseSchema: databaseSchema
                )
            },
            onApplyFilter: onApplyFilter,
            onLayoutInvalidated: onLayoutInvalidated,
            onHeightChanged: { height in
                if abs(measuredHeight - height) >= 0.5 {
                    measuredHeight = height
                }
                onHeightChanged?(height)
            }
        )
        .frame(maxWidth: .infinity, minHeight: measuredHeight, maxHeight: measuredHeight, alignment: .topLeading)
    }
}

private struct FilterBuilderRepresentable: NSViewRepresentable {
    var columns: [DatabaseSchemaInfo]
    var fallbackColumns: [QueryColumnInfo]
    let tabID: UUID
    @Binding var conditions: [FilterCondition]
    var generateFilterQuery: ([FilterCondition]) -> String
    var onApplyFilter: (String) -> Void
    var onLayoutInvalidated: (() -> Void)? = nil
    var onHeightChanged: ((CGFloat) -> Void)? = nil

    func makeNSView(context: Context) -> FilterBuilderAppKitView {
        let view = FilterBuilderAppKitView()
        updateNSView(view, context: context)
        return view
    }

    func updateNSView(_ nsView: FilterBuilderAppKitView, context: Context) {
        nsView.update(
            columns: columns,
            fallbackColumns: fallbackColumns,
            tabID: tabID,
            conditions: conditions,
            onConditionsChange: { updatedConditions in
                if updatedConditions != conditions {
                    conditions = updatedConditions
                }
            },
            generateFilterQuery: generateFilterQuery,
            onApplyFilter: onApplyFilter,
            onLayoutInvalidated: onLayoutInvalidated,
            onHeightChanged: onHeightChanged
        )
    }
}
