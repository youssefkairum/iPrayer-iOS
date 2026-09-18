//
//  iPrayerWatchWidgetBundle.swift
//  iPrayerWatchWidget
//
//  Watch face complications.
//

import WidgetKit
import SwiftUI

@main
struct iPrayerWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        NextPrayerComplication()
    }
}
