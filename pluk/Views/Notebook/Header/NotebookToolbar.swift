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

            Button {
                dataController.isRightSidebarVisible.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "bubble.fill")
                        .font(.system(size: 11))
//                        .foregroundStyle(Color.accentColor)
                    Text("Chat").lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.06))
//                .foregroundStyle(.secondary)
                .clipShape(.rect(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
        .fixedSize()
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
    }
}
