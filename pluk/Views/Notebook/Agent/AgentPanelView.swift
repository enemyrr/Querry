import SwiftUI

struct AgentPanelView: View {
    var dataController: NotebookDataController

    var body: some View {
        VStack(spacing: 0) {
            header
            Spacer()
            emptyState
            chatInput
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack(spacing: 0) {
            AgentHeaderTextButton(label: "New AI Chat") {
            }

            Spacer()

            HStack(spacing: 4) {
                AgentHeaderButton(icon: "square.and.pencil", size: 13, weight: .medium, iconOffset: -1) {
                }

                AgentHeaderButton(icon: "xmark", size: 11, weight: .medium) {
                    dataController.isRightSidebarVisible = false
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 0) {
            AgentSuggestionRow(icon: "chart.bar.xaxis", label: "Build a chart") {
                message = "Build a chart"
            }
            AgentSuggestionRow(icon: "sparkle.magnifyingglass", label: "Explore this data") {
                message = "Explore this data"
            }
            AgentSuggestionRow(icon: "chart.bar", label: "Summarize key insights") {
                message = "Summarize key insights"
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
    }

    @State private var message = ""
    @FocusState private var isInputFocused: Bool

    private var chatInput: some View {
        VStack(spacing: 6) {
            HStack {
                TextField("Ask data question...", text: $message)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($isInputFocused)
                    .onSubmit {
                    }
                    .padding(.leading, 8)
            }
            .frame(maxWidth: .infinity)

            HStack(alignment: .bottom, spacing: 8) {
                Spacer()

                Button {
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 13, weight: .bold))
                }
                .buttonStyle(ChatSendButtonStyle())
                .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.leading, 2)
        }
        .padding(.top, 10)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .circular)
                .fill(.background)
                .strokeBorder(.separator.opacity(0.5), lineWidth: 1)
                .shadow(color: .black.opacity(0.03), radius: 1, y: 1)
        )
        .padding(.horizontal, 4)
        .padding(.bottom, 4)
    }
}

private struct AgentHeaderButton: View {
    let icon: String
    var size: CGFloat = 13
    var weight: Font.Weight = .regular
    var iconOffset: CGFloat = 0
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: weight))
                .foregroundStyle(.secondary)
                .offset(y: iconOffset)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(
                            isHovering
                            ? (colorScheme == .dark
                               ? Color.white.opacity(0.08)
                               : Color.black.opacity(0.06))
                            : Color.clear
                        )
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

private struct AgentSuggestionRow: View {
    let icon: String
    let label: String
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        isHovering
                        ? (colorScheme == .dark
                           ? Color.white.opacity(0.06)
                           : Color.black.opacity(0.04))
                        : Color.clear
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

private struct AgentHeaderTextButton: View {
    let label: String
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.body)
                    .fontWeight(.medium)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        isHovering
                        ? (colorScheme == .dark
                           ? Color.white.opacity(0.06)
                           : Color.black.opacity(0.04))
                        : Color.clear
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
