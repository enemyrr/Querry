import SwiftUI

struct NotebookEmptyStateView: View {
    let dataController: NotebookDataController

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 12) {
                Text("What would you like to know?")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Start by connecting a data source or adding a cell.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ConnectionChips(connections: dataController.connections)

            CellTypeToolbar(dataController: dataController)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

private struct ConnectionChips: View {
    let connections: [Connection]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Connect your data")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(connections, id: \.persistentModelID) { connection in
                        ConnectionChip(connection: connection)
                    }

                    if connections.isEmpty {
                        Text("No connections yet")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    }
                }
            }
        }
        .frame(maxWidth: 480)
    }
}

private struct ConnectionChip: View {
    let connection: Connection

    var body: some View {
        Button {
        } label: {
            HStack(spacing: 6) {
                Image(connection.databaseType.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
                Text(connection.name)
                    .font(.caption)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.quinary)
            .clipShape(.rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

private struct CellTypeToolbar: View {
    let dataController: NotebookDataController

    var body: some View {
        HStack(spacing: 8) {
            ForEach(NotebookCellType.allCases, id: \.self) { type in
                CellTypeButton(type: type) {
                    handleCellType(type)
                }
            }
        }
    }

    private func handleCellType(_ type: NotebookCellType) {
        switch type {
        case .chart:
            dataController.addChartBlock()
        default:
            break
        }
    }
}
