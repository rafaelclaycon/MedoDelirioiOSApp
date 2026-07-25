import UIKit

// MARK: - Physical Characteristics

extension UIDevice {

    /// In default non-Display Zoom mode, this applies to SE 2, SE 3, XS, 11 Pro, 12 mini, 13 mini.
    static var isSmallDevice: Bool {
        guard UIDevice.deviceType == .iPhone else {
            return false
        }
        return UIScreen.main.bounds.width < 380
    }

    static var isControlCenterAccessibleFromTheTop: Bool {
        guard deviceType != .iPad else { return true }
        return !modelName.contains("SE")
    }

    static var biometricsName: String {
        switch deviceType {
        case .iPhone:
            return modelName.contains("SE") ? "Touch ID" : "Face ID"
        case .iPad:
            return modelName.contains("Pro") ? "Face ID" : "Touch ID"
        case .mac:
            return "Touch ID"
        }
    }
}

// MARK: - Software Characteristics

extension UIDevice {

    static var isIOS26OrLater: Bool {
        if #available(iOS 26.0, *) {
            return true
        }
        return false
    }

    static var systemMarketingName: String {
        switch deviceType {
        case .iPhone:
            return "iOS"
        case .iPad:
            return "iPadOS"
        case .mac:
            return "macOS"
        }
    }
}

// MARK: - Is specific device

enum MedoSupportedDevice {

    case iPhone, iPad, mac
}

extension UIDevice {
    
    static var deviceType: MedoSupportedDevice {
        if current.userInterfaceIdiom == .phone {
            return .iPhone
        } else if current.userInterfaceIdiom == .pad {
            return .iPad
        } else {
            return .mac
        }
    }

    static var deviceGenericName: String {
        switch deviceType {
        case .iPhone:
            return "iPhone"
        case .iPad:
            return "iPad"
        case .mac:
            return "Mac"
        }
    }
}

// MARK: - Device Info

public extension UIDevice {

