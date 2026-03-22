//
//  MedoDelirioBrasiliaApp.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 05/05/22.
//

import FirebaseCore
import SwiftUI
import UserNotifications

var moveDatabaseIssue: String = ""

@main
struct MedoDelirioBrasiliaApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var tabSelection: PhoneTab = .sounds
    @State private var state: PadScreen? = PadScreen.allSounds

    @State private var helper = PlayRandomSoundHelper()

    private let contentRepository = ContentRepository(database: LocalDatabase.shared)

    /// Shared instance used across the app to ensure cache consistency
    private let userFolderRepository = UserFolderRepository(database: LocalDatabase.shared)

    var body: some Scene {
        WindowGroup {
            MainView(
                tabSelection: $tabSelection,
                padSelection: $state,
                contentRepository: contentRepository,
                userFolderRepository: userFolderRepository
            )
            .onOpenURL(perform: handleURL)
            .onReceive(NotificationCenter.default.publisher(for: .navigateToTab)) { notification in
                if let tab = notification.userInfo?[NavigateToTabKey.phoneTab] as? PhoneTab {
                    tabSelection = tab
                }
            }
            .environment(helper)
        }
    }

    private func handleURL(_ url: URL) {
        guard url.scheme == "medodelirio" else { return }
        if url.host == "playrandomsound" {
            tabSelection = .sounds

            let includeOffensive = UserSettings().getShowExplicitContent()

            do {
                guard
                    let randomSound = try LocalDatabase.shared.randomSound(includeOffensive: includeOffensive)
                else { return }
                helper.soundIdToPlay = randomSound.id
                Task {
                    await AnalyticsService().send(action: "didPlayRandomSound(\(randomSound.title))")
                }
            } catch {
                print("Erro obtendo som aleatório: \(error.localizedDescription)")
                Task {
                    await AnalyticsService().send(action: "hadErrorPlayingRandomSound(\(error.localizedDescription))")
                }
            }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    @AppStorage("hasMigratedSoundsAuthors") private var hasMigratedSoundsAuthors = false
    @AppStorage("hasMigratedSongsMusicGenres") private var hasMigratedSongsMusicGenres = false
    @AppStorage("hasUpdatedExternalLinksOnFirstRun") private var hasUpdatedExternalLinksOnFirstRun = false
    @AppStorage("hasUpdatedFolderHashesOnFirstRun") private var hasUpdatedFolderHashesOnFirstRun = false

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        configureFirebase()

        print("APP - APP DELEGATE")
        UNUserNotificationCenter.current().delegate = self

        // Fixes
        moveDatabaseFileIfNeeded()
        replaceUserSettingFlag()
        
        do {
            try LocalDatabase.shared.migrateIfNeeded()
        } catch {
            fatalError("Failed to migrate database: \(error)")
        }
        
        //print(database)
        
        if !hasMigratedSoundsAuthors {
            moveSoundsAndAuthorsToDatabase()
            hasMigratedSoundsAuthors = true
        }

        if !hasMigratedSongsMusicGenres {
            moveSongsAndMusicGenresToDatabase()
            hasMigratedSongsMusicGenres = true
        }
        
        prepareAudioPlayerOnMac()
        Task {
            await collectTelemetry()
        }
        createFoldersForDownloadedContent()
        updateExternalLinks()
        updateFolderChangeHashes()
        registerForPushNotificationsIfAuthorized()

        return true
    }

    // This fixes the issue in which a sound would take 10 seconds to play on the Mac
    private func prepareAudioPlayerOnMac() {
        guard ProcessInfo.processInfo.isiOSAppOnMac else { return }
        guard let path = Bundle.main.path(forResource: "Lula - Eu posso tomar cafe.mp3", ofType: nil) else { return }
        let url = URL(fileURLWithPath: path)
        AudioPlayer.shared = AudioPlayer(url: url, update: { _ in })
        AudioPlayer.shared?.prepareToPlay()
    }
    
    // MARK: - Firebase

    private func configureFirebase() {
        let plistName: String
        if Bundle.main.bundleIdentifier == "com.rafaelschmitt.MedoDelirioBrasilia.beta" {
            plistName = "GoogleService-Info-Beta"
        } else {
            plistName = "GoogleService-Info-Prod"
        }

        guard let filePath = Bundle.main.path(forResource: plistName, ofType: "plist"),
              let options = FirebaseOptions(contentsOfFile: filePath)
        else {
            fatalError("Missing Firebase configuration file: \(plistName).plist")
        }
        FirebaseApp.configure(options: options)
    }

    // MARK: - Telemetry

    private func collectTelemetry() async {
        await sendDeviceModelNameToServer()
        await sendStillAliveSignalToServer()
    }

    private func sendDeviceModelNameToServer() async {
        guard AppPersistentMemory.shared.getHasSentDeviceModelToServer() == false else {
            return
        }
        let info = ClientDeviceInfo(installId: AppPersistentMemory.shared.customInstallId, modelName: UIDevice.modelName)
        do {
            try await APIClient.shared.post(clientDeviceInfo: info)
            AppPersistentMemory.shared.setHasSentDeviceModelToServer(to: true)
        } catch {
            print("Erro enviando device model para o servidor:")
            debugPrint(error)
        }
    }

    private func sendStillAliveSignalToServer() async {
        let lastDate = UserSettings().getLastSendDateOfStillAliveSignalToServer()

        // Should only send 1 still alive signal per day
        guard lastDate == nil || lastDate!.onlyDate! < Date.now.onlyDate! else {
            return
        }

        let signal = StillAliveSignal(
            installId: AppPersistentMemory.shared.customInstallId,
            modelName: UIDevice.modelName,
            systemName: UIDevice.current.systemName,
            systemVersion: UIDevice.current.systemVersion,
            isiOSAppOnMac: ProcessInfo.processInfo.isiOSAppOnMac,
            appVersion: Versioneer.appVersion,
            currentTimeZone: TimeZone.current.abbreviation() ?? "",
            dateTime: Date.now.iso8601withFractionalSeconds
        )

        do {
            let url = URL(string: APIClient.shared.serverPath + "v1/still-alive-signal")!
            try await APIClient.shared.post(to: url, body: signal)
            UserSettings().setLastSendDateOfStillAliveSignalToServer(to: Date.now)
        } catch {
            debugPrint(error)
        }
    }

    // MARK: - Push notifications
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task {
            let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
            let token = tokenParts.joined()

            let storedToken = AppPersistentMemory().getLastSentPushToken()

            guard token != storedToken else {
                PushRegistrationStatus.shared.markRegistered()
                return
            }

            let device = PushDevice(installId: AppPersistentMemory().customInstallId, pushToken: token)

            do {
                let success = try await APIClient.shared.register(pushDevice: device)
                if success {
                    AppPersistentMemory().setLastSentPushToken(to: token)
                    PushRegistrationStatus.shared.markRegistered()
                }
            } catch {
                print("Failed to register push token: \(error.localizedDescription)")
                PushRegistrationStatus.shared.markFailed("Falha ao registrar o dispositivo no servidor.")
            }
        }
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Failed to register: \(error.localizedDescription)")
        PushRegistrationStatus.shared.markFailed("Falha ao registrar para notificações remotas.")
    }

    private func registerForPushNotificationsIfAuthorized() {
        Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()

            if settings.authorizationStatus == .authorized {
                PushRegistrationStatus.shared.markChecking()
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        if let typeString = userInfo["type"] as? String,
           let type = PushNotificationType(rawValue: typeString) {
            switch type {
            case .newEpisode:
                NotificationCenter.default.post(
                    name: .navigateToTab,
                    object: nil,
                    userInfo: [NavigateToTabKey.phoneTab: PhoneTab.trends]
                )
            }
        }

        completionHandler()
    }

    // MARK: - Missing Favorites bugfix
    
    private func moveDatabaseFileIfNeeded() {
        guard databaseFileExistsInCachesDirectory() else {
            return
        }
        
        let documentsDirPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as String
        let cachesDirPath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0] as String
        let fromPath = cachesDirPath.appending("/medo_db.sqlite3")
        let toPath = documentsDirPath.appending("/medo_db.sqlite3")
        
        do {
            try FileManager.default.moveItem(atPath: fromPath, toPath: toPath)
        } catch {
            moveDatabaseIssue = error.localizedDescription
        }
    }
    
    private func databaseFileExistsInCachesDirectory() -> Bool {
        let path = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0] as String
        let url = NSURL(fileURLWithPath: path)
        if let pathComponent = url.appendingPathComponent("medo_db.sqlite3") {
            let filePath = pathComponent.path
            let fileManager = FileManager.default
            return fileManager.fileExists(atPath: filePath)
        } else {
            return false
        }
    }
    
    // MARK: - Fix UserSetting flag name
    
    private func hasSkipGetLinkInstructionsSet() -> Bool {
        let userDefaults = UserDefaults.standard
        guard let value = userDefaults.object(forKey: "skipGetLinkInstructions") else {
            return false
        }
        return Bool(value as! Bool)
    }

    /// `skipGetLinkInstructions` is a remnant of when the app started and I copied a bunch of code from my other app, The Library Is Open.
    private func replaceUserSettingFlag() {
        if hasSkipGetLinkInstructionsSet() {
            UserSettings().setShowExplicitContent(to: true)
            UserDefaults.standard.removeObject(forKey: "skipGetLinkInstructions")
        }
    }

