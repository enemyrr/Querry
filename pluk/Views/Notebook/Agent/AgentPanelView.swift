import SwiftUI

struct AgentPanelView: View {

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            emptyState
            Spacer()
            chatInput
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack {
            Image(systemName: "sparkles")
                .foregroundStyle(.purple)
            Text("Notebook Agent")
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 36))
                .foregroundStyle(.quaternary)
            Text("Ask the agent to help you explore your data, write queries, or build visualizations.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer()
        }
    }

    private var chatInput: some View {
        HStack(spacing: 8) {
            TextField("Ask anything...", text: .constant(""))
                .textFieldStyle(.plain)
                .padding(8)
                .background(.quinary)
                .clipShape(.rect(cornerRadius: 8))
            Button {
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.purple)
            }
            .buttonStyle(.plain)
            .disabled(true)
        }
        .padding()
    }
}
