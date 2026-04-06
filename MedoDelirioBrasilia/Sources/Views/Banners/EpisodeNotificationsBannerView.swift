import SwiftUI
import UserNotifications

struct EpisodeNotificationsBannerView: View {

    @Binding var isBeingShown: Bool

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.openURL) private var openURL

    @State private var showDeniedAlert = false
    @State private var toast: Toast?

    private func optIn() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()

        if settings.authorizationStatus == .denied {
            showDeniedAlert = true
            return
        }

        await NotificationAide.registerForRemoteNotifications()
        guard UserSettings().getUserAllowedNotifications() else { return }

        let result = await EpisodeNotificationSubscriber.subscribe()
        switch result {
        case .success:
            Task { await AnalyticsService().send(originatingScreen: "EpisodesBanner", action: "episode_notifications_opted_in") }
            isBeingShown = false
        case .failure:
            toast = Toast(
                message: "Não foi possível ativar as notificações de episódios. Tente novamente.",
                type: .warning
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .spacing(.medium)) {
            HStack {
                Label("Novos Episódios", systemImage: "bell.badge")
                    .foregroundStyle(
                        colorScheme == .dark ? Color.primary : Color.darkestGreen
                    )
                    .bold()

                Spacer()
                    .frame(width: 30)
            }

            Text("Receba uma notificação sempre que um novo episódio do podcast estiver disponível.")
                .foregroundStyle(
                    colorScheme == .dark ? Color.primary : Color.darkestGreen
                )
                .opacity(0.8)
                .font(.callout)

            if #available(iOS 26, *) {
                Button {
                    Task { await optIn() }
                } label: {
                    Text("Quero Receber")
                        .font(.callout)
                        .bold()
                        .foregroundStyle(
                            colorScheme == .dark ? .primary : Color.darkestGreen
                        )
                        .padding(.vertical, .spacing(.small))
                        .frame(maxWidth: .infinity)
                        .glassEffect(
                            .regular.interactive()
                        )
                }
            } else {
                Button {
                    Task { await optIn() }
                } label: {
                    Text("Quero Receber")
                        .font(.callout)
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, .spacing(.xxSmall))
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.all, 20)
        .background {
            RoundedRectangle(cornerRadius: 15)
                .foregroundColor(.green)
                .opacity(colorScheme == .dark ? 0.3 : 0.15)
        }
        .overlay(alignment: .topTrailing) {
            Button {
                Task { await AnalyticsService().send(originatingScreen: "EpisodesBanner", action: "episode_notifications_banner_dismissed") }
                AppPersistentMemory.shared.setHasDismissedEpisodeNotificationsBanner(to: true)
                isBeingShown = false
            } label: {
                Image(systemName: "xmark")
                    .foregroundColor(
                        colorScheme == .dark ? .green : Color.darkestGreen
                    )
            }
            .padding()
        }
        .alert("Notificações Desativadas", isPresented: $showDeniedAlert) {
            Button("Abrir Ajustes") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("As notificações estão desativadas para este app. Ative-as nos Ajustes do sistema para receber avisos de novos episódios.")
        }
        .topToast($toast)
    }
}

#Preview {
    EpisodeNotificationsBannerView(isBeingShown: .constant(true))
        .padding()
}