//    Feature put on hold on Jan 3, 2026.
//    /// For anyone that already had the app before the Ask For Content Update changes (PR #251),
//    /// we need to skip asking them since asking should only happen before the 1st ever content update.
//    private func updateHasAllowedContentUpdateIfNeeded() {
//        if AppPersistentMemory.shared.getLastUpdateAttempt() != "" {
//            AppPersistentMemory.shared.hasAllowedContentUpdate(true)
//        }
//    }
}

extension AppDelegate {
    
    func createFoldersForDownloadedContent() {
        createFolder(named: InternalFolderNames.downloadedSounds)
        createFolder(named: InternalFolderNames.downloadedSongs)
        createFolder(named: InternalFolderNames.downloadedEpisodes)
    }
    
    func createFolder(named folderName: String) {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let downloadedSoundsURL = documentsURL.appendingPathComponent(folderName)
        
        do {
            var isDirectory: ObjCBool = false
            if !fileManager.fileExists(atPath: downloadedSoundsURL.path, isDirectory: &isDirectory) {
                try fileManager.createDirectory(at: downloadedSoundsURL, withIntermediateDirectories: true, attributes: nil)
                print(folderName + " folder created.")
            } else {
                if isDirectory.boolValue {
                    print(folderName + " folder already exists.")
                } else {
                    print("A file with the name \(folderName) already exists.")
                }
            }
        } catch {
            print("Error creating \(folderName) folder: \(error)")
            Logger.shared.updateError("Erro ao tentar criar a pasta \(folderName): \(error.localizedDescription)")
        }
    }
}

