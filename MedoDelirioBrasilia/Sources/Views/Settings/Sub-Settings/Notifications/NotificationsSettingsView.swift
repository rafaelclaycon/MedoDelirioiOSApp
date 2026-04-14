import SwiftUI

struct NotificationsSettingsView: View {

    var showCloseButton: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var enableNotifications = false
    @State private var episodeNotifications = false
    @State private var showSubscriptionError = false
    @State private var toast: Toast?

    private var pushStatus = PushRegistrationStatus.shared

    init(showCloseButton: Bool = false) {
        self.showCloseButton = showCloseButton
    }

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
                    ChannelLogStore.shared.logEvent("Notificações desabilitadas pelo usuário", success: true)
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
                        if newValue {
                            await AnalyticsService().send(originatingScreen: "NotificationsSettings", action: "episode_notifications_resubscribed")
                        } else {
                            await AnalyticsService().send(originatingScreen: "NotificationsSettings", action: "episode_notifications_unsubscribed")
                        }
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

            if enableNotifications {
                Section {
                    Toggle("Avisos", isOn: .constant(true))
                        .disabled(true)

                    Toggle("Novos Episódios", isOn: episodeNotificationsBinding)
                } header: {
                    Text("Escolha o que quer receber")
                } footer: {
                    Text("Receba uma notificação quando um novo episódio do podcast estiver disponível.")
                }

                Section {
                    pushRegistrationStatusRow
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
        .toast($toast)
        .navigationTitle("Notificações")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showCloseButton {
                ToolbarItem(placement: .topBarLeading) {
                    CloseButton {
                        dismiss()
                    }
                }
            }
        }
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
            if enableNotifications {
                syncEpisodeSubscriptionWithServer()
            }
        }
    }

    @ViewBuilder
    private var pushRegistrationStatusRow: some View {
        switch pushStatus.state {
        case .registered:
            Label("Dispositivo registrado para push", systemImage: "checkmark.circle")
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

    private func syncEpisodeSubscriptionWithServer() {
        Task {
            guard let channels = try? await APIClient.shared.deviceChannels() else { return }
            let subscribed = channels.contains("new_episodes")
            let wasSubscribed = episodeNotifications

            episodeNotifications = subscribed
            UserSettings().setEnableEpisodeNotifications(to: subscribed)

            if wasSubscribed, !subscribed {
                toast = Toast(
                    message: "Dispositivo não registrado corretamente para notificações de Novos Episódios.",
                    type: .warning
                )
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
