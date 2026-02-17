import SwiftUI

struct NotebookHeaderView: View {
    @Bindable var dataController: NotebookDataController

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            statusDropdown

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

    private var statusDropdown: some View {
        Menu {
            ForEach(NotebookStatus.allCases, id: \.self) { status in
                Button {
                    dataController.status = status
                } label: {
                    HStack {
                        Circle()
                            .fill(status.color)
                            .frame(width: 8, height: 8)
                        Text(status.rawValue)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Circle()
                    .fill(dataController.status.color)
                    .frame(width: 8, height: 8)
                Text(dataController.status.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quinary)
            .clipShape(.rect(cornerRadius: 6))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}
