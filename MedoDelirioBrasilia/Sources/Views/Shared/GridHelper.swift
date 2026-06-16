//
//  GridHelper.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 29/08/22.
//

import SwiftUI

class GridHelper {

    static func adaptableColumns(
        gridWidth: CGFloat,
        sizeCategory: ContentSizeCategory,
        spacing: CGFloat
    ) -> [GridItem] {
        if sizeCategory > ContentSizeCategory.large && gridWidth < 440 {
            return [GridItem(.flexible(), spacing: spacing, alignment: .center)]
        }
        let qty = Int(gridWidth / 190)
        guard qty > 0 else {
            return [GridItem(.flexible(), spacing: spacing, alignment: .center)]
        }
        return Array(repeating: GridItem(.flexible(), spacing: spacing, alignment: .center), count: qty)
    }

    static func authorColumns(
        gridWidth: CGFloat,
        spacing: CGFloat
    ) -> [GridItem] {
        if gridWidth < 450 {
            return [GridItem(.flexible(), spacing: spacing, alignment: .center)]
        } else {
            let qty = Int(gridWidth / 300)
            guard qty > 0 else {
                return [GridItem(.flexible(), spacing: spacing, alignment: .center)]
            }
            return Array(repeating: GridItem(.flexible(), spacing: spacing, alignment: .center), count: qty)
        }
    }
}
