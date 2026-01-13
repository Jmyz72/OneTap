//
//  SubCategoryModel.swift
//  OneTap
//
//  Created by Jimmy Hew on 30/12/2025.
//

import Foundation
import SwiftUI
@preconcurrency internal import CoreData

extension SubCategory {
    var displayIcon: String {
        if let icon = icon, !icon.isEmpty {
            return icon
        }
        return category?.iconName ?? "questionmark.circle.fill"
    }
}
