//
//  DocumentRowView.swift
//  Collection
//
//  Created by Fauzaan on 12/31/24.
//
import SwiftUI
import MongoKitten
import SwiftData

// MARK: - Document Details
struct DocumentRowView: View {
    let document: [String: QueryRowInfo]
    let index: Int
    let onRefresh: () async -> Void

    @State private var isCardHovered = false
    @State private var showActionButton = false
    @State private var pendingAction: DocumentAction? = nil
    @State private var showCopyFeedback = false
    @State private var editingJSON: String = ""
    @State private var errorMessage: String?
    @State private var showErrorAlert = false
    @State private var localDocument: [String: QueryRowInfo]?
    @Environment(\.colorScheme) var colorScheme
    @Environment(ConnectionInstance.self) private var instance

    // Use local document if available, otherwise use the passed document
    private var displayDocument: [String: QueryRowInfo] {
        localDocument ?? document
    }

    var body: some View {
        Group {
            ZStack(alignment: .bottomTrailing) {
                VStack(alignment: .leading, spacing: 2) {
                    if pendingAction == .update {
                        DocumentEditView(editingJSON: $editingJSON)
                    } else {
                        DocumentKeyValueList(
                            document: displayDocument
                        )
                        .padding()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Group {
                        if colorScheme == .dark {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    Color(Color(.black).opacity(0.25))
                                )
                                .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.05), radius: 4)
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    Color(hex: "#FDFDFD")
                                )
                                .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.05), radius: 4)
                        }
                    }
                )
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(pendingAction == .delete
                                ? Color.red.opacity(0.7)
                                : pendingAction
                                == .update
                                ? Color.orange.opacity(0.7)
                                : Color(.separatorColor),
                                lineWidth: 1
                               )
                        .shadow(color: pendingAction == .delete
                                ? Color.red
                                : pendingAction
                                == .update
                                ? Color.orange.opacity(0.8)
                                : Color.clear,
                                radius: 4,
                                x: 0,
                                y: 0
                               )
                )
                .cornerRadius(8)
                .cardStyle(isHovered: isCardHovered)

                HoverActionButtons(
                    isVisible: showActionButton,
                    onEdit: {
                        togglePendingAction(.update)
                    },
                    onCopy: {
                        copyDocumentJSON()
                    },
                    onDelete: {
                        togglePendingAction(.delete)
                    },
                    onClone: {
                        copyDocumentJSON()
                    },
                    showCopyFeedback: showCopyFeedback,
                    pendingAction: pendingAction,
                    onSave: {
                        if pendingAction == .delete {
                            handleDelete()
                        } else {
                            handleSave()
                        }
                    },
                    onCancel: {
                        if pendingAction == .delete {
                            togglePendingAction(.delete)
                        } else {
                            handleCancel()
                        }
                    }
                )
            }
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isCardHovered = hovering
                }
            }
            .onChange(of: isCardHovered) { _, newValue in
                showActionButton = newValue || pendingAction == .update || pendingAction == .delete
            }
            .onChange(of: pendingAction) { _, _ in
                showActionButton = isCardHovered || pendingAction == .update || pendingAction == .delete
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: pendingAction)
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {
                showErrorAlert = false
            }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
    }

    // MARK: - Action Handlers

    private func togglePendingAction(_ action: DocumentAction) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if pendingAction == action {
                pendingAction = nil
            } else {
                pendingAction = action

                // If entering update mode, initialize editing JSON
                if action == .update {
                    editingJSON = getDocumentJSON()
                }
            }
        }
    }

    private func copyDocumentJSON() {
        let jsonString = getDocumentJSON()

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(jsonString, forType: .string)

        showCopyFeedback = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            showCopyFeedback = false
        }
    }

    private func getDocumentJSON() -> String {
        // Extract the FormattedDocument from metadata (use displayDocument to get latest state)
        guard let formattedDocInfo = displayDocument["__formattedDocument"],
              let formattedDoc = formattedDocInfo.value as? MongoKitten.Document.FormattedDocument else {
            return "{}"
        }

        // Get JSON string from the raw document
        return formattedDoc.rawDocument.jsonString
    }

    private func handleSave() {
        Task {
            do {
                // 1. Extract document ID
                guard let idInfo = document["_id"],
                      let documentId = idInfo.value as? String,
                      let objectId = ObjectId(documentId) else {
                    throw MongoError.invalidData
                }

                // 2. Get collection name from selected tab
                guard let collectionName = instance.selectedTab?.name else {
                    throw DatabaseError.operationFailed("No collection selected")
                }

                // 3. Parse edited JSON into MongoDB Document
                guard let updatedDocument = try? MongoKitten.Document(fromJSON: editingJSON) else {
                    throw MongoError.invalidData
                }

                // 4. Convert to [String: Any] dictionary
                var documentData: [String: Any] = [:]
                for (key, value) in updatedDocument {
                    documentData[key] = value
                }

                // 5. Call database service to update
                try await instance.databaseService.updateDocument(
                    in: collectionName,
                    databaseSchema: nil,
                    id: objectId,
                    data: documentData
                )

                // 6. Optimistically update local state with the saved document
                await MainActor.run {
                    localDocument = formatUpdatedDocument(updatedDocument)
                }

                // 7. Success - clear pending action
                await MainActor.run {
                    togglePendingAction(.update)
                }

            } catch {
                // Handle error - show alert to user
                debugLog("Failed to save document: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to save document: \(error.localizedDescription)"
                    showErrorAlert = true
                }
            }
        }
    }

    private func handleCancel() {
        togglePendingAction(.update)
    }

    private func formatUpdatedDocument(_ mongoDocument: MongoKitten.Document) -> [String: QueryRowInfo] {
        // Format the document similar to how MongoDBDriver does it
        let formattedDoc = formatMongoDocument(mongoDocument)
        return convertFormattedDocumentToRow(formattedDoc)
    }

    private func formatMongoDocument(_ mongoDocument: MongoKitten.Document) -> MongoKitten.Document.FormattedDocument {
        guard let id = mongoDocument["_id"] as? ObjectId else {
            return MongoKitten.Document.FormattedDocument(id: "", fields: [], rawDocument: mongoDocument)
        }

        let fields = mongoDocument.keys.map { key in
            formatField(key: key, value: mongoDocument[key])
        }

        return MongoKitten.Document.FormattedDocument(id: id.hexString, fields: fields, rawDocument: mongoDocument)
    }

    private func formatField(key: String, value: Primitive?) -> MongoKitten.Document.FormattedDocument.FormattedField {
        let formatted = MongoKitten.Document().formatValue(value)

        var nestedFields: [MongoKitten.Document.FormattedDocument.FormattedField]?
        if let doc = value as? MongoKitten.Document {
            nestedFields = doc.keys.map { key in
                formatField(key: key, value: doc[key])
            }
        }

        return MongoKitten.Document.FormattedDocument.FormattedField(
            key: key,
            formattedValue: formatted,
            rawValue: value ?? "nil",
            nestedFields: nestedFields
        )
    }

    private func convertFormattedDocumentToRow(_ formattedDoc: MongoKitten.Document.FormattedDocument) -> [String: QueryRowInfo] {
        var row: [String: QueryRowInfo] = [:]

        // Store the FormattedDocument as metadata for access to rawDocument
        row["__formattedDocument"] = QueryRowInfo(
            value: formattedDoc,
            dataType: "FormattedDocument",
            format: nil
        )

        // Add the document ID
        row["_id"] = QueryRowInfo(value: formattedDoc.id, dataType: "ObjectId", format: nil)

        // Convert each formatted field to display value
        for field in formattedDoc.fields {
            if field.key == "_id" {
                continue
            }
            row[field.key] = QueryRowInfo(value: field, dataType: field.formattedValue.type, format: nil)
        }

        return row
    }

    private func handleDelete() {
        Task {
            do {
                // 1. Extract document ID
                guard let idInfo = document["_id"],
                      let documentId = idInfo.value as? String,
                      let objectId = ObjectId(documentId) else {
                    throw MongoError.invalidData
                }

                // 2. Get collection name from selected tab
                guard let collectionName = instance.selectedTab?.name else {
                    throw DatabaseError.operationFailed("No collection selected")
                }

                // 3. Call database service to delete
                try await instance.databaseService.deleteDocument(
                    in: collectionName,
                    databaseSchema: nil,
                    id: objectId
                )

                // 4. Refresh the document list
                await onRefresh()

                // 5. Success - clear pending action
                await MainActor.run {
                    togglePendingAction(.delete)
                }

            } catch {
                debugLog("Failed to delete document: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to delete document: \(error.localizedDescription)"
                    showErrorAlert = true
                }
            }
        }
    }
}

