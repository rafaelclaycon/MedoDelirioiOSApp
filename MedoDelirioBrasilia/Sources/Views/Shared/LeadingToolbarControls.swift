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

    @Environment(\.usesSidebarLayout) private var usesSidebarLayout

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if isSelecting {
                Button {
                    cancelAction()
                } label: {
                    Text("Cancelar")
                        .bold()
                }
            } else if !usesSidebarLayout {
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
