import SwiftUI

struct AgentPanelView: View {
    var dataController: NotebookDataController
    @State private var message = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            AgentHeader(dataController: dataController)
            Spacer()
            AgentEmptyState(message: $message)
            AgentChatInput(message: $message, isInputFocused: $isInputFocused)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            isInputFocused = true
        }
    }
}

private struct AgentHeader: View {
    var dataController: NotebookDataController

    var body: some View {
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
}

private struct AgentEmptyState: View {
    @Binding var message: String

    var body: some View {
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
}

private struct AgentChatInput: View {
    @Binding var message: String
    var isInputFocused: FocusState<Bool>.Binding

    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .topLeading) {
                if message.isEmpty {
                    Text("Ask data question...")
                        .font(.title3)
                        .foregroundStyle(.placeholder)
                        .padding(.leading, 8)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $message)
                    .font(.title3)
                    .scrollContentBackground(.hidden)
                    .focused(isInputFocused)
                    .padding(.leading, 4)
                    .frame(maxWidth: .infinity, minHeight: 34, maxHeight: 160)
                    .fixedSize(horizontal: false, vertical: true)
            }

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
            RoundedRectangle(cornerRadius: 14)
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
            .padding(8)
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
