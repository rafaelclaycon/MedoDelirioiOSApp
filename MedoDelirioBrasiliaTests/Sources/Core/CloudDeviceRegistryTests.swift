//
//  CloudDeviceRegistryTests.swift
//  MedoDelirioBrasiliaTests
//
//  Created by Rafael Schmitt on 11/10/26.
//

import Testing
import Foundation
@testable import MedoDelirio

@MainActor
struct CloudDeviceRegistryTests {

    private final class Clock {
        var now = Date(timeIntervalSince1970: 1_790_000_000)
    }

    private let clock = Clock()
    private let cloud = FakeCloudKeyValueStore()

    private func registry(
        id: String,
        name: String = "iPhone 17 Pro",
        kind: CloudDeviceRecord.Kind = .iPhone
    ) -> CloudDeviceRegistry {
        let clock = clock
        return CloudDeviceRegistry(
            cloudStore: cloud,
            deviceID: id,
            thisDevice: { (name, kind) },
            now: { clock.now }
        )
    }

    @Test
    func checkIn_shouldListThisDevice() {
        let sut = registry(id: "phone")

        sut.checkIn()

        let devices = sut.devices()
        #expect(devices.map(\.id) == ["phone"])
        #expect(devices.first?.isThisDevice == true)
        #expect(devices.first?.record.name == "iPhone 17 Pro")
        #expect(devices.first?.record.lastSeen == clock.now)
    }

    @Test
    func checkIn_withinTheRefreshInterval_shouldNotWriteAgain() {
        let sut = registry(id: "phone")
        sut.checkIn()

        clock.now = clock.now.addingTimeInterval(CloudDeviceRegistry.refreshInterval - 1)
        sut.checkIn()

        #expect(cloud.setDataCallCount == 1)
    }

    @Test
    func checkIn_afterTheRefreshInterval_shouldUpdateLastSeen() {
        let sut = registry(id: "phone")
        sut.checkIn()

        clock.now = clock.now.addingTimeInterval(CloudDeviceRegistry.refreshInterval)
        sut.checkIn()

        #expect(sut.devices().first?.record.lastSeen == clock.now)
    }

    @Test
    func checkIn_shouldKeepTheOtherDevices_withThisOneFirst() {
        registry(id: "ipad", name: "iPad Air", kind: .iPad).checkIn()
        clock.now = clock.now.addingTimeInterval(60)
        registry(id: "mac", name: "MacBook Air", kind: .mac).checkIn()
        clock.now = clock.now.addingTimeInterval(60)
        let sut = registry(id: "phone")

        sut.checkIn()

        #expect(sut.devices().map(\.id) == ["phone", "mac", "ipad"])
    }

    @Test
    func checkIn_shouldForgetDevicesNotSeenFor90Days() {
        registry(id: "old", name: "iPhone 11").checkIn()
        clock.now = clock.now.addingTimeInterval(CloudDeviceRegistry.forgetAfter)
        let sut = registry(id: "phone")

        sut.checkIn()

        #expect(sut.devices().map(\.id) == ["phone"])
    }

    @Test
    func checkIn_afterTheModelNameChanged_shouldUpdateItRightAway() {
        registry(id: "phone", name: "iPhone").checkIn()
        clock.now = clock.now.addingTimeInterval(60)
        let sut = registry(id: "phone", name: "iPhone 17 Pro")

        sut.checkIn()

        #expect(sut.devices().first?.record.name == "iPhone 17 Pro")
    }
}
