import UIKit
import UserNotifications

class NotificationAide {

    static func registerForRemoteNotifications() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.sound, .alert])
            if granted {
                ChannelLogStore.shared.logEvent("Autorização push concedida", success: true)
                PushRegistrationStatus.shared.markChecking()
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                ChannelLogStore.shared.logEvent("Autorização push negada pelo usuário", success: false)
            }
            UserSettings().setUserAllowedNotifications(to: granted)
        } catch {
            ChannelLogStore.shared.logEvent("Erro ao solicitar autorização push", success: false, errorMessage: error.localizedDescription)
            UserSettings().setUserAllowedNotifications(to: false)
        }
    }
}
