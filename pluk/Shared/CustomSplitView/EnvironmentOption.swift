//
//  EnvironmentOptions.swift
//  Collection
//
//  Created by Fauzaan on 1/16/25.
//
import SwiftUI

// MARK: - Environment value to reserve leading space for overlay controls
struct LeadingOverlayWidthKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var leadingOverlayWidth: CGFloat {
        get { self[LeadingOverlayWidthKey.self] }
        set { self[LeadingOverlayWidthKey.self] = newValue }
    }
}

// MARK: - Environment value for current database type
struct CurrentDatabaseTypeKey: EnvironmentKey {
    static let defaultValue: DatabaseType? = nil
}

extension EnvironmentValues {
    var currentDatabaseType: DatabaseType? {
        get { self[CurrentDatabaseTypeKey.self] }
        set { self[CurrentDatabaseTypeKey.self] = newValue }
    }
}

// MARK: - Hoverable Menu Label
struct EnvironmentMenuLabel: View {
    let title: String
    @State private var isHovering: Bool = false

    var body: some View {
        if #available(macOS 26, *) {
            HStack(spacing: 6) {
                Text(title)
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
            }
            .font(.callout)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .glassEffect()
            .accessibilityLabel(Text(title))
            .accessibilityAddTraits(.isButton)
        } else {
            HStack(spacing: 6) {
                Text(title)
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
            }
            .font(.callout)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovering ? Color.primary.opacity(0.08) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(.separator, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovering = hovering
                }
            }
            .accessibilityLabel(Text(title))
            .accessibilityAddTraits(.isButton)
        }
    }
}
