import SwiftUI

struct NotificationsSettingsView: View {

    @State private var enableNotifications = false
    @State private var episodeNotifications = false
    @State private var showSubscriptionError = false

    private var pushStatus = PushRegistrationStatus.shared

    private var enableNotificationsBinding: Binding<Bool> {
        Binding(
            get: { enableNotifications },
            set: { newValue in
                enableNotifications = newValue
                if newValue {
                    Task {
                        await NotificationAide.registerForRemoteNotifications()
                        enableNotifications = UserSettings().getUserAllowedNotifications()
                    }
                } else {
                    UserSettings().setUserAllowedNotifications(to: false)
                }
            }
        )
    }

    private var episodeNotificationsBinding: Binding<Bool> {
        Binding(
            get: { episodeNotifications },
            set: { newValue in
                episodeNotifications = newValue
                Task {
                    let result = if newValue {
                        await EpisodeNotificationSubscriber.subscribe()
                    } else {
                        await EpisodeNotificationSubscriber.unsubscribe()
                    }

                    switch result {
                    case .success:
                        break
                    case .failure:
                        episodeNotifications = !newValue
                        showSubscriptionError = true
                    }
                }
            }
        )
    }

    var body: some View {
        Form {
            Section {
                Toggle("Habilitar Notificações", isOn: enableNotificationsBinding)
            } header: {
                EmptyView()
            } footer: {
                Text("Caso a opção acima não esteja surtindo efeito, toque no botão no fim dessa tela para habilitar as notificações do app nos Ajustes do sistema.")
            }

            if FeatureFlag.isEnabled(.episodeNotifications), enableNotifications {
                Section {
                    Toggle("Avisos", isOn: .constant(true))
                        .disabled(true)

                    Toggle("Novos Episódios", isOn: episodeNotificationsBinding)
                        .disabled(pushStatus.state != .registered)

                    pushRegistrationStatusRow
                } header: {
                    Text("Escolha o que quer receber")
                } footer: {
                    Text("Receba uma notificação quando um novo episódio do podcast estiver disponível.")
                }
            }

            Section {
                Button("Mostrar permissões do app no sistema") {
                    let bundleId = Bundle.main.bundleIdentifier ?? ""
                    if let url = URL(string: "settings-navigation://com.apple.Settings.Apps/\(bundleId)") {
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
        .navigationTitle("Notificações")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "Houve um problema ao registrar este dispositivo para notificações",
            isPresented: $showSubscriptionError
        ) {
            Button("OK") {}
        } message: {
            Text("Por favor, tente novamente em alguns minutos. Você também pode desligar e religar as notificações gerais para tentar corrigir o problema.")
        }
        .onAppear {
            enableNotifications = UserSettings().getUserAllowedNotifications()
            episodeNotifications = UserSettings().getEnableEpisodeNotifications()
            pushStatus.refresh()
            if pushStatus.state == .unknown, enableNotifications {
                retryRegistration()
            }
        }
    }

    @ViewBuilder
    private var pushRegistrationStatusRow: some View {
        switch pushStatus.state {
        case .registered:
            Label("Registro push OK", systemImage: "checkmark.circle")
                .foregroundStyle(.green)
                .font(.callout)

        case .checking, .unknown:
            HStack(spacing: 12) {
                ProgressView()
                Text("Registrando dispositivo...")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }

        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .font(.callout)

                Button("Tentar Novamente") {
                    retryRegistration()
                }
                .font(.callout)
            }
        }
    }

    private func retryRegistration() {
        pushStatus.markChecking()
        UIApplication.shared.registerForRemoteNotifications()

        Task {
            try? await Task.sleep(for: .seconds(10))
            if pushStatus.state == .checking {
                pushStatus.markFailed("Tempo esgotado. Verifique sua conexão e tente novamente.")
            }
        }
    }
}

#Preview {
    NavigationStack {
        NotificationsSettingsView()
    }
}
