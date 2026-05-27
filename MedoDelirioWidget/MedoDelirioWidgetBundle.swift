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

    var body: some Widget {
        PlayRandomSoundControl()
#if DAILY_SOUND_WIDGET_ENABLED
        DailySoundWidget()
#endif
    }
}
