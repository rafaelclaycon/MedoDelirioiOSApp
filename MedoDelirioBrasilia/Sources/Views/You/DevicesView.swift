//
//  DevicesView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 11/10/26.
//

import SwiftUI

/// How this device works with the user's other ones: iCloud sync, and the devices taking
/// part in it.
struct DevicesView: View {

    @State private var iCloudSync: Bool = UserSettings().getEnableICloudSync()
    @State private var devices: [CloudDevice] = []

    private let registry = CloudDeviceRegistry()

    var body: some View {
        Form {
            Section {
                Toggle("Sincronizar com o iCloud", isOn: $iCloudSync)
                    .onChange(of: iCloudSync) {
                        UserSettings().setEnableICloudSync(to: iCloudSync)
                        if iCloudSync {
                            registry.checkIn()
                            loadDevices()
                        }
                    }
            } footer: {
                Text("Mantém em dia, em todos os seus aparelhos com a mesma Conta Apple, as vírgulas e músicas favoritas e, nos episódios, o ponto onde você parou, os finalizados e os favoritos.")
            }

            if iCloudSync && !devices.isEmpty {
                Section {
                    ForEach(devices) { device in
                        DeviceRow(device: device)
                    }
                } header: {
                    Text("Aparelhos sincronizados")
                } footer: {
                    Text("Aparelhos que sincronizaram nos últimos 90 dias. Eles aparecem pelo modelo, porque o app não tem acesso ao nome que você deu a cada um.")
                }
            }
        }
        .navigationTitle("Seus aparelhos")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadDevices()
            // Its only way in is the card in Você, since it left Settings.
            Task {
                await AnalyticsService().send(originatingScreen: "DevicesView", action: "didViewDevices")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSUbiquitousKeyValueStore.didChangeExternallyNotification)) { _ in
            loadDevices()
        }
    }

    private func loadDevices() {
        devices = registry.devices()
    }
}

// MARK: - Row

extension DevicesView {

    struct DeviceRow: View {

        let device: CloudDevice

        private var symbol: String {
            switch device.record.kind {
            case .iPhone: "iphone"
            case .iPad: "ipad"
            case .mac: "laptopcomputer"
            }
        }

        private var detail: String {
            if device.isThisDevice {
                return "Este aparelho"
            }
            let seen = device.record.lastSeen
            if Date.now.timeIntervalSince(seen) < 60 * 60 {
                return "Sincronizou há menos de uma hora"
            }
            return "Sincronizou \(seen.formatted(.relative(presentation: .named)))"
        }

        var body: some View {
            Label {
                VStack(alignment: .leading, spacing: .spacing(.xxxSmall)) {
                    Text(device.record.name)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: symbol)
            }
        }
    }
}

#Preview {
    NavigationStack {
        DevicesView()
    }
}
