//
//  ChangeAppIconView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 24/08/22.
//

import SwiftUI

struct ChangeAppIconView: View {

    private var model = AppIcon()

    @State private var selectedIcon: String = ""

    var body: some View {
        VStack {
            List(Icon.allCases.filter { $0 != .birthday }) { icon in
                Button {
                    model.setAlternateAppIcon(icon: icon)
                    selectedIcon = icon.id
                } label: {
                    AppIconView(icon: icon, selectedItem: $selectedIcon)
                }
                .foregroundColor(.primary)
            }
        }
        .navigationTitle("Ícone do app")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selectedIcon = UIApplication.shared.alternateIconName ?? Icon.primary.id
            Task {
                await AnalyticsService().send(
                    originatingScreen: "ChangeAppIconView",
                    action: "didViewAlternateIconsView"
                )
            }
        }
    }
}

#Preview {
    ChangeAppIconView()
}
