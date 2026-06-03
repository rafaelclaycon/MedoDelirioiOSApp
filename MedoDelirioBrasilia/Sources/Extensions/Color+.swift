//
//  Color+.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 19/05/22.
//

import SwiftUI

// MARK: - Custom colors
public extension Color {

    static let mutedNavyBlue = Color(UIColor(red: 0.07, green: 0.20, blue: 0.37, alpha: 1.00))
    static let darkerGreen = Color(UIColor(red: 0.00, green: 0.64, blue: 0.02, alpha: 1.00))
    static let darkestGreen = Color(UIColor(red: 0.01, green: 0.20, blue: 0.00, alpha: 1.00))
    static let hitsMedoDelirioSpotify = Color(UIColor(red: 0.02, green: 0.07, blue: 0.53, alpha: 1.00))
    static let systemBackground = Color(UIColor.systemBackground)

    // From the logo
    static let brightGreen = Color(UIColor(red: 0.49, green: 0.84, blue: 0.39, alpha: 1.00))
    static let brightYellow = Color(UIColor(red: 1.00, green: 0.98, blue: 0.36, alpha: 1.00))
    
    // Pastels
    static let pastelPurple = Color(UIColor(red: 0.81, green: 0.76, blue: 0.98, alpha: 1.00))
    static let pastelBabyBlue = Color(UIColor(red: 0.64, green: 0.84, blue: 0.95, alpha: 1.00))
    static let pastelBrightGreen = Color(UIColor(red: 0.75, green: 0.97, blue: 0.70, alpha: 1.00))
    static let pastelYellow = Color(UIColor(red: 0.98, green: 0.90, blue: 0.71, alpha: 1.00))
    static let pastelOrange = Color(UIColor(red: 0.96, green: 0.76, blue: 0.69, alpha: 1.00))
    static let pastelPink = Color(UIColor(red: 0.95, green: 0.68, blue: 0.78, alpha: 1.00))
    static let pastelGray = Color(UIColor(red: 0.82, green: 0.84, blue: 0.86, alpha: 1.00))
    static let pastelRoyalBlue = Color(UIColor(red: 0.64, green: 0.78, blue: 0.98, alpha: 1.00))
    static let pastelMutedGreen = Color(UIColor(red: 0.64, green: 0.85, blue: 0.83, alpha: 1.00))
    static let pastelRed = Color(UIColor(red: 0.93, green: 0.64, blue: 0.67, alpha: 1.00))
    static let pastelBeige = Color(UIColor(red: 0.91, green: 0.87, blue: 0.84, alpha: 1.00))

    // Main View Selector
    static let whatsAppLightGreen = Color(UIColor(red: 0.88, green: 0.99, blue: 0.84, alpha: 1.00))
    static let whatsAppDarkGreen = Color(UIColor(red: 0.18, green: 0.37, blue: 0.25, alpha: 1.00))

    // Episodes – Bookmarks
    static let rubyRed = Color(red: 0.8, green: 0.07, blue: 0.14)
    static let darkerOrange = Color(UIColor(red: 0.80, green: 0.45, blue: 0.0, alpha: 1.00))
}

extension Color {

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    func darkened(by amount: Double = 0.2) -> Color {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(hue: h, saturation: s, brightness: max(0, b - amount))
    }
}
