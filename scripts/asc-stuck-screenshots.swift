#!/usr/bin/env swift
//
// Finds App Store screenshots stuck mid-upload on an App Store Connect version, which block
// "Add for Review" and have no delete button on the website, and optionally deletes them.
//
// Usage:
//   swift scripts/asc-stuck-screenshots.swift --key-id <KEY_ID> --issuer <ISSUER_ID> --key <AuthKey.p8> [--version 13.1] [--bundle-id <id>] [--delete]
//
// The key comes from App Store Connect > Users and Access > Integrations (App Manager or Admin).
// Without --delete it only lists. With --delete it asks before deleting anything.

import CryptoKit
import Foundation

// MARK: - Arguments

func argument(_ name: String) -> String? {
    guard let index = CommandLine.arguments.firstIndex(of: name), index + 1 < CommandLine.arguments.count else { return nil }
    return CommandLine.arguments[index + 1]
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("Error: \(message)\n".utf8))
    exit(1)
}

guard let keyId = argument("--key-id"), let issuer = argument("--issuer"), let keyPath = argument("--key") else {
    fail("usage: swift scripts/asc-stuck-screenshots.swift --key-id <KEY_ID> --issuer <ISSUER_ID> --key <AuthKey.p8> [--version 13.1] [--bundle-id <id>] [--delete]")
}
let versionString = argument("--version") ?? "13.1"
let bundleId = argument("--bundle-id") ?? "com.rafaelschmitt.MedoDelirioBrasilia"
let shouldDelete = CommandLine.arguments.contains("--delete")

// MARK: - Token

func base64URL(_ data: Data) -> String {
    data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

/// ES256 JWT for the App Store Connect API, valid for 20 minutes (the maximum).
func makeToken() -> String {
    guard let pem = try? String(contentsOfFile: (keyPath as NSString).expandingTildeInPath, encoding: .utf8) else {
        fail("can't read the key at \(keyPath)")
    }
    guard let key = try? P256.Signing.PrivateKey(pemRepresentation: pem) else {
        fail("\(keyPath) isn't an App Store Connect .p8 key")
    }
    let now = Int(Date().timeIntervalSince1970)
    let header = try! JSONSerialization.data(withJSONObject: ["alg": "ES256", "kid": keyId, "typ": "JWT"])
    let payload = try! JSONSerialization.data(withJSONObject: ["iss": issuer, "iat": now, "exp": now + 20 * 60, "aud": "appstoreconnect-v1"])
    let signingInput = base64URL(header) + "." + base64URL(payload)
    let signature = try! key.signature(for: Data(signingInput.utf8))
    return signingInput + "." + base64URL(signature.rawRepresentation)
}

let token = makeToken()

// MARK: - API

let baseURL = "https://api.appstoreconnect.apple.com"

@discardableResult
func request(_ method: String, _ path: String) async -> [String: Any] {
    var request = URLRequest(url: URL(string: baseURL + path)!)
    request.httpMethod = method
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    let data: Data
    let response: URLResponse
    do {
        (data, response) = try await URLSession.shared.data(for: request)
    } catch {
        fail("\(method) \(path): \(error.localizedDescription)")
    }
    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
    guard (200..<300).contains(status) else {
        fail("\(method) \(path) answered \(status): \(String(decoding: data, as: UTF8.self))")
    }
    guard !data.isEmpty else { return [:] }
    return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
}

func items(_ response: [String: Any]) -> [[String: Any]] {
    response["data"] as? [[String: Any]] ?? []
}

func id(_ item: [String: Any]) -> String {
    item["id"] as? String ?? "?"
}

func attributes(_ item: [String: Any]) -> [String: Any] {
    item["attributes"] as? [String: Any] ?? [:]
}

func query(_ value: String) -> String {
    value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
}

// MARK: - Main

struct Screenshot {
    let id: String
    let locale: String
    let displayType: String
    let fileName: String
    let state: String
    let errors: String
}

guard let app = items(await request("GET", "/v1/apps?filter[bundleId]=\(query(bundleId))")).first else {
    fail("no app with bundle ID \(bundleId) for this key")
}
guard let version = items(await request("GET", "/v1/apps/\(id(app))/appStoreVersions?filter[versionString]=\(query(versionString))&filter[platform]=IOS")).first else {
    fail("no iOS version \(versionString) on App Store Connect")
}
print("App \(id(app)), version \(versionString) (\(attributes(version)["appStoreState"] as? String ?? "?"))")

var screenshots: [Screenshot] = []
let localizations = items(await request("GET", "/v1/appStoreVersions/\(id(version))/appStoreVersionLocalizations?limit=200"))
for localization in localizations {
    let locale = attributes(localization)["locale"] as? String ?? "?"
    let sets = items(await request("GET", "/v1/appStoreVersionLocalizations/\(id(localization))/appScreenshotSets?limit=50"))
    for set in sets {
        let displayType = attributes(set)["screenshotDisplayType"] as? String ?? "?"
        for screenshot in items(await request("GET", "/v1/appScreenshotSets/\(id(set))/appScreenshots?limit=50")) {
            let attributes = attributes(screenshot)
            let delivery = attributes["assetDeliveryState"] as? [String: Any]
            let errors = (delivery?["errors"] as? [[String: Any]] ?? []).compactMap { $0["description"] as? String ?? $0["code"] as? String }
            screenshots.append(Screenshot(
                id: id(screenshot),
                locale: locale,
                displayType: displayType,
                fileName: attributes["fileName"] as? String ?? "(no name)",
                state: delivery?["state"] as? String ?? "(no state)",
                errors: errors.joined(separator: "; ")
            ))
        }
    }
}

for screenshot in screenshots {
    let flag = screenshot.state == "COMPLETE" ? "  " : "!!"
    print("\(flag) \(screenshot.locale)  \(screenshot.displayType)  \(screenshot.state)  \(screenshot.fileName)  [\(screenshot.id)]\(screenshot.errors.isEmpty ? "" : "  \(screenshot.errors)")")
}

let stuck = screenshots.filter { $0.state != "COMPLETE" }
print("\n\(screenshots.count) screenshots, \(stuck.count) not complete.")
guard !stuck.isEmpty else { exit(0) }
guard shouldDelete else {
    print("Run again with --delete to remove the ones marked !!.")
    exit(0)
}

print("Delete the \(stuck.count) screenshot(s) marked !!? Type yes to confirm: ", terminator: "")
guard readLine()?.lowercased() == "yes" else {
    print("Nothing deleted.")
    exit(0)
}
for screenshot in stuck {
    await request("DELETE", "/v1/appScreenshots/\(screenshot.id)")
    print("Deleted \(screenshot.fileName) [\(screenshot.id)]")
}
print("Done. Reload the version page on App Store Connect.")
