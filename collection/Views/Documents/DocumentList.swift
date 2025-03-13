import SwiftUI
import AppKit

struct DocumentList: View {
    @StateObject private var viewModel: DocumentViewModel
    
    init(instance: ConnectionInstance, selectedTab: DatabaseTab) {
        self._viewModel = StateObject(wrappedValue: DocumentViewModel(
            instance: instance,
            selectedTab: selectedTab
        ))
    }
    
    var body: some View {
        ZStack {
            VStack {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.formattedDocuments, id: \.self) { document in
                            DocumentRow(
                                document: document,
                                parentViewModel: viewModel
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top)
                    .padding(.bottom, 24) // Space for pagination
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
                FloatingActionBar(viewModel: viewModel)
                    .padding(.bottom, 16)
            }
        }
    }
    
    
    // Convert natural language to database query
    private func convertToSearchQuery(_ naturalLanguage: String) -> String {
        // This would use AI to convert natural language to a proper query
        // For now, we'll just simulate some basic conversions
        
        if naturalLanguage.lowercased().contains("payment") && naturalLanguage.lowercased().contains("rejected") {
            return "{ action: \"reject\", entity: \"payment-voucher\" }"
        } else if naturalLanguage.lowercased().contains("approved") {
            return "{ action: \"approve\" }"
        } else if naturalLanguage.lowercased().contains("created") {
            return "{ action: \"create\" }"
        }
        
        // Default case - just use as is
        return naturalLanguage
    }
    
    // Search function
    private func performSearch(_ query: String) {
        Task {
            await viewModel.loadDocuments()
        }
    }
}