// MARK: - Document Key-Value List
struct DocumentKeyValueList: View {
    let document: [String: QueryRowInfo]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(document.keys.filter { $0 != "__formattedDocument" }.sorted()), id: \.self) { key in
                if let queryRowInfo = document[key] {

                    // Try to cast to FormattedField first (for MongoDB with nested fields)
                    if let formattedField = queryRowInfo.value as? MongoKitten.Document.FormattedDocument.FormattedField {
                        RecursiveKeyValueRow(
                            formattedField: formattedField,
                            key: key
                        )
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    // Fallback to FormattedPrimitive (for other database types)
                    else if let formattedPrimitive = queryRowInfo.value as? FormattedPrimitive {
                        KeyValueRow(
                            key: key,
                            formattedPrimitive: formattedPrimitive
                        )
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

// MARK: - Key-Value Views
struct KeyValueRow: View {
    let key: String
    let formattedPrimitive: FormattedPrimitive
    
    private static let monoFont = Font.system(.body, design: .monospaced)
    
    @State private var isHoveredKey = false
    @State private var isHoveredValue = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 2) {
            // Key section
            HStack(spacing: 0) {
                Text(key)
                    .font(Self.monoFont)
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                
                Text(":")
                    .font(Self.monoFont)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHoveredKey ? Color.gray.opacity(0.2) : Color.clear)
            )
            .onHover { hovering in
                if isHoveredKey != hovering {
                    isHoveredKey = hovering
                }
            }
            
            Text(formattedPrimitive.value)
                .font(Self.monoFont)
                .foregroundColor(formattedPrimitive.color)
                .padding(.horizontal, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isHoveredValue ? Color.gray.opacity(0.2) : Color.clear)
                )
                .onHover { hovering in
                    if isHoveredValue != hovering {
                        isHoveredValue = hovering
                    }
                }
                .textSelection(.enabled)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct ExpandableHeader: View {
    let key: String
    let isExpanded: Bool
    @Binding var isHoveredKey: Bool
    
    // Static font for better performance
    private static let monoFont = Font.system(.body, design: .monospaced)
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 10))
                .foregroundColor(.gray)
                .padding(.leading, 4)
            
            Text("\(key):")
                .font(Self.monoFont)
                .foregroundColor(.primary)
                .padding(.horizontal, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isHoveredKey ? Color.gray.opacity(0.2) : Color.clear)
                )
                .onHover { hovering in
                    isHoveredKey = hovering
                }
        }
    }
}

