import AppKit
import SwiftUI

final class NotebookActionBarView: NSView {

    private let dataController: NotebookDataController
    private let insertionIndex: Int?
    private let onDidInsert: (() -> Void)?
    private var hostingView: NSHostingView<AnyView>?

    init(dataController: NotebookDataController, insertionIndex: Int? = nil, onDidInsert: (() -> Void)? = nil) {
        self.dataController = dataController
        self.insertionIndex = insertionIndex
        self.onDidInsert = onDidInsert
        super.init(frame: .zero)

        wantsLayer = true
        setupBar()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var intrinsicContentSize: NSSize {
        guard let hostingView else { return super.intrinsicContentSize }
        let topPadding: CGFloat = insertionIndex == nil ? 16 : 0
        let size = hostingView.fittingSize
        return NSSize(width: size.width, height: size.height + topPadding)
    }

    private func setupBar() {
        let barContent = NotebookActionBarContent(
            dataController: dataController,
            insertionIndex: insertionIndex,
            onDidInsert: onDidInsert
        )
        let hosting = NSHostingView(rootView: AnyView(barContent))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hosting)
        hostingView = hosting

        let topPadding: CGFloat = insertionIndex == nil ? 16 : 0

        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: topAnchor, constant: topPadding),
            hosting.centerXAnchor.constraint(equalTo: centerXAnchor),
            hosting.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
}

// MARK: - SwiftUI bar content matching FloatingActionBar visual language

private struct NotebookActionBarContent: View {
    let dataController: NotebookDataController
    let insertionIndex: Int?
    let onDidInsert: (() -> Void)?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 5) {
            ForEach(Array(NotebookCellType.allCases.enumerated()), id: \.element) { index, type in
                let isEnabled = type == .chart || type == .text

                NotebookActionButton(type: type, isEnabled: isEnabled) {
                    handleCellType(type)
                }

                if index < NotebookCellType.allCases.count - 1 {
                    Divider()
                        .frame(height: 22)
                }
            }
        }
        .padding(8)
        .modifier(GlassBackgroundStyle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.separator, lineWidth: colorScheme == .dark ? 1 : 0.5)
        )
    }

    private func handleCellType(_ type: NotebookCellType) {
        switch type {
        case .chart:
            if let index = insertionIndex {
                dataController.insertChartBlock(at: index)
            } else {
                dataController.addChartBlock()
            }
        case .text:
            if let index = insertionIndex {
                dataController.insertTextBlock(at: index)
            } else {
                dataController.addTextBlock()
            }
        default:
            break
        }
        onDidInsert?()
    }
}

private struct NotebookActionButton: View {
    let type: NotebookCellType
    let isEnabled: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: type.icon)
                    .font(.system(size: 14))
                    .frame(width: 16, height: 16)
                Text(type.rawValue)
                    .font(.system(size: 12))
            }
            .foregroundStyle(isHovering ? .primary : .secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(ActionButtonStyle(padding: EdgeInsets(top: 7, leading: 8, bottom: 7, trailing: 8)))
        .opacity(isEnabled ? 1.0 : 0.4)
        .allowsHitTesting(isEnabled)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
