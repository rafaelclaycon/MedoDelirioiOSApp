//
//  MedoDelirioBrasiliaApp.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 05/05/22.
//

import SwiftUI

var moveDatabaseIssue: String = .empty

@main
struct MedoDelirioBrasiliaApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var tabSelection: PhoneTab = .sounds
    @State private var state: PadScreen? = PadScreen.allSounds

    @StateObject private var helper = PlayRandomSoundHelper()

    var body: some Scene {
        WindowGroup {
            MainView(tabSelection: $tabSelection, padSelection: $state)
                .onOpenURL(perform: handleURL)
                .environmentObject(helper)
        }
    }

    private func handleURL(_ url: URL) {
        guard url.scheme == "medodelirio" else { return }
        if url.host == "playrandomsound" {
            tabSelection = .sounds
            state = .allSounds

            let includeOffensive = UserSettings().getShowExplicitContent()

            do {
                guard
                    let randomSound = try LocalDatabase.shared.randomSound(includeOffensive: includeOffensive)
                else { return }
                helper.soundIdToPlay = randomSound.id
                Analytics().send(action: "didPlayRandomSound(\(randomSound.title))")
            } catch {
                print("Erro obtendo som aleatório: \(error.localizedDescription)")
                Analytics().send(action: "hadErrorPlayingRandomSound(\(error.localizedDescription))")
            }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    
    @AppStorage("hasMigratedSoundsAuthors") private var hasMigratedSoundsAuthors = false
    @AppStorage("hasMigratedSongsMusicGenres") private var hasMigratedSongsMusicGenres = false
    @AppStorage("hasUpdatedExternalLinksOnFirstRun") private var hasUpdatedExternalLinksOnFirstRun = false
    @AppStorage("hasUpdatedFolderHashesOnFirstRun") private var hasUpdatedFolderHashesOnFirstRun = false

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        print("APP - APP DELEGATE")
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
        collectTelemetry()
        createFoldersForDownloadedContent()
        updateExternalLinks()
        updateFolderChangeHashes()

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
    
    // MARK: - Telemetry
    
    private func collectTelemetry() {
        sendDeviceModelNameToServer()
        sendStillAliveSignalToServer()
    }
    
    private func sendDeviceModelNameToServer() {
        guard AppPersistentMemory().getHasSentDeviceModelToServer() == false else {
            return
        }
        
        let info = ClientDeviceInfo(installId: AppPersistentMemory().customInstallId, modelName: UIDevice.modelName)
        NetworkRabbit.shared.post(clientDeviceInfo: info) { success, error in
            if let success = success, success {
                AppPersistentMemory().setHasSentDeviceModelToServer(to: true)
            }
        }
    }
    
    private func sendStillAliveSignalToServer() {
        let lastDate = UserSettings().getLastSendDateOfStillAliveSignalToServer()
        
        // Should only send 1 still alive signal per day
        guard lastDate == nil || lastDate!.onlyDate! < Date.now.onlyDate! else {
            return
        }
        
        let signal = StillAliveSignal(installId: AppPersistentMemory().customInstallId,
                                      modelName: UIDevice.modelName,
                                      systemName: UIDevice.current.systemName,
                                      systemVersion: UIDevice.current.systemVersion,
                                      isiOSAppOnMac: ProcessInfo.processInfo.isiOSAppOnMac,
                                      appVersion: Versioneer.appVersion,
                                      currentTimeZone: TimeZone.current.abbreviation() ?? .empty,
                                      dateTime: Date.now.iso8601withFractionalSeconds)
        NetworkRabbit.shared.post(signal: signal) { success, error in
            if success != nil, success == true {
                UserSettings().setLastSendDateOfStillAliveSignalToServer(to: Date.now)
            }
        }
    }
    
    // MARK: - Push notifications
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        if AppPersistentMemory().getShouldRetrySendingDevicePushToken() {
            let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
            let token = tokenParts.joined()
            //print("Device Token: \(token)")

            let device = PushDevice(installId: AppPersistentMemory().customInstallId, pushToken: token)
            NetworkRabbit.shared.post(pushDevice: device) { success, error in
                guard let success = success, success else {
                    AppPersistentMemory().setShouldRetrySendingDevicePushToken(to: true)
                    return
                }
                AppPersistentMemory().setShouldRetrySendingDevicePushToken(to: false)
            }
        }
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Failed to register: \(error.localizedDescription)")
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
        let folderUrl = documentsURL.appendingPathComponent(folderName)
        
        do {
            var isDirectory: ObjCBool = false
            if !fileManager.fileExists(atPath: folderUrl.path, isDirectory: &isDirectory) {
                try fileManager.createDirectory(at: folderUrl, withIntermediateDirectories: true, attributes: nil)
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
            Logger.shared.logSyncError(description: "Erro ao tentar criar a pasta \(folderName): \(error.localizedDescription)")
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
                let url = URL(string: NetworkRabbit.shared.serverPath + "v4/author-links-first-open")!
                do {
                    let authorsWithLinks: [Author] = try await NetworkRabbit.shared.get(from: url)
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
                try UserFolderRepository().addHashToExistingFolders()
                hasUpdatedFolderHashesOnFirstRun = true
            } catch {
                print(error)
            }
        }
    }
}
