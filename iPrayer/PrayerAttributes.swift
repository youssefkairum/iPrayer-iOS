//
//  PrayerAttributes.swift
//  iPrayer
//

import Foundation
import ActivityKit

public struct PrayerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic data that changes during the activity
        public var timeRemaining: ClosedRange<Date>
        public var prayerName: String
        public var prayerIcon: String
        public var prayerTime: String
        public var atString: String
        public var startsInString: String
        public var nextString: String
    }
    
    // Static data that doesn't change
    public var dummy: Int = 0
}