struct RecursiveKeyValueRow: View {
    let formattedField: MongoKitten.Document.FormattedDocument.FormattedField
    let key: String

    var body: some View {
        let formattedPrimitive = formattedField.formattedValue

        Group {
            if formattedPrimitive.isExpandable {
                ExpandableValueView(
                    formattedPrimitive: formattedPrimitive,
                    key: key,
                    nestedFields: formattedField.nestedFields
                )
            } else {
                KeyValueRow(
                    key: key,
                    formattedPrimitive: formattedPrimitive
                )
            }
        }
    }
}

// MARK: - Optimized ExpandableValueView
struct ExpandableValueView: View {
    let formattedPrimitive: FormattedPrimitive
    let key: String
    let nestedFields: [MongoKitten.Document.FormattedDocument.FormattedField]?
    
    private static let monoFont = Font.system(.body, design: .monospaced)
    
    @State private var isExpanded = false
    @State private var isHoveredKey = false
    @State private var isHoveredValue = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Header row with toggle
            HStack(spacing: 2) {
                // Expandable header
                ExpandableHeader(
                    key: key,
                    isExpanded: isExpanded,
                    isHoveredKey: $isHoveredKey
                )
                
                // Value display
                Text(formattedPrimitive.value)
                    .font(Self.monoFont)
                    .foregroundColor(formattedPrimitive.color)
                    .padding(.horizontal, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isHoveredValue ? Color.gray.opacity(0.2) : Color.clear)
                    )
                    .onHover { hovering in
                        if isHoveredValue != hovering {
                            isHoveredValue = hovering
                        }
                    }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }
            
            // Nested fields - only create when expanded
            if isExpanded, let fields = nestedFields {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(fields, id: \.key) { field in
                        RecursiveKeyValueRow(
                            formattedField: field,
                            key: field.key
                        )
                        .padding(.leading, 16)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Common Styles and Modifiers
struct HoverableText: ViewModifier {
    @Binding var isHovered: Bool
    
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovered ? Color.gray.opacity(0.2) : Color.clear)
            )
            .onHover { hovering in
                if isHovered != hovering {
                    isHovered = hovering
                }
            }
    }
}

// MARK: - Action confirmation
extension View {
    func hoverable(isHovered: Binding<Bool>) -> some View {
        modifier(HoverableText(isHovered: isHovered))
    }
    
    func monospacedStyle(color: Color = .primary) -> some View {
        self.font(.system(.body, design: .monospaced))
            .foregroundColor(color)
    }
    
    func cardStyle(isHovered: Bool) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), lineWidth: 0)
        )
        .cornerRadius(10)
    }
}
