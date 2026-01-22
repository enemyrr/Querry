//
//  RowDetailField.swift
//  Pluk
//
//  Created by Claude on 1/21/26.
//

import SwiftUI

struct RowDetailField: View {
    let columnName: String
    let rowInfo: QueryRowInfo
    let isEditing: Bool
    @Binding var editedValue: String

    private var isNull: Bool {
        rowInfo.value == nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(columnName)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(rowInfo.dataType)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            if isEditing {
                TextField("", text: $editedValue, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .lineLimit(1...50)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(.rect(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(.separatorColor), lineWidth: 1)
                    )
            } else {
                Text(displayValue)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(isNull ? .tertiary : .primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color(nsColor: .quaternarySystemFill))
                    .clipShape(.rect(cornerRadius: 6))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private var displayValue: String {
        guard let value = rowInfo.value else {
            return "NULL"
        }

        if let stringValue = value as? String {
            return stringValue.isEmpty ? "(empty)" : stringValue
        } else if let intValue = value as? Int {
            return String(intValue)
        } else if let doubleValue = value as? Double {
            return doubleValue.formatted()
        } else if let boolValue = value as? Bool {
            return boolValue ? "true" : "false"
        } else if let dateValue = value as? Date {
            return dateValue.formatted(date: .abbreviated, time: .standard)
        } else if let arrayValue = value as? [Any] {
            return formatJSON(arrayValue)
        } else if let dictValue = value as? [String: Any] {
            return formatJSON(dictValue)
        } else {
            return String(describing: value)
        }
    }

    private func formatJSON(_ value: Any) -> String {
        do {
            let data = try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys])
            return String(data: data, encoding: .utf8) ?? String(describing: value)
        } catch {
            return String(describing: value)
        }
    }
}
