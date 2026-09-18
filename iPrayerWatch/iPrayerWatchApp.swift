//
//  iPrayerWatchApp.swift
//  iPrayerWatch
//
//  The Apple Watch companion. It calculates prayer times itself from the watch's location (or the
//  phone's, as a fallback), so it works without the iPhone nearby.
//

import SwiftUI

@main
struct iPrayerWatchApp: App {
    @StateObject private var model = WatchModel.shared
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(model)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                // Back on the wrist after a while: new day, new location, fresh times
                HomeWidgetsData.shared.refreshDayState()
                model.start()
            case .background:
                model.stop()
            default:
                break
            }
        }
        // A few times a day, off-wrist: refresh the location so the complications follow the wearer
        .backgroundTask(.appRefresh(WatchModel.backgroundRefreshIdentifier)) {
            await WatchModel.shared.backgroundRefresh()
        }
    }
}
