//
//  ContentUpdateStatusSymbol.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 16/08/23.
//

import SwiftUI

struct ContentUpdateStatusSymbol: View {

    @Environment(SyncValues.self) private var syncValues

    var body: some View {
        switch syncValues.syncStatus {
        case .updating:
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())

        case .done:
            Image(systemName: "info")

        case .updateError:
            Image(systemName: "exclamationmark.triangle.fill") // "xmark.octagon"
                .foregroundColor(.orange)

//        case .pendingFirstUpdate:
//            Image(systemName: "clock")
//                .foregroundColor(.gray)
        }
    }
}

//struct ContentUpdateStatusSymbol_Previews: PreviewProvider {
//
//    static let syncValuesUpdating: SyncValues = SyncValues()
//    static let syncValuesDone: SyncValues = SyncValues(syncStatus: .done)
//    static let syncValuesUpdateError: SyncValues = SyncValues(syncStatus: .updateError)
//
//    static var previews: some View {
//        Group {
//            ContentUpdateStatusSymbol()
//                .environment(syncValuesUpdating)
//
//            ContentUpdateStatusSymbol()
//                .environment(syncValuesDone)
//
//            ContentUpdateStatusSymbol()
//                .environment(syncValuesUpdateError)
//        }
//    }
//}
