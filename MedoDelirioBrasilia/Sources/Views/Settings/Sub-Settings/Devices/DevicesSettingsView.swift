//
//  DevicesSettingsView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 11/10/26.
//

import SwiftUI

/// How this device works with the user's other ones. Only iCloud sync for now.
struct DevicesSettingsView: View {

    @State private var iCloudSync: Bool = UserSettings().getEnableICloudSync()

    var body: some View {
        Form {
            Section {
                Toggle("Sincronizar com o iCloud", isOn: $iCloudSync)
                    .onChange(of: iCloudSync) {
                        UserSettings().setEnableICloudSync(to: iCloudSync)
                    }
            } footer: {
                Text("Mantém em dia, em todos os seus aparelhos com a mesma Conta Apple, as vírgulas e músicas favoritas e, nos episódios, o ponto onde você parou, os finalizados e os favoritos.")
            }
        }
        .navigationTitle("Seus aparelhos")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        DevicesSettingsView()
    }
}
