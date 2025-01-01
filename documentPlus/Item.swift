//
//  Item.swift
//  documentPlus
//
//  Created by Fauzaan on 12/31/24.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class Item {
    var timestamp: Date

    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
