//
//  GridHelper.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 29/08/22.
//

import SwiftUI

class GridHelper {

    static func adaptableColumns(
        listWidth: CGFloat,
        sizeCategory: ContentSizeCategory,
        spacing: CGFloat,
        deviceType: MedoSupportedDevice
    ) -> [GridItem] {
        if deviceType == .iPhone {
            if sizeCategory > ContentSizeCategory.large {
                return [
                    GridItem(.flexible(), spacing: spacing, alignment: .center)
                ]
            } else {
                return [
                    GridItem(.flexible(), spacing: spacing, alignment: .center),
                    GridItem(.flexible(), spacing: spacing, alignment: .center)
                ]
            }
        } else {
            if listWidth < 500 {
                return [
                    GridItem(.flexible(), spacing: spacing, alignment: .center)
                ]
            } else {
                let qty = Int(listWidth / (deviceType == .mac ? 320 : 220))
                return Array(repeating: GridItem(.flexible(), spacing: spacing, alignment: .center), count: qty)
            }
        }
    }

    static func authorColumns(
        gridWidth: CGFloat,
        spacing: CGFloat
    ) -> [GridItem] {
        if gridWidth < 450 {
            return [GridItem(.flexible(), spacing: spacing, alignment: .center)]
        } else {
            let qty = Int(gridWidth / 300)
            return Array(repeating: GridItem(.flexible(), spacing: spacing, alignment: .center), count: qty)
        }
    }
}
