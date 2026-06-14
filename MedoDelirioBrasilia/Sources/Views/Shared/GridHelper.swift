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
        spacing: CGFloat,
        deviceType: MedoSupportedDevice
    ) -> [GridItem] {
        if UIDevice.deviceType == .iPhone {
            return [
                GridItem(.flexible(), spacing: spacing, alignment: .center)
            ]
        } else {
            if gridWidth < 600 {
                return [
                    GridItem(.flexible(), spacing: spacing, alignment: .center)
                ]
            } else if gridWidth < 850 {
                return [
                    GridItem(.flexible(), spacing: spacing, alignment: .center),
                    GridItem(.flexible(), spacing: spacing, alignment: .center)
                ]
            } else if gridWidth < 1200 {
                return [
                    GridItem(.flexible(), spacing: spacing, alignment: .center),
                    GridItem(.flexible(), spacing: spacing, alignment: .center),
                    GridItem(.flexible(), spacing: spacing, alignment: .center)
                ]
            } else if gridWidth < 2000 {
                return [
                    GridItem(.flexible(), spacing: spacing, alignment: .center),
                    GridItem(.flexible(), spacing: spacing, alignment: .center),
                    GridItem(.flexible(), spacing: spacing, alignment: .center),
                    GridItem(.flexible(), spacing: spacing, alignment: .center)
                ]
            } else {
                return [
                    GridItem(.flexible(), spacing: spacing, alignment: .center),
                    GridItem(.flexible(), spacing: spacing, alignment: .center),
                    GridItem(.flexible(), spacing: spacing, alignment: .center),
                    GridItem(.flexible(), spacing: spacing, alignment: .center),
                    GridItem(.flexible(), spacing: spacing, alignment: .center)
                ]
            }
        }
    }
}
