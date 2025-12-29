//
//  FitLinkWatchComplicationsBundle.swift
//  FitLinkWatchComplications
//
//  Created by Gökay Ege Süren on 29.12.2025.
//

import WidgetKit
import SwiftUI

@main
struct FitLinkWatchComplicationsBundle: WidgetBundle {
    var body: some Widget {
        StreakComplication()
        TimerComplication()
    }
}
