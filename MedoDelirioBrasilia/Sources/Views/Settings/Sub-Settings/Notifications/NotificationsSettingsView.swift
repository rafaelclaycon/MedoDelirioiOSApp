import SwiftUI

struct NotificationsSettingsView: View {

    @State private var enableNotifications = false
    @State private var episodeNotifications = false
    @State private var showSubscriptionError = false
    @State private var toast: Toast?

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

            if FeatureFlag.isEnabled(.episodeNotifications), enableNotifications {
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

            if FeatureFlag.isEnabled(.episodeNotifications) {
                ChannelLogsView()
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
            if FeatureFlag.isEnabled(.episodeNotifications), enableNotifications {
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

// MARK: - Channel Logs

private struct ChannelLogsView: View {

    private var store = ChannelLogStore.shared

    private static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd/MM HH:mm:ss.SSS"
        return f
    }()

    var body: some View {
        Section("Logs de push") {
            if store.entries.isEmpty {
                Text("Sem registros nesta sessão")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.entries) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: entry.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(entry.success ? .green : .red)

                            Text("\(entry.method) — \(Self.timestampFormatter.string(from: entry.timestamp))")
                                .font(.footnote.bold())

                            if let code = entry.statusCode {
                                Text("\(code)")
                                    .font(.footnote.bold().monospaced())
                                    .foregroundStyle(code == 200 ? .green : .red)
                            }
                        }

                        if !entry.url.isEmpty {
                            Text(entry.url)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        if let body = entry.requestBody {
                            Text("REQ: \(body)")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }

                        if let responseBody = entry.responseBody, !responseBody.isEmpty {
                            Text("RES: \(responseBody)")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }

                        if let error = entry.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        NotificationsSettingsView()
    }
}
