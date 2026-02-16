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

            if items.isEmpty {
                emptyState
            } else {
                cardRow
            }
        }
    }

    private var emptyState: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock")
                .font(.system(size: 14))
                .foregroundStyle(.tertiary)

            Text("Items you open will show up here")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                .foregroundStyle(Color(.separatorColor).opacity(0.4))
        )
    }

    private var cardRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(items) { item in
                    RecentCard(item: item) {
                        onOpen(item)
                    }
                    .frame(width: 200)
                }
            }
        }
    }
}

struct RecentCard: View {
    let item: WorkspaceItem
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false

    var body: some View {
        Button(action: onTap) {
            cardContent
        }
        .buttonStyle(.plain)
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
        .overlay(cardBorder)
        .scaleEffect(isHovering ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isHovering)
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

    @ViewBuilder
    private var cardBackground: some View {
        if #available(macOS 26.0, *) {
            RoundedRectangle(cornerRadius: 12)
                .fill(.clear)
                .glassEffect(.regular.tint(Color(.controlColor).opacity(0.1)), in: .rect(cornerRadius: 12))
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(cardFillColor)
        }
    }

    private var cardFillColor: Color {
        let isDark = colorScheme == .dark
        if isHovering {
            return isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.04)
        }
        return isDark ? Color.white.opacity(0.04) : Color.black.opacity(0.02)
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(
                Color(.separatorColor).opacity(isHovering ? 0.6 : 0.3),
                lineWidth: 1
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