    static let modelName: String = {
        func hardwareModelIdentifier() -> String {
            var size = 0
            sysctlbyname("hw.model", nil, &size, nil, 0)
            var buffer = [CChar](repeating: 0, count: size)
            sysctlbyname("hw.model", &buffer, &size, nil, 0)
            return String(cString: buffer)
        }

        if ProcessInfo.processInfo.isiOSAppOnMac {
            let internalId = hardwareModelIdentifier()
            return mapToDevice(identifier: internalId)
        }

        if ProcessInfo.processInfo.isMacCatalystApp {
            return "Mac Catalyst"
        }

        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        
        func mapToDevice(identifier: String) -> String { // swiftlint:disable:this cyclomatic_complexity
            #if os(iOS)
            switch identifier {
            case "iPhone11,8":                                     return "iPhone XR" // 2018 - A12 (4E,2P) - 3 GB
            case "iPhone11,2":                                     return "iPhone XS" // 2018 - A12 (4E,2P) - 4 GB
            case "iPhone11,4", "iPhone11,6":                       return "iPhone XS Max" // 2018 - A12 (4E,2P) - 4 GB
            case "iPhone12,1":                                     return "iPhone 11" // 2019 - A13 - 4 GB
            case "iPhone12,3":                                     return "iPhone 11 Pro" // 2019 - A13 - 4 GB
            case "iPhone12,5":                                     return "iPhone 11 Pro Max" // 2019 - A13 - 4 GB
            case "iPhone12,8":                                     return "iPhone SE (2nd generation)" // 2020 - A13 - 3 GB
            case "iPhone13,1":                                     return "iPhone 12 mini" // 2020 - A14 - 4 GB
            case "iPhone13,2":                                     return "iPhone 12" // 2020 - A14 - 4 GB
            case "iPhone13,3":                                     return "iPhone 12 Pro" // 2020 - A14 - 6 GB
            case "iPhone13,4":                                     return "iPhone 12 Pro Max" // 2020 - A14 - 6 GB
            case "iPhone14,4":                                     return "iPhone 13 mini" // 2021 - A15
            case "iPhone14,5":                                     return "iPhone 13" // 2021 - A15
            case "iPhone14,2":                                     return "iPhone 13 Pro" // 2021 - A15
            case "iPhone14,3":                                     return "iPhone 13 Pro Max" // 2021 - A15
            case "iPhone14,6":                                     return "iPhone SE (3rd generation)" // 2022 - A15
            case "iPhone14,7":                                     return "iPhone 14" // 2022 - A15
            case "iPhone14,8":                                     return "iPhone 14 Plus" // 2022 - A15
            case "iPhone15,2":                                     return "iPhone 14 Pro" // 2022 - A16
            case "iPhone15,3":                                     return "iPhone 14 Pro Max" // 2022 - A16
            case "iPhone15,4":                                     return "iPhone 15" // 2023 - A16
            case "iPhone15,5":                                     return "iPhone 15 Plus" // 2023 - A16
            case "iPhone16,1":                                     return "iPhone 15 Pro" // 2023 - A17 Pro (4E,2P) - 8 GB
            case "iPhone16,2":                                     return "iPhone 15 Pro Max" // 2023 - A17 Pro
            case "iPhone17,3":                                     return "iPhone 16" // 2024 - A18
            case "iPhone17,4":                                     return "iPhone 16 Plus" // 2024 - A18
            case "iPhone17,1":                                     return "iPhone 16 Pro" // 2024 - A18 Pro - 8 GB
            case "iPhone17,2":                                     return "iPhone 16 Pro Max" // 2024 - A18 Pro - 8 GB
            case "iPhone17,5":                                     return "iPhone 16e" // 2025 - A18 (4E,2P) - 8 GB
            case "iPhone18,1":                                     return "iPhone 17 Pro" // 2025 - A19 Pro (4E,2P) - 12 GB
            case "iPhone18,2":                                     return "iPhone 17 Pro Max" // 2025 - A19 Pro (4E,2P) - 12 GB
            case "iPhone18,3":                                     return "iPhone 17" // 2025 - A19 (4E,2P) - 8 GB
            case "iPhone18,4":                                     return "iPhone Air" // 2025 - A19 Pro (4E,2P) - 12 GB
            case "iPhone18,5":                                     return "iPhone 17e" // 2026 - A19 (4E,2P) - 8 GB

            case "iPad7,5", "iPad7,6":                             return "iPad (6th generation)" // 2018 - A10 (2E,2P) - 2 GB
            case "iPad7,11", "iPad7,12":                           return "iPad (7th generation)" // 2019 - A10 - 3 GB
            case "iPad11,6", "iPad11,7":                           return "iPad (8th generation)" // 2020 - A12 - 3 GB
            case "iPad12,1", "iPad12,2":                           return "iPad (9th generation)" // 2021 - A13 - 3 GB
            case "iPad13,18", "iPad13,19":                         return "iPad (10th generation)" // 2022 - A14 (4E,2P) - 4 GB
            case "iPad15,7":                                       return "iPad (A16)" // 2025 - A16 (3E,2P) - 6 GB

            case "iPad11,3", "iPad11,4":                           return "iPad Air (3rd generation)" // 2019 - A12 (4E, 2P) - 3 GB
            case "iPad13,1", "iPad13,2":                           return "iPad Air (4th generation)" // 2020 - A14 (4E, 2P) - 4 GB
            case "iPad13,16", "iPad13,17":                         return "iPad Air (5th generation)" // 2022 - M1 - 8 GB
            case "iPad14,8":                                       return "iPad Air 11-inch (M2)" // 2024 - M2 - 8 GB
            case "iPad14,10":                                      return "iPad Air 13-inch (M2)" // 2024 - M2 - 8 GB
            case "iPad15,3":                                       return "iPad Air 11-inch (M3)" // 2025 - M3 - 8 GB
            case "iPad15,5":                                       return "iPad Air 13-inch (M3)" // 2025 - M3 - 8 GB
            case "iPad16,9":                                       return "iPad Air 11-inch (M4)" // 2026 - M4 - 12 GB
            case "iPad16,11":                                      return "iPad Air 13-inch (M4)" // 2026 - M4 - 12 GB

            case "iPad11,1", "iPad11,2":                           return "iPad mini (5th generation)" // 2019 - A12 - 3 GB
            case "iPad14,1", "iPad14,2":                           return "iPad mini (6th generation)" // 2021 - A15 - 4 GB
            case "iPad16,1", "iPad16,2":                           return "iPad mini (A17 Pro)" // 2024 - A17 Pro - 8 GB

            case "iPad7,3", "iPad7,4":                             return "iPad Pro (10.5-inch)" // 2017 - A10X (3E,3P) - 4 GB
            case "iPad8,1", "iPad8,2", "iPad8,3", "iPad8,4":       return "iPad Pro (11-inch) (1st generation)" // 2018 - A12X - 4 or 6 GB
            case "iPad8,9", "iPad8,10":                            return "iPad Pro (11-inch) (2nd generation)" // 2020 - A12Z - 6 GB
            case "iPad13,4", "iPad13,5", "iPad13,6", "iPad13,7":   return "iPad Pro (11-inch) (3rd generation)" // 2021 - M1 - 8 or 16 GB
            case "iPad14,3", "iPad14,4":                           return "iPad Pro (11-inch) (4th generation)" // 2022 - M2 - 8 or 16 GB
            case "iPad7,1", "iPad7,2":                             return "iPad Pro (12.9-inch) (2nd generation)" // 2017 - A10X - 4 GB
            case "iPad8,5", "iPad8,6", "iPad8,7", "iPad8,8":       return "iPad Pro (12.9-inch) (3rd generation)" // 2018 - A12X - 4 or 6 GB
            case "iPad8,11", "iPad8,12":                           return "iPad Pro (12.9-inch) (4th generation)" // 2020 - A12Z - 6 GB
            case "iPad13,8", "iPad13,9", "iPad13,10", "iPad13,11": return "iPad Pro (12.9-inch) (5th generation)" // 2021 - M1 - 8 or 16 GB
            case "iPad14,5", "iPad14,6":                           return "iPad Pro (12.9-inch) (6th generation)" // 2022 - M2 - 8 or 16 GB
            case "iPad16,3","iPad16,4":                            return "iPad Pro 11-inch (M4)" // 2024 - M4 (6E,3-4P) - 8 or 16 GB
            case "iPad16,5","iPad16,6":                            return "iPad Pro 13-inch (M4)" // 2024 - M4 (6E,3-4P) - 8 or 16 GB
            case "iPad17,1","iPad17,2":                            return "iPad Pro 11-inch (M5)" // 2025 - M5 (6E,3-4P) - 12 or 16 GB
            case "iPad17,3","iPad17,4":                            return "iPad Pro 13-inch (M5)" // 2025 - M5 (6E,3-4P) - 12 or 16 GB

            case "MacBookAir10,1":                                 return "MacBook Air (M1, 2020)"
            case "Mac14,5":                                        return "MacBook Pro (14-inch, 2023)" // M2
            case "Mac14,13":                                       return "Mac Studio (M2 Max, 2023)"
            case "Mac16,1":                                        return "MacBook Pro (14-inch, M4, 2024)"
            case "Mac16,5":                                        return "MacBook Pro (16-inch, 2024)" // M4
            case "Mac16,6":                                        return "MacBook Pro (14-inch, M4 Pro, 2024)"
            case "Mac16,8":                                        return "MacBook Pro (14-inch, M4 Max, 2024)"
            case "Mac17,2":                                        return "MacBook Pro (14-inch, M5)"
            case "Mac17,3":                                        return "MacBook Air (13-inch, M5)"
            case "Mac17,4":                                        return "MacBook Air (15-inch, M5)"
            case "Mac17,6":                                        return "MacBook Pro (16-inch, M5 Pro)"
            case "Mac17,7":                                        return "MacBook Pro (14-inch, M5 Pro)"
            case "Mac17,8":                                        return "MacBook Pro (16-inch, M5 Max)"
            case "Mac17,9":                                        return "MacBook Pro (14-inch, M5 Max)"

            case "RealityDevice14,1":                              return "Apple Vision Pro (M2, Original)" // 2024 - M2 (4E,4P) - 16 GB
            case "RealityDevice17,1":                              return "Apple Vision Pro (M5)" // 2025 - M5 (9 or 10 cores) - 16 GB

            case "i386", "x86_64", "arm64":                        return "Simulator \(mapToDevice(identifier: ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "iOS"))"
            default:                                              return identifier
            }
            #endif
        }
        
        return mapToDevice(identifier: identifier)
    }()
}
