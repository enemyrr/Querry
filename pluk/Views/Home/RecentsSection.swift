//
//  RecentsSection.swift
//  Pluk
//

import SwiftUI

struct RecentsSection: View {
    let items: [WorkspaceItem]
    let onOpen: (WorkspaceItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recents")
                .font(.system(size: 14, weight: .semibold))

            cardRow
        }
    }

    private var cardRow: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 12) {
                ForEach(items) { item in
                    RecentCard(item: item) {
                        onOpen(item)
                    }
                    .frame(width: 200)
                }
            }
            .padding(.vertical, 6)
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, 28, for: .scrollContent)
        .padding(.horizontal, -28)
        .mask(
            HStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 12)
                Color.black
                LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 12)
            }
            .padding(.horizontal, -6)
        )
    }
}

struct RecentCard: View {
    let item: WorkspaceItem
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false

    var body: some View {
        cardContent
            .contentShape(.rect)
            .simultaneousGesture(
                TapGesture(count: 2)
                    .onEnded {
                        onTap()
                    }
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovering = hovering
                }
            }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                itemIcon
                Spacer()
                statusTag
            }
            .padding(.bottom, 12)

            Spacer()

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(relativeTime)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .frame(height: 120)
        .background(cardBackground)
        .clipShape(.rect(cornerRadius: 12))
        .overlay(cardBorder)
        .offset(y: isHovering ? -2 : 0)
    }

    @ViewBuilder
    private var itemIcon: some View {
        switch item {
        case .connection(let connection):
            DatabaseTypeIcon(databaseType: connection.databaseType)
        case .notebook:
            NotebookIcon()
        }
    }

    @ViewBuilder
    private var statusTag: some View {
        switch item {
        case .connection(let connection):
            if let env = connection.environment {
                EnvironmentTag(environment: env)
            }
        case .notebook(let notebook):
            NotebookStatusTag(status: notebook.status)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(cardFillColor)
            .shadow(color: .black.opacity(isHovering ? 0.15 : 0.10), radius: isHovering ? 2 : 1, y: isHovering ? 1 : 0.5)
    }

    private var cardFillColor: Color {
        let isDark = colorScheme == .dark
        if isHovering {
            return isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.04)
        }
        return isDark ? Color.white.opacity(0.04) : .white
    }

    private var cardBorder: some View {
        let isDark = colorScheme == .dark
        return RoundedRectangle(cornerRadius: 12)
            .stroke(
                isDark
                    ? Color.white.opacity(isHovering ? 0.12 : 0.06)
                    : Color.black.opacity(isHovering ? 0.12 : 0.08),
                lineWidth: 0.5
            )
    }

    private var relativeTime: String {
        let interval = Date().timeIntervalSince(item.lastAccessedAt)
        if interval < 60 {
            return "Just now"
        }
        return item.lastAccessedAt.formatted(.relative(presentation: .named))
    }
}
