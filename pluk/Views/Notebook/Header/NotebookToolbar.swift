import SwiftUI

struct NotebookToolbar: View {
    @Bindable var dataController: NotebookDataController
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var segmentAnimation

    private var isDashboardPublished: Bool {
        dataController.viewMode == .dashboard && dataController.isPublished
    }

    var body: some View {
        if isDashboardPublished {
            publishedToolbar
        } else {
            normalToolbar
        }
    }

    private var normalToolbar: some View {
        HStack(spacing: 0) {
            Spacer()
            viewModePicker
            Spacer()
        }
        .overlay(alignment: .trailing) {
            trailingButtons
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    private var publishedToolbar: some View {
        HStack {
            Spacer()
            editPublishedButton
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var trailingButtons: some View {
        HStack(spacing: 8) {
            if dataController.viewMode == .dashboard {
                publishButton
            }
            chatButton
        }
    }

    // MARK: - Segmented Control

    private var viewModePicker: some View {
        HStack(spacing: 0) {
            segmentButton(mode: .notebook, label: "Notebook")
            segmentButton(mode: .dashboard, label: "Dashboard")
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    colorScheme == .dark
                        ? Color(.black).opacity(0.2)
                        : Color(.separatorColor).opacity(0.3)
                )
        )
    }

    private func segmentButton(mode: NotebookViewMode, label: String) -> some View {
        let isActive = dataController.viewMode == mode

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                dataController.viewMode = mode
            }
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isActive ? .primary : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
        }
        .background {
            if isActive {
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        colorScheme == .dark
                            ? Color(.controlColor).opacity(0.3)
                            : Color(.white)
                    )
                    .matchedGeometryEffect(id: "segmentSelector", in: segmentAnimation)
            }
        }
        .shadow(color: isActive
            ? Color(.sRGBLinear, white: 0, opacity: 0.10)
            : .clear, radius: 1)
        .buttonStyle(.plain)
    }

    // MARK: - Action Buttons

    private var publishButton: some View {
        Button {
            dataController.publishDashboard()
        } label: {
            Text("Publish")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .contentShape(Rectangle())
        }
        .buttonStyle(HoverBackgroundButtonStyle())
    }

    private var editPublishedButton: some View {
        Button {
            dataController.unpublishDashboard()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "pencil")
                    .font(.system(size: 11))
                Text("Edit").lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.04))
            .clipShape(.rect(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }

    private var chatButton: some View {
        Button {
            dataController.isRightSidebarVisible.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "bubble.fill")
                    .font(.system(size: 11))
                Text("Chat").lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.04))
            .clipShape(.rect(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

private struct HoverBackgroundButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(isHovered || configuration.isPressed ? 0.06 : 0))
            )
            .onHover { isHovered = $0 }
    }
}
