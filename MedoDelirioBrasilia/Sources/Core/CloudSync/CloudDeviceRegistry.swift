//
//  CloudDeviceRegistry.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 11/10/26.
//

import UIKit
import os

private let logger = os.Logger(subsystem: "com.rafaelschmitt.MedoDelirioBrasilia", category: "CloudDeviceRegistry")

/// One of the user's devices, as it last described itself.
struct CloudDeviceRecord: Codable, Equatable {

    enum Kind: String, Codable {
        case iPhone, iPad, mac
    }

    var name: String
    var kind: Kind
    var lastSeen: Date

    enum CodingKeys: String, CodingKey {
        case name = "n"
        case kind = "k"
        case lastSeen = "s"
    }
}

/// A device for the list in Seus aparelhos.
struct CloudDevice: Identifiable, Equatable {

    let id: String
    let record: CloudDeviceRecord
    let isThisDevice: Bool
}

/// Lets each device that syncs list itself in iCloud, so Seus aparelhos can show which
/// devices are taking part and when each last showed up.
///
/// Apple doesn't tell an app which devices share an Apple Account, so every device keeps
/// its own entry under one key. Names come from the model ("iPhone 17 Pro"): the name the
/// user gave the device takes an entitlement Apple grants case by case.
@MainActor
final class CloudDeviceRegistry {

    nonisolated static let key = "devices.v1"

    /// How stale this device's entry may get before a sync refreshes it. Keeps writes to a
    /// few a day while "há X" stays close enough.
    nonisolated static let refreshInterval: TimeInterval = 15 * 60

    /// A device not seen for this long drops off the list, and out of the cloud.
    nonisolated static let forgetAfter: TimeInterval = 90 * 24 * 60 * 60

    private let cloudStore: CloudKeyValueStore
    private let deviceID: String
    private let thisDevice: @MainActor () -> (name: String, kind: CloudDeviceRecord.Kind)
    private let now: () -> Date

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }()

    /// - Parameter deviceID: per device rather than per install. `identifierForVendor`
    ///   isn't carried over when a backup is restored onto a new iPhone, so the new one
    ///   doesn't take over the old one's entry.
    init(
        cloudStore: CloudKeyValueStore = NSUbiquitousKeyValueStore.default,
        deviceID: String = UIDevice.current.identifierForVendor?.uuidString ?? CloudDeviceRegistry.fallbackDeviceID,
        thisDevice: @escaping @MainActor () -> (name: String, kind: CloudDeviceRecord.Kind) = { CloudDeviceRegistry.currentDevice() },
        now: @escaping () -> Date = Date.init
    ) {
        self.cloudStore = cloudStore
        self.deviceID = deviceID
        self.thisDevice = thisDevice
        self.now = now
    }

    // MARK: - Check In

    /// Refreshes this device's entry when it's missing, stale or describes the device
    /// differently, and drops devices past `forgetAfter`. Writes only when something
    /// changed. Called by `CloudStateSync` on every sync, so only while sync is on.
    func checkIn() {
        let date = now()
        let remote = read()
        let device = thisDevice()

        var records = remote.filter { date.timeIntervalSince($0.value.lastSeen) < Self.forgetAfter }
        let current = records[deviceID]
        let isStale = current.map { date.timeIntervalSince($0.lastSeen) >= Self.refreshInterval } ?? true
        if isStale || current?.name != device.name || current?.kind != device.kind {
            records[deviceID] = CloudDeviceRecord(name: device.name, kind: device.kind, lastSeen: date)
        }

        if records != remote {
            write(records)
        }
    }

    // MARK: - Listing

    /// This device first, then the rest by when they were last seen.
    func devices() -> [CloudDevice] {
        let date = now()
        return read()
            .filter { date.timeIntervalSince($0.value.lastSeen) < Self.forgetAfter }
            .map { CloudDevice(id: $0.key, record: $0.value, isThisDevice: $0.key == deviceID) }
            .sorted { lhs, rhs in
                if lhs.isThisDevice != rhs.isThisDevice { return lhs.isThisDevice }
                if lhs.record.lastSeen != rhs.record.lastSeen { return lhs.record.lastSeen > rhs.record.lastSeen }
                return lhs.id < rhs.id
            }
    }

    // MARK: - This Device

    /// The model name, or "iPhone", "iPad" or "Mac" for a model newer than the app's
    /// list, which would otherwise show as a raw identifier like "iPhone19,1".
    static func currentDevice() -> (name: String, kind: CloudDeviceRecord.Kind) {
        let kind: CloudDeviceRecord.Kind = switch UIDevice.deviceType {
        case .iPhone: .iPhone
        case .iPad: .iPad
        case .mac: .mac
        }
        let model = UIDevice.modelName
        let isRawIdentifier = model.contains(",") && model.contains(where: \.isNumber) && !model.contains(" ")
        return (isRawIdentifier ? UIDevice.deviceGenericName : model, kind)
    }

    /// Only when `identifierForVendor` is unavailable, which Apple says can happen right
    /// after a restart before the device is unlocked.
    nonisolated static var fallbackDeviceID: String {
        let key = "cloudDeviceRegistryFallbackID"
        if let id = UserDefaults.standard.string(forKey: key) { return id }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: key)
        return id
    }

    // MARK: - Encoding

    private func read() -> [String: CloudDeviceRecord] {
        guard let data = cloudStore.data(forKey: Self.key) else { return [:] }
        do {
            return try Self.decoder.decode([String: CloudDeviceRecord].self, from: data)
        } catch {
            logger.error("Couldn't decode the device list: \(error.localizedDescription, privacy: .public)")
            return [:]
        }
    }

    private func write(_ records: [String: CloudDeviceRecord]) {
        do {
            cloudStore.setData(try Self.encoder.encode(records), forKey: Self.key)
        } catch {
            logger.error("Couldn't encode the device list: \(error.localizedDescription, privacy: .public)")
        }
    }
}
