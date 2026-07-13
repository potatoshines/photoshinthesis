//
//  Item.swift
//  Photoshinthesis
//
//  Created by Shin Aung on 7/12/26.
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
