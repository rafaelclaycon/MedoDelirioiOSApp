//
//  MedoDelirioWidgetBundle.swift
//  MedoDelirioWidget
//
//  Created by Rafael Schmitt on 22/09/24.
//

import WidgetKit
import SwiftUI

@main
struct MedoDelirioWidgetBundle: WidgetBundle {

    @WidgetBundleBuilder
    var body: some Widget {
        PlayRandomSoundControl()
        if FeatureFlags.dailySoundWidgetEnabled {
            DailySoundWidget()
        }
    }
}
