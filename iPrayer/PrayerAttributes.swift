//
//  PrayerAttributes.swift
//  iPrayer
//

import Foundation
import ActivityKit

// nonisolated: the target defaults to MainActor isolation, which would make this conformance
// unusable from ActivityKit's concurrent contexts (an error in Swift 6).
nonisolated public struct PrayerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic data that changes during the activity
        public var timeRemaining: ClosedRange<Date>
        public var prayerName: String
        public var prayerIcon: String
        public var prayerTime: String
        public var atString: String
        public var startsInString: String
        public var nextString: String
        // Optional so activities started by an older build still decode
        /// Shown instead of the countdown once the prayer time has arrived.
        public var nowString: String?
        public var openHintString: String?
        /// English prayer name ("Fajr", "Dhuhr"...), used to pick the colors. `prayerName` is translated.
        public var prayerKey: String?
    }
    
    // Static data that doesn't change
    public var dummy: Int = 0
}
