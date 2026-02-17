import SwiftUI

struct NotebookToolbar: View {

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
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
