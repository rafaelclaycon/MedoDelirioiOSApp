//
//  MedoDelirioBrasiliaApp.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 05/05/22.
//

import SwiftUI

let baseURL: String = CommandLine.arguments.contains("-UNDER_DEVELOPMENT") ? "http://127.0.0.1:8080/" : "https://api.medodelirioios.com/"

var moveDatabaseIssue: String = .empty

@main
struct MedoDelirioBrasiliaApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            MainView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    
    @AppStorage("hasMigratedSoundsAuthors") private var hasMigratedSoundsAuthors = false
    @AppStorage("hasMigratedSongsMusicGenres") private var hasMigratedSongsMusicGenres = false
    
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
        guard AppPersistentMemory.getHasSentDeviceModelToServer() == false else {
            return
        }
        
        let info = ClientDeviceInfo(installId: UIDevice.customInstallId, modelName: UIDevice.modelName)
        NetworkRabbit.shared.post(clientDeviceInfo: info) { success, error in
            if let success = success, success {
                AppPersistentMemory.setHasSentDeviceModelToServer(to: true)
            }
        }
    }
    
    private func sendStillAliveSignalToServer() {
        let lastDate = UserSettings.getLastSendDateOfStillAliveSignalToServer()
        
        // Should only send 1 still alive signal per day
        guard lastDate == nil || lastDate!.onlyDate! < Date.now.onlyDate! else {
            return
        }
        
        let signal = StillAliveSignal(installId: UIDevice.customInstallId,
                                      modelName: UIDevice.modelName,
                                      systemName: UIDevice.current.systemName,
                                      systemVersion: UIDevice.current.systemVersion,
                                      isiOSAppOnMac: ProcessInfo.processInfo.isiOSAppOnMac,
                                      appVersion: Versioneer.appVersion,
                                      currentTimeZone: TimeZone.current.abbreviation() ?? .empty,
                                      dateTime: Date.now.iso8601withFractionalSeconds)
        NetworkRabbit.shared.post(signal: signal) { success, error in
            if success != nil, success == true {
                UserSettings.setLastSendDateOfStillAliveSignalToServer(to: Date.now)
            }
        }
    }
    
    // MARK: - Push notifications
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        if AppPersistentMemory.getShouldRetrySendingDevicePushToken() {
            let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
            let token = tokenParts.joined()
            //print("Device Token: \(token)")

            let device = PushDevice(installId: UIDevice.customInstallId, pushToken: token)
            NetworkRabbit.shared.post(pushDevice: device) { success, error in
                guard let success = success, success else {
                    AppPersistentMemory.setShouldRetrySendingDevicePushToken(to: true)
                    return
                }
                AppPersistentMemory.setShouldRetrySendingDevicePushToken(to: false)
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
    
    private func replaceUserSettingFlag() {
        if hasSkipGetLinkInstructionsSet() {
            UserSettings.setShowExplicitContent(to: true)
            UserDefaults.standard.removeObject(forKey: "skipGetLinkInstructions")
        }
    }
}

extension AppDelegate {
    
    func createFoldersForDownloadedContent() {
        createFolder(named: InternalFolderNames.downloadedSounds)
        createFolder(named: InternalFolderNames.downloadedSongs)
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
            Logger.shared.logSyncError(description: "Erro ao tentar criar a pasta \(folderName): \(error.localizedDescription)", updateEventId: "")
        }
    }
}
