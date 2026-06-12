//
//  PushAction.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 20/07/24.
//

import SwiftUI

typealias PushAction = Action<any Hashable, Void>

extension EnvironmentValues {

    private enum PushActionKey: EnvironmentKey {
        static let defaultValue = PushAction { _ in
            print("Push action invoked, but it has not been set up in this environment yet.")
        }
    }

    var push: PushAction {
        get { self[PushActionKey.self] }
        set { self[PushActionKey.self] = newValue }
    }
}
