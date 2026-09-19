//
//  Haptics.swift
//  iPrayer
//
//  One place for the app's haptic vocabulary, so every screen uses the same few sensations:
//  `tap` for pressing a card, `selection` for switching tabs, `success` when something completes,
//  `rigid` when something is deleted. Those are one-shots, fired on a deliberate touch.
//  `Ratchet` is the one streamed sensation and is built differently; its own comment says why.
//

import UIKit
import CoreHaptics

@MainActor
enum Haptics {
    /// Whether this device has a Taptic Engine. Every iPhone on iOS 26 does; no iPad and no Simulator
    /// does, where every call below is a silent no-op that still allocates. Read once: it cannot change.
    /// This is the only public way to ask — there is no `UIDevice.hasTapticEngine`.
    static let supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics

    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func soft() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func rigid() { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}

extension Haptics {
    /// `Ratchet` is the compass's detent: a run of `selection`-weight clicks, one per notch of the dial, so
    /// turning the phone feels like turning a bezel instead of watching a needle slide.
    ///
    /// It is the only sensation in this file that is *streamed*, and that is why it is a class rather than
    /// another static. The one-shots above build a generator per call and throw it away, which is right for
    /// a press — the finger is already down, so the 50-100 ms cold ramp is masked. A stream cannot do that:
    /// every click would start cold and land behind the wrist. So one generator is held for the life of the
    /// screen and re-`prepare()`d after every click, which is the picker-wheel pattern. While someone is
    /// turning, clicks are ~110 ms apart so the engine never idles; when they stop, the re-prepares stop with
    /// them and it idles out on its own in a second or two. No timer drives any of this — `headingFilter = 1`
    /// means a still phone sends nothing, so idle cost is exactly zero.
    ///
    /// Owned one per screen: `begin(at:)` when the compass starts, `end()` when it stops or backgrounds.
    @MainActor
    final class Ratchet {
        /// Notch sizes, finest first. Each divides 360 and the next one up, and the lattice is anchored on
        /// the Qibla, so the target is a notch in all three and changing tier can never double a click.
        private static let spacings: [Double] = [5, 15, 45]
        /// Widen a tier above this many degrees per second; narrow below the matching figure underneath.
        /// The gap between the two is the hysteresis that stops a turn hovering on the line from flapping.
        /// A tier is left at ~9 clicks a second, the fastest the Taptic Engine renders as separate taps.
        private static let widenAbove: [Double] = [45, 135]
        private static let narrowBelow: [Double] = [35, 105]
        /// Longer than this between readings and the stream counts as new. `headingFilter = 1` means a
        /// resting phone sends nothing, so a lone reading after a silence is sensor noise or a return from
        /// the background — never a turn.
        private static let streamGap: CFTimeInterval = 0.25
        /// Readings swallowed after any re-anchor, so a settling magnetometer cannot click on its own.
        private static let warmupReadings = 2
        /// Nothing may follow a click sooner than this, whatever the arithmetic says. A backstop only: the
        /// tiers already hold the natural cadence at ~110 ms.
        private static let minimumGap: CFTimeInterval = 0.06
        /// A single reading's rate is capped before it enters the average; one 1° step across a 5 ms frame
        /// would otherwise read as 200°/s and jump a tier.
        private static let rateCeiling: Double = 720

        /// Where the arithmetic runs at all. In DEBUG it runs without a Taptic Engine too, so
        /// `-debugSpinCompass 1` can log the click pattern on the Simulator, where nothing can be felt.
        private static var canRun: Bool {
            #if DEBUG
            return true
            #else
            return Haptics.supportsHaptics
            #endif
        }

        private var generator: UISelectionFeedbackGenerator?
        private var running = false
        private var notch = 0
        private var spacingIndex = 0
        private var lastAngle: Double = 0
        private var lastReading: CFTimeInterval = 0
        private var lastClick: CFTimeInterval = 0
        private var lastDirection = 0
        private var rate: Double = 0
        private var warmup = 0
        private var mutedUntil: CFTimeInterval = 0

        private var spacing: Double { Self.spacings[spacingIndex] }

