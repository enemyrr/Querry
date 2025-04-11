import SwiftUI
import AppKit

struct DocumentList: View {
    @State private var viewModel: DocumentListModel
    
    init(viewModel: DocumentListModel) {
        self._viewModel = State(wrappedValue: viewModel)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.formattedDocuments, id: \.self) { document in
                                DocumentRow(
                                    viewModel: DocumentRowViewModel(
                                        document: document,
                                        documentListViewModel: viewModel)
                                )
                                .transition(.opacity)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal)
                            }
                        }
                        .id("\(viewModel.lastFetchTimestamp)")
                        .padding(.top)
                        .padding(.bottom, 24) // Space for Floating Action bar
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .task {
                    await viewModel.loadDocuments()
                }
                .background {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.separator, lineWidth: 1)
                }
                
                VStack {
                    StatusToast(isLoading: viewModel.isLoading)
                        .padding(.top, 10)
                    Spacer()
                    FloatingActionBar(viewModel: viewModel, screenWidth: geometry.size.width)
                        .padding(.bottom, 16)
                }
            }.frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}


