//
//  CollectionDetails.swift
//  Collection
//
//  Created by Fauzaan on 3/23/25.
//

import SwiftUI

// MARK: - ScrollOffsetPreferenceKey
struct ScrollOffsetPreferenceKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

enum SidebarViewMode {
    case tables
    case history
}

// MARK: - ConnectionDetailsSidebar
struct ConnectionDetailsSidebar: View {
    @Environment(SidebarViewModel.self) var viewModel: SidebarViewModel
    @Environment(ConnectionInstance.self) var connectionInstance: ConnectionInstance
    @Environment(\.colorScheme) private var colorScheme
    @State private var isScrolled = false
    @State private var scrollOffset: CGFloat = 0
    @State private var isLoadingCollections: Bool = false
    @State private var sidebarViewMode: SidebarViewMode = .tables
    @State private var showAdvancedHistory = false

    var body: some View {
        VStack(spacing: 0) {
            ConnectionNameHeader()

            VStack(spacing: 2) {
                HStack {
                    DatabaseHeader(viewModel: viewModel, isLoadingCollections: $isLoadingCollections)
                        .padding(.leading, 4)

                    Spacer()

                    SidebarViewModeToggle(viewMode: $sidebarViewMode, showAdvancedHistory: $showAdvancedHistory)
                        .padding(.trailing, 8)
                }
                .padding(.bottom, 4)

                if viewModel.isSearchVisible && sidebarViewMode == .tables {
                    SearchInput(viewModel: viewModel)
                        .padding(.horizontal, 6)
                        .padding(.leading, -2)
                        .padding(.bottom, 2)
                }

                SoftSeparator()
                    .opacity(isScrolled ? 1 : 0)
            }
            .animation(.easeOut(duration: 0.15), value: isScrolled)

            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: []) {
                    if sidebarViewMode == .tables {
                        DatabaseList(viewModel: viewModel, isLoadingCollections: $isLoadingCollections)
                            .padding(.trailing, 16)
                            .background(
                                GeometryReader { geometry in
                                    Color.clear
                                        .onAppear {
                                            scrollOffset = geometry.frame(in: .global).minY
                                        }
                                        .onChange(of: geometry.frame(in: .global).minY) { _, newValue in
                                            let diff = scrollOffset - newValue
                                            withAnimation(.easeOut(duration: 0.15)) {
                                                isScrolled = diff > 20
                                            }
                                        }
                                }
                            )
                    } else {
                        QueryHistorySidebarList()
                            .padding(.trailing, 16)
                    }
                }
            }
            .padding(.trailing, -10)

        }
        .padding(.top, 4)
        .padding(.leading, 10)
        .padding([.trailing], 8)
        .padding(.bottom, 0)
        .padding(.bottom, 10)
        .padding(.leading, 4)
        .cornerRadius(16)
        .task {
            do {
                isLoadingCollections = true
                try await viewModel.activeConnection?.connect()
            } catch {

            }
        }
        .sheet(isPresented: $showAdvancedHistory) {
            QueryHistoryView()
                .environment(connectionInstance)
                .frame(minWidth: 600, minHeight: 400)
        }
    }
}

// MARK: - Sidebar View Mode Toggle
struct SidebarViewModeToggle: View {
    @Binding var viewMode: SidebarViewMode
    @Binding var showAdvancedHistory: Bool
    @Namespace private var animation

    var body: some View {
        HStack(spacing: 0) {
            SegmentIconButton(
                icon: "tablecells",
                isSelected: viewMode == .tables,
                animation: animation
            ) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7, blendDuration: 0)) {
                    viewMode = .tables
                }
            }
            .customHelp("Tables")

            SegmentIconButton(
                icon: "clock.arrow.circlepath",
                isSelected: viewMode == .history,
                animation: animation
            ) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7, blendDuration: 0)) {
                    viewMode = .history
                }
            }
            .customHelp("Query History")
            .contextMenu {
                Button {
                    showAdvancedHistory = true
                } label: {
                    Label("Advanced View...", systemImage: "rectangle.expand.vertical")
                }
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.clear)
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
        )
    }
}

