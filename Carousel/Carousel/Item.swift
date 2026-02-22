//
//  Item.swift
//  Carousel
//
//  Created by Brendan Winter on 22/2/2026.
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
