import SwiftUI

struct NotebookToolbar: View {
    @Bindable var dataController: NotebookDataController

    var body: some View {
        HStack(spacing: 8) {
            Button {
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
                    .font(.subheadline)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Button {
            } label: {
                Label("Publish", systemImage: "globe")
                    .font(.subheadline)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Divider()
                .frame(height: 16)

            Button {
                dataController.isRightSidebarVisible.toggle()
            } label: {
                Image(systemName: "sidebar.right")
                    .font(.system(size: 14))
                    .foregroundStyle(dataController.isRightSidebarVisible ? .primary : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
