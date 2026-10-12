//
//  YouSyncCardView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 11/10/26.
//

import SwiftUI

/// Seus aparelhos: whether iCloud sync is on and how many devices take part. Leads to
/// the screen with the sync switch and the device list, which used to live in Settings.
struct YouSyncCardView: View {

    @State private var isSyncOn = UserSettings().getEnableICloudSync()
    @State private var deviceCount = 0

    private var detail: String {
        guard isSyncOn else {
            return "Sincronização com o iCloud desligada."
        }
        switch deviceCount {
        case 0, 1: return "Sincronizando pelo iCloud. Só este aparelho por enquanto."
        default: return "Sincronizando pelo iCloud entre \(deviceCount) aparelhos."
        }
    }

    var body: some View {
        NavigationLink {
            DevicesView()
        } label: {
            YouCardLabel(
                systemImage: "laptopcomputer.and.iphone",
                symbolColor: isSyncOn ? .teal : .secondary,
                title: "Seus aparelhos",
                detail: detail
            )
        }
        .buttonStyle(.plain)
        .onAppear(perform: refresh)
        .onReceive(NotificationCenter.default.publisher(for: NSUbiquitousKeyValueStore.didChangeExternallyNotification)) { _ in
            refresh()
        }
    }

    private func refresh() {
        isSyncOn = UserSettings().getEnableICloudSync()
        deviceCount = isSyncOn ? CloudDeviceRegistry().devices().count : 0
    }
}

#Preview {
    NavigationStack {
        YouSyncCardView()
            .padding()
    }
}
