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

    /// Both compass sensations back to back, for the Settings test button: the "facing Mecca" chime, then
    /// a single detent click 600 ms later. This is the only thing the owner can do without a debugger.
    /// Feeling neither means the phone is silencing them (Low Power Mode, or Sounds & Haptics), not us.
    static func testCompassPair() {
        success()
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            generator.selectionChanged()
        }
    }
}

extension Haptics {
    /// `Ratchet` is the compass's detent: one `selection`-weight click per notch of the dial, so turning
    /// the phone feels like turning a bezel instead of watching a needle slide.
    ///
    /// It is the only *streamed* sensation in this file, which is why it is a class rather than another
    /// static. The one-shots above build a generator per call and throw it away — right for a press, where
    /// the finger is already down and the 50-100 ms cold ramp is masked. A stream cannot do that, so one
    /// generator is held for the life of the screen and re-`prepare()`d after every click.
    ///
    /// Deliberately stupid. There are exactly two ways this can stay quiet: the dial has not crossed a
    /// notch, or the last click was under `minimumGap` ago. Speed tiers, a stream-gap timer, a warm-up
    /// count, a mute window, a reversal dead zone and a sensor-accuracy gate are all gone. Between them
    /// they could swallow a click eleven different ways, and not one of them was worth a compass that
    /// feels dead in the hand.
    ///
    /// Owned one per screen: `begin(at:)` when the compass starts, `end()` when it stops or backgrounds.
    @MainActor
    final class Ratchet {
        /// One notch, at every speed. 5 degrees divides 360 and lands exactly on the 72 ticks the rose
        /// already draws, so a click always coincides with a mark going past the pointer.
        private static let spacing: Double = 5
        /// A notch is entered only by travelling a WHOLE notch from the last one, in either direction.
        /// Rounding to the nearest notch instead would re-centre on each click and leave the dial sitting a
        /// fraction from the next boundary, so a hand tremor could rattle back and forth across it — and now
        /// that readings arrive unfiltered, that tremor is visible to us. A full notch of reversal, 5°, is
        /// wider than any hand shake, and forward travel still clicks exactly every 5°.
        /// Nothing may follow a click sooner than this: ~11 a second, the fastest the Taptic Engine still
        /// renders as separate taps. A violent whip of the phone is capped here rather than humming.
        private static let minimumGap: CFTimeInterval = 0.09

        private var generator: UISelectionFeedbackGenerator?
        private var notch = 0
        private var lastClick: CFTimeInterval = 0

        /// Clicks emitted over this screen's lifetime. Read only by the compass's diagnostics line.
        private(set) var clicks = 0

        /// Warms the engine and silently takes the dial's current angle as the starting notch, so opening
        /// the screen never clicks off the first reading. Safe to call again; it will not double up.
        func begin(at angle: Double) {
            if generator == nil {
                let generator = UISelectionFeedbackGenerator()
                generator.prepare()
                self.generator = generator
            }
            lastClick = 0
            reseed(at: angle)
        }

        /// Drops the generator so the Taptic Engine is not held warm behind another screen or in the
        /// background. Safe to call when it was never started.
        func end() {
            generator = nil
        }

        /// Re-anchors the lattice without clicking. Call whenever the angle can jump for a reason that is
        /// not the phone turning: a new Qibla bearing (it moves on every location fix), a return from the
        /// background, the screen appearing.
        func reseed(at angle: Double) {
            notch = Int((angle / Self.spacing).rounded())
        }

        /// One reading of the dial. `angle` is the continuous, never-rewrapped angle from the phone to the
        /// Qibla, so zero is the Qibla itself and passing north is not a discontinuity.
        ///
        /// At most one click per call, however many notches the reading skipped: SwiftUI can coalesce
        /// several headings into one change, and paying that back as a burst is the buzz this exists to
        /// avoid. Nothing is queued — the skipped notches are simply gone.
        func update(angle: Double) {
            guard generator != nil else { return }   // not on screen, or haptics switched off
            let position = angle / Self.spacing
            if position >= Double(notch) + 1 {
                notch += 1
            } else if position <= Double(notch) - 1 {
                notch -= 1
            } else {
                return
            }
            let now = CACurrentMediaTime()
            guard now - lastClick >= Self.minimumGap else { return }  // swallow, never queue
            lastClick = now
            clicks += 1
            #if DEBUG
            // NSLog, not print: this is read back with `log show`, which print never reaches
            NSLog("[QiblaRatchet] notch %d · click %d", notch, clicks)
            #endif
            generator?.selectionChanged()
            generator?.prepare()   // the next notch is close behind; keep the engine out of its cold ramp
        }
    }
}