        /// Warms the engine and silently takes the dial's current angle as the starting notch, so opening
        /// the screen never clicks off the first reading.
        func begin(at angle: Double) {
            guard Self.canRun, !running else { return }
            running = true
            if Haptics.supportsHaptics {
                let generator = UISelectionFeedbackGenerator()
                generator.prepare()
                self.generator = generator
            }
            spacingIndex = 0
            lastClick = 0
            mutedUntil = 0
            reseed(at: angle)
        }

        /// Drops the generator so the Taptic Engine is not held warm behind another screen or in the
        /// background. Safe to call when it was never started.
        func end() {
            running = false
            generator = nil
        }

        /// Re-anchors the lattice without clicking. Call whenever the angle can jump for a reason that is
        /// not the phone turning: a new Qibla bearing (it moves on every location fix), a return from the
        /// background, the screen appearing.
        func reseed(at angle: Double) {
            notch = Int((angle / spacing).rounded())
            lastAngle = angle
            lastReading = CACurrentMediaTime()
            lastDirection = 0
            rate = 0
            warmup = Self.warmupReadings
        }

        /// Keeps the ratchet quiet for `seconds`. Used while `success()` plays its half-second pattern; a
        /// click landing inside that window turns the two sensations into one stutter.
        func mute(for seconds: CFTimeInterval) {
            mutedUntil = CACurrentMediaTime() + seconds
        }

        /// One reading of the dial. `angle` is the continuous, never-rewrapped angle from the phone to the
        /// Qibla, so zero is the Qibla itself and passing north is not a discontinuity.
        ///
        /// At most one click per call, however many notches the reading skipped: SwiftUI can coalesce
        /// several headings into one change, and paying that back as a burst is the buzz this design exists
        /// to avoid. Nothing is ever queued — the skipped notches are simply gone.
        func update(angle: Double, trustworthy: Bool) {
            guard running else { return }
            let now = CACurrentMediaTime()
            let gap = now - lastReading
            lastReading = now

            // An untrustworthy heading, a gap in the stream, or the lock notification still playing:
            // re-anchor and say nothing. Re-anchoring is what stops the silence being paid back afterwards.
            guard trustworthy, gap > 0, gap < Self.streamGap, now >= mutedUntil else {
                reseed(at: angle)
                return
            }

            let travelled = angle - lastAngle
            lastAngle = angle
            let instant = min(abs(travelled) / gap, Self.rateCeiling)
            rate = rate <= 0 ? instant : rate * 0.6 + instant * 0.4

            let tier = tierIndex(for: rate)
            if tier != spacingIndex {
                spacingIndex = tier
                notch = Int((angle / spacing).rounded())
                return
            }

            if warmup > 0 {
                warmup -= 1
                notch = Int((angle / spacing).rounded())
                return
            }

            let target = Int((angle / spacing).rounded())
            guard target != notch else { return }
            let direction = target > notch ? 1 : -1

            // A heading wobbling either side of one notch line would otherwise click forever. Turning back
            // has to travel four tenths of a notch past the line before it counts — 2° at the fine setting,
            // well under the dial's own 0.25 s spring lag and invisible against a real turn.
            if lastDirection != 0, direction != lastDirection,
               abs(angle - Double(notch) * spacing) < spacing * 1.4 {
                return
            }

            notch = target
            guard now - lastClick >= Self.minimumGap else { return }  // swallow, never queue
            lastClick = now
            lastDirection = direction
            generator?.selectionChanged()
            generator?.prepare()   // the next notch is ~110 ms away; keep the engine out of its cold ramp
            #if DEBUG
            // NSLog, not print: this is read back with `log show` and print never reaches the unified log
            NSLog("[QiblaRatchet] notch %d · %d° · %d°/s", notch, Int(spacing), Int(rate))
            #endif
        }

        private func tierIndex(for rate: Double) -> Int {
            var index = spacingIndex
            while index < Self.spacings.count - 1, rate > Self.widenAbove[index] { index += 1 }
            while index > 0, rate < Self.narrowBelow[index - 1] { index -= 1 }
            return index
        }
    }
}
