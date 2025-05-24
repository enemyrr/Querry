import SwiftUI
import AppKit

struct DocumentList: View {
    @State private var viewModel: DocumentListModel
    @State private var searchQueryViewModel: SearchQueryViewModel
    
    init(viewModel: DocumentListModel) {
        self._viewModel = State(wrappedValue: viewModel)
        self.searchQueryViewModel = SearchQueryViewModel(documentListModel: viewModel)
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
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal)
                            }
                        }
                        .id("\(viewModel.lastFetchTimestamp)")
                        .padding(.top)
                        .padding(.bottom, 24) // Space for Floating Action bar
                        
                        Spacer()
                            .frame(height: 40) // Fixed height spacer at the bottom
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay {
                        if viewModel.formattedDocuments.isEmpty && viewModel.isLoading == false {
                            if searchQueryViewModel.query != searchQueryViewModel.defaultQuery {
                                ContentUnavailableView {
                                    Label("No Matching Documents", systemImage: "doc.text.magnifyingglass").font(.title2)
                                } description: {
                                    Text("Your search didn't match any documents in this collection.")
                                } actions: {
                                    Button("Clear Search") {
                                        searchQueryViewModel.clearQuery()
                                    }
                                    .buttonStyle(.plain)
                                }
                            } else {
                                ContentUnavailableView {
                                    Label("No Documents Available", systemImage: "tray").font(.title2)
                                } description: {
                                    Text("This collection doesn't contain any documents yet.\nAdd your first document or import data to get started.")
                                } actions: {
                                    Button("Add Document") {
                                        searchQueryViewModel.showCreateDocumentSheet = true
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .task {
                    if !viewModel.intialLoadComplete {
                        await viewModel.loadDocuments()
                    }
                }
                .background {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.separator, lineWidth: 1)
                }
                .cornerRadius(10)
                
                VStack {
                    Spacer()
                    FloatingActionBar(viewModel: viewModel, searchQueryViewModel: searchQueryViewModel, screenWidth: geometry.size.width)
                        .padding(.bottom, 10)
                }
            }.frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}


