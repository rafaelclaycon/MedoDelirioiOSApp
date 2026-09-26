//
//  APIConfig.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 21/09/24.
//

import Foundation

final class APIConfig {

    static var baseServerURL: String {
        switch ProcessInfo.processInfo.environment["api_environment"] {
        case "local":
            return "http://127.0.0.1:8080/"
        case "dev":
            return "https://api.medodelirioios.club/"
        default:
            return "https://api.medodelirioios.com/"
        }
    }

    static var apiURL: String {
        self.baseServerURL + "api/"
    }

    /// The election Live Activity is tested on the dev server before production gets the
    /// code, so the beta app asks it for the election state. Only the beta: TestFlight
    /// builds don't carry the scheme's `api_environment`, which still wins from Xcode.
    static var electionAPIURL: String {
        guard ProcessInfo.processInfo.environment["api_environment"] == nil,
              Bundle.main.bundleIdentifier == "com.rafaelschmitt.MedoDelirioBrasilia.beta"
        else {
            return apiURL
        }
        return "https://api.medodelirioios.club/api/"
    }

    static var baseLinkURL: String {
        switch ProcessInfo.processInfo.environment["api_environment"] {
        case "dev":
            return "https://api.medodelirioios.club/"
        default:
            return "https://medodelirioios.com/"
        }
    }
}