struct SegmentIconButton: View {
    let icon: String
    let isSelected: Bool
    let animation: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .frame(width: 24, height: 20)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.separatorColor).opacity(0.5))
                            .matchedGeometryEffect(id: "selectedSegment", in: animation)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Query History Sidebar List
struct QueryHistorySidebarList: View {
    @Environment(ConnectionInstance.self) private var instance
    @State private var historyEntries: [QueryHistoryEntryViewModel] = []
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 40)
            } else if historyEntries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                    Text("No queries yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            } else {
                ForEach(groupedHistory, id: \.key) { group in
                    QueryHistoryDateSection(
                        title: group.key,
                        entries: group.entries,
                        onDelete: { loadHistory() }
                    )
                }
            }
        }
        .onAppear {
            loadHistory()
        }
    }

    private var groupedHistory: [QueryHistoryGroup] {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday)!
        let startOfThisWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        let startOfLastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: startOfThisWeek)!

        var groups: [String: [QueryHistoryEntryViewModel]] = [:]

        for entry in historyEntries {
            let key: String
            if entry.executedAt >= startOfToday {
                key = "Today"
            } else if entry.executedAt >= startOfYesterday {
                key = "Yesterday"
            } else if entry.executedAt >= startOfThisWeek {
                key = "This Week"
            } else if entry.executedAt >= startOfLastWeek {
                key = "Last Week"
            } else {
                key = "Older"
            }

            groups[key, default: []].append(entry)
        }

        let order = ["Today", "Yesterday", "This Week", "Last Week", "Older"]
        return order.compactMap { key in
            guard let entries = groups[key], !entries.isEmpty else { return nil }
            return QueryHistoryGroup(key: key, entries: entries)
        }
    }

    private func loadHistory() {
        isLoading = true
        guard let service = instance.queryHistoryService else {
            isLoading = false
            return
        }
        historyEntries = service.fetchHistory(limit: 50)
        isLoading = false
    }
}

struct QueryHistoryGroup {
    let key: String
    let entries: [QueryHistoryEntryViewModel]
}

struct QueryHistoryDateSection: View {
    let title: String
    let entries: [QueryHistoryEntryViewModel]
    var onDelete: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.tertiary)
                .padding(.leading, 8)
                .padding(.top, 8)
                .padding(.bottom, 4)

            ForEach(entries) { entry in
                QueryHistorySidebarRow(entry: entry, onDelete: onDelete)
            }
        }
    }
}

struct QueryHistorySidebarRow: View {
    @Environment(ConnectionInstance.self) private var instance
    let entry: QueryHistoryEntryViewModel
    var onDelete: (() -> Void)?
    var isLast: Bool = false
    @State private var isHovered = false

    var body: some View {
        Button {
            loadQueryInEditor()
        } label: {
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.queryPreview)
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(.primary)

                    HStack(spacing: 4) {
                        Text(entry.formattedDate)
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)

                        if let duration = entry.formattedDuration {
                            Text("·")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                            Text(duration)
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Spacer()

                if !entry.wasSuccessful {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color(.separatorColor).opacity(0.5) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(entry.query, forType: .string)
            } label: {
                Label("Copy Query", systemImage: "doc.on.doc")
            }

            Button {
                loadQueryInEditor()
            } label: {
                Label("Load in Editor", systemImage: "arrow.up.forward.square")
            }

            if let tableName = entry.tableName {
                Divider()
                Button {
                    instance.createNewTab(name: tableName, databaseSchema: entry.schemaName)
                } label: {
                    Label("Open Table: \(tableName)", systemImage: "table")
                }
            }

            Divider()

            Button(role: .destructive) {
                instance.queryHistoryService?.deleteEntry(entry.id)
                onDelete?()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .help(entry.query)
    }

    private func loadQueryInEditor() {
        instance.createSQLEditorTab(withQuery: entry.query)
    }
}
