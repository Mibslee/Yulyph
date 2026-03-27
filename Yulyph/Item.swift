//
//  Item.swift
//  Yulyph
//
//  Created by Peishen Li on 2026/3/28.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
