//
//  DonationGate.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 12/10/26.
//

import Foundation

/// Whether the app may ask for donations right now. Every ask goes through here: the
/// Settings section, the support sheets after an episode, a clip or the election
/// results, the chapters button and the games card.
///
/// App Review frowns on donations in an app with digital content, so asks stay hidden
/// unless the server says this isn't the version being reviewed (it answers with the
/// version under review, see `displayAskForMoneyView`). Hidden by default and whenever
/// the check fails, so a reviewer never sees one, even offline.
@Observable
final class DonationGate {

    static let shared = DonationGate()

    /// Shows the asks regardless, for screenshots and testing, same as in Settings.
    private static let isForced = CommandLine.arguments.contains("-FORCE_SHOW_HELP_THE_APP")

    private(set) var isAllowed: Bool = DonationGate.isForced

    @ObservationIgnored private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol = APIClient.shared) {
        self.apiClient = apiClient
    }

    /// Asks the server again. Called at launch and when coming back to the app; a
    /// failed check closes the gate.
    func refresh() async {
        guard !Self.isForced else { return }
        let allowed = await apiClient.displayAskForMoneyView(appVersion: Versioneer.appVersion)
        await MainActor.run {
            isAllowed = allowed
        }
    }
}
