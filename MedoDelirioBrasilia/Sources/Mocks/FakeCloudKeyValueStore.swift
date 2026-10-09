//
//  FakeCloudKeyValueStore.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 09/10/26.
//

import Foundation

final class FakeCloudKeyValueStore: CloudKeyValueStore {

    var values: [String: Data] = [:]
    var setDataCallCount = 0
    var didCallSynchronize = false

    func data(forKey key: String) -> Data? {
        values[key]
    }

    func setData(_ data: Data, forKey key: String) {
        values[key] = data
        setDataCallCount += 1
    }

    func synchronize() -> Bool {
        didCallSynchronize = true
        return true
    }
}
