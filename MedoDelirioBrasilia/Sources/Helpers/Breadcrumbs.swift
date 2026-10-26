//
//  Breadcrumbs.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 26/10/26.
//

import FirebaseCore
import FirebaseCrashlytics

/// Short notes on where someone is in the app, kept by Crashlytics on the device. They only
/// leave the phone attached to a crash report, where the last ones say which screen was
/// showing. Crashes inside the system's own drawing, like Liquid Glass's, have no app code
/// in their stack trace to tell.
enum Breadcrumbs {

    static func leave(_ message: String) {
        // Firebase is set up at launch; a note should never be what brings the app down.
        guard FirebaseApp.app() != nil else { return }
        Crashlytics.crashlytics().log(message)
    }
}
