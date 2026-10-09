//
//  CloudKeyValueStore.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 09/10/26.
//

import Foundation

/// The slice of `NSUbiquitousKeyValueStore` the episode sync uses, so tests can swap
/// in a fake instead of touching the user's iCloud.
protocol CloudKeyValueStore: AnyObject {

    func data(forKey key: String) -> Data?
    func setData(_ data: Data, forKey key: String)
    @discardableResult func synchronize() -> Bool
}

extension NSUbiquitousKeyValueStore: CloudKeyValueStore {

    func setData(_ data: Data, forKey key: String) {
        set(data, forKey: key)
    }
}