extension AppDelegate {

    /// External Links were added on version 7.10. Because of the server architecture, EL author updates will arrive to older versions
    /// that know nothing about ELs. This func makes sure 7.10 onwards starts with the ELs in place that were ignored before.
    /// This should run only once.
    func updateExternalLinks() {
        if !hasUpdatedExternalLinksOnFirstRun {
            Task {
                let url = URL(string: APIClient.shared.serverPath + "v4/author-links-first-open")!
                do {
                    let authorsWithLinks: [Author] = try await APIClient.shared.get(from: url)
                    try authorsWithLinks.forEach { author in
                        try LocalDatabase.shared.update(author: author)
                    }
                    print("UPDATED \(authorsWithLinks.count) AUTHORS WITH LINKS")
                    hasUpdatedExternalLinksOnFirstRun = true
                } catch {
                    print(error)
                }
            }
        }
    }

    /// UserFolder change hashes were added on version 7.14.
    /// This sets initial hashes for all existing folders so the app can keep track of future changes done to them.
    /// This should run only once.
    func updateFolderChangeHashes() {
        if !hasUpdatedFolderHashesOnFirstRun {
            do {
                try UserFolderRepository(database: LocalDatabase.shared).addHashToExistingFolders()
                hasUpdatedFolderHashesOnFirstRun = true
            } catch {
                print(error)
            }
        }
    }
}
