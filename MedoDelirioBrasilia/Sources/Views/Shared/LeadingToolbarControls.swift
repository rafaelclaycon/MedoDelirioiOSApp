//
//  LeadingToolbarControls.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 18/04/25.
//

import SwiftUI

struct LeadingToolbarControls: ToolbarContent {

    let isSelecting: Bool
    let cancelAction: () -> Void
    let openSettingsAction: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if isSelecting {
                Button {
                    cancelAction()
                } label: {
                    Text("Cancelar")
                        .bold()
                }
            } else if UIDevice.deviceType == .iPhone {
                Button {
                    openSettingsAction()
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
    }
}

#Preview {
    VStack {
        Text("View")
    }
    .toolbar {
        LeadingToolbarControls(
            isSelecting: false,
            cancelAction: {},
            openSettingsAction: {}
        )
    }
}
