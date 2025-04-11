//
//  DocumentListModel.swift
//  Collection
//
//  Created by Fauzaan on 2/19/25.
//

import Foundation

@Observable class PaginationManager {
    private(set) var currentPage: Int
    private(set) var itemsPerPage: Int
    private(set) var totalItems: Int
    
    var totalPages: Int {
        return max(1, Int(ceil(Double(totalItems) / Double(itemsPerPage))))
    }
    
    init(itemsPerPage: Int = 25) {
        self.currentPage = 1
        self.itemsPerPage = itemsPerPage
        self.totalItems = 0
    }
    
    func updateTotalItems(_ count: Int) {
        self.totalItems = count
    }
    
    func nextPage() -> Bool {
        guard currentPage < totalPages else { return false }
        currentPage += 1
        return true
    }
    
    func previousPage() -> Bool {
        guard currentPage > 1 else { return false }
        currentPage -= 1
        return true
    }
    
    func goToPage(_ page: Int) -> Bool {
        guard page >= 1 && page <= totalPages else { return false }
        currentPage = page
        return true
    }
    
    var skip: Int {
        return (currentPage - 1) * itemsPerPage
    }
    
    var limit: Int {
        return itemsPerPage
    }
} 
