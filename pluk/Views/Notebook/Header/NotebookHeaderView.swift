import SwiftUI

struct NotebookHeaderView: View {
    @Bindable var dataController: NotebookDataController

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            StatusDropdown(dataController: dataController)

            TextField("Untitled Notebook", text: $dataController.title)
                .font(.largeTitle.weight(.bold))
                .textFieldStyle(.plain)

            TextField("Add a description...", text: $dataController.descriptionText)
                .font(.body)
                .foregroundStyle(.secondary)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
}

private struct StatusDropdown: View {
    @Bindable var dataController: NotebookDataController
    @State private var isPopoverVisible = false
    @State private var isHovering = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button {
            isPopoverVisible.toggle()
        } label: {
            HStack(spacing: 5) {
                Circle()
                    .strokeBorder(dataController.status.color, lineWidth: 1.5)
                    .frame(width: 10, height: 10)
                Text(dataController.status.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovering ? subtleHoverFill(colorScheme) : .clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
        .popover(isPresented: $isPopoverVisible, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(NotebookStatus.allCases, id: \.self) { status in
                    StatusOptionRow(
                        status: status,
                        isSelected: dataController.status == status
                    ) {
                        dataController.status = status
                        isPopoverVisible = false
                    }
                }
            }
            .padding(6)
            .frame(width: 180)
        }
    }
}

private struct StatusOptionRow: View {
    let status: NotebookStatus
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Circle()
                    .strokeBorder(status.color, lineWidth: 1.5)
                    .background(Circle().fill(isSelected ? status.color : .clear))
                    .frame(width: 12, height: 12)
                Text(status.rawValue)
                    .font(.body)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovering ? subtleHoverFill(colorScheme) : .clear)
            )
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

private func subtleHoverFill(_ colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04)
}
