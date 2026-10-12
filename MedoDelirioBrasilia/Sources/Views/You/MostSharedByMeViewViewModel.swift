//
//  MostSharedByMeViewViewModel.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 11/10/22.
//

import Foundation
import Combine

@Observable @MainActor
final class MostSharedByMeViewViewModel {

    var viewState: LoadingState<[TopChartItem]> = .loading

    func onViewAppeared() async {
        guard let ranking = Podium.shared.top10SoundsSharedByTheUser() else { return }
        viewState = .loaded(ranking)
    }
}
