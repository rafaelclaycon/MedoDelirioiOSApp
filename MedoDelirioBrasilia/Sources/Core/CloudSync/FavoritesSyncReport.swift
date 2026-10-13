//
//  FavoritesSyncReport.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 13/10/26.
//

import Foundation

/// How this device's sound and song favorites compare with the copy in iCloud, for
/// Diagnostics. Two devices that disagree show it here: a favorite only on this device
/// hasn't reached the cloud (or was overwritten there), one only in the cloud hasn't
/// been taken in here yet.
struct FavoritesSyncReport: Equatable {

    /// Every favorite stored on this device, shown or not.
    let localFavorites: Set<String>
    /// Removals this device still remembers, to pass on to the others.
    let localRemovals: Int
    /// The local favorites the Favorites list can't show: their sound or song isn't in
    /// this device's catalog.
    let notInCatalog: Set<String>
    /// Nil when iCloud has nothing for favorites yet, or this device hasn't received it.
    let cloudFavorites: Set<String>?
    let cloudRemovals: Int

    init(
        localDates: [String: Date],
        localTombstones: [String: Date],
        cloudRecords: [String: ContentFavoriteRecord]?,
        catalogIDs: Set<String>
    ) {
        localFavorites = Set(localDates.keys)
        localRemovals = localTombstones.count
        notInCatalog = localFavorites.subtracting(catalogIDs)
        cloudFavorites = cloudRecords.map { Set($0.filter { $0.value.isFavorite }.keys) }
        cloudRemovals = cloudRecords?.values.filter { !$0.isFavorite }.count ?? 0
    }

    /// What the Favorites list shows.
    var shownCount: Int {
        localFavorites.count - notInCatalog.count
    }

    var onlyHere: Set<String> {
        localFavorites.subtracting(cloudFavorites ?? [])
    }

    var onlyInCloud: Set<String> {
        (cloudFavorites ?? []).subtracting(localFavorites)
    }

    var isInStep: Bool {
        cloudFavorites != nil && onlyHere.isEmpty && onlyInCloud.isEmpty
    }
}
