//
//  QiblaCompassView.swift
//  iPrayer
//
//  A compass dial that turns with the phone's heading while the Kaaba pointer stays on the Qibla, so
//  the pointer straight up means you are facing Mecca. Below the dial: which way to turn and by how
//  much, the bearing, and the distance to Mecca.
//

import SwiftUI
import CoreLocation

struct QiblaCompassView: View {
    @EnvironmentObject var viewModel: PrayerViewModel
    @AppStorage(UDKey.appLanguage.rawValue) private var appLanguage: String = "en"
    @AppStorage(UDKey.compassHapticsEnabled.rawValue) private var compassHapticsEnabled: Bool = true
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var radarRotation: Double = 0
    @State private var distanceText: String?
    /// The detent engine for this screen: one prepared generator, alive only while the compass is.
    @State private var ratchet = Haptics.Ratchet()
    /// Latched rather than computed: the lock is taken at 5° and only given up at 8°. A heading sitting on
    /// a bare 5° line used to re-enter this state over and over, re-firing `success()` every time and
    /// re-lighting the whole dial with it.
    @State private var isFacingQibla = false
    
    private static let kaaba = CLLocation(latitude: 21.422487, longitude: 39.826206)
    private static let facingTolerance = 5.0
    private static let releaseTolerance = 8.0
    
    /// Signed difference from the phone's heading to the Qibla, in -180...180 (positive = turn right).
    /// This is the GUIDANCE value: it drives the turn text and the facing state, never a rotation.
    private var offset: Double {
        var delta = (viewModel.qiblaDirection - viewModel.currentHeading).truncatingRemainder(dividingBy: 360)
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        return delta
    }
    
    /// The needle's angle, taken from the same continuous heading the rose turns on and never re-wrapped.
    /// The needle stays rigid with the rose — the Kaaba tip sits exactly over the Qibla mark at every
    /// instant — and can no longer swing the long way round when the phone sweeps past the opposite bearing.
    private var qiblaRotation: Double { viewModel.qiblaDirection - viewModel.currentHeading }
    
    /// One curve for everything the heading moves. A spring is retargeted in flight and carries its velocity
    /// into the next reading, where a timing curve restarts from a standstill 20 to 50 times a second and
    /// never leaves its slow-in shoulder. Critically damped, so the dial settles without the wobble the old
    /// 0.65-damped needle left after every turn.
    private static let dialMotion: Animation = .spring(response: 0.25, dampingFraction: 1)
    
    private var hasLocation: Bool {
        viewModel.locationError == nil && viewModel.locationAuthorization != .notDetermined && viewModel.qiblaDirection != 0
    }
    
    /// Units follow the device region (km or miles), not the app language. Built once: allocating a
    /// MeasurementFormatter is expensive and this used to happen on every heading reading.
    private static let distanceFormatter: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.locale = Locale.current
        formatter.unitOptions = .naturalScale
        formatter.numberFormatter.maximumFractionDigits = 0
        return formatter
    }()
    
    /// Distance from the last known position to the Kaaba, in the user's units. Read once when the screen
    /// appears rather than recomputed per heading reading: it is a property of the location, and working it
    /// out meant an App Group read and a JSON decode 20 to 50 times a second while the phone turned.
    private static func distanceToKaaba() -> String? {
        guard let config = SharedPrayerConfig.load() else { return nil }
        let here = CLLocation(latitude: config.latitude, longitude: config.longitude)
        let metres = here.distance(from: kaaba)
        return distanceFormatter.string(from: Measurement(value: metres, unit: UnitLength.meters))
    }
    
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color(hex: "0F2027"), Color(hex: "203A43"), Color(hex: "2C5364")]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)
            
            BackgroundPatternView()
                .opacity(0.25)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                header
                
                Spacer(minLength: 8)
                
                GeometryReader { geometry in
                    let size = min(geometry.size.width - 56, 320)
                    dial(size: size)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
                
                Spacer(minLength: 8)
                
                Group {
                    if hasLocation {
                        statusCard
                    } else {
                        locationCard
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 108) // clear the floating tab bar
            }
        }
        .onAppear {
            viewModel.startCompass()
            distanceText = Self.distanceToKaaba()
            if compassHapticsEnabled { ratchet.begin(at: qiblaRotation) }
        }
        .onChange(of: viewModel.qiblaDirection) { _, _ in
            distanceText = Self.distanceToKaaba()
            // The detent lattice is anchored on the Qibla, and the Qibla just moved. Re-anchor in silence.
            ratchet.reseed(at: qiblaRotation)
        }
        .onDisappear {
            viewModel.stopCompass()
            ratchet.end()
        }
        .onChange(of: viewModel.currentHeading) { _, _ in headingChanged() }
        .onChange(of: compassHapticsEnabled) { _, enabled in
            if enabled { ratchet.begin(at: qiblaRotation) } else { ratchet.end() }
        }
        .onChange(of: scenePhase) { _, phase in
            // onDisappear does not fire when the app is backgrounded from this screen, and the engine must
            // not be left warm there. Coming back, the heading may have jumped tens of degrees in one
            // delta, so begin() re-anchors rather than paying that out as clicks.
            if phase == .active {
                if compassHapticsEnabled { ratchet.begin(at: qiblaRotation) }
            } else {
                ratchet.end()
            }
        }
    }
    
    // MARK: - Haptics
    
    /// The magnetometer's own verdict on the reading: nil until the first one, negative when CoreLocation
    /// says it is invalid, and past `poorHeadingAccuracy` when it wants a figure-8. All three mean stay
    /// quiet. The dial already shows the calibration banner in that state, and clicking — or congratulating
    /// someone for facing Mecca — on a heading the sensor itself calls wrong is worse than silence.
    private var headingIsTrustworthy: Bool {
        guard let accuracy = viewModel.headingAccuracy else { return false }
        return accuracy >= 0 && accuracy <= PrayerViewModel.poorHeadingAccuracy
    }
    
    /// One heading reading: move the lock latch, then hand the raw angle to the ratchet.
    ///
    /// Both run off `viewModel.currentHeading`, not the animated presentation value, so a click can lead the
    /// pixels by up to the dial spring's 0.25 s. That is the right way round: hand-to-click is ~60-120 ms
    /// (CoreLocation's pipeline plus a prepared engine), inside the window where motion and sensation still
    /// read as one event. Chasing the animation instead would push it past that.
    private func headingChanged() {
        let trustworthy = headingIsTrustworthy
        let aligned = abs(offset) < (isFacingQibla ? Self.releaseTolerance : Self.facingTolerance)
        if aligned != isFacingQibla {
            isFacingQibla = aligned
            if aligned, trustworthy {
                Haptics.success()
                // .success is a multi-part pattern about half a second long. A click inside it does not
                // layer, it stutters.
                ratchet.mute(for: 0.5)
            }
        }
        ratchet.update(angle: qiblaRotation, trustworthy: trustworthy)
    }
    
    // MARK: - Pieces
    
    private var header: some View {
        HStack(alignment: .center) {
            Text(AppTranslations.catalogString("Qibla Compass", language: appLanguage))
                .font(.custom("AvenirNext-Bold", size: 34))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer()
            HStack(spacing: 5) {
                Image(systemName: "location.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.teal)
                Text(viewModel.locationName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .glassEffect(.regular, in: .capsule)
        }
        .padding(.horizontal)
        .padding(.top, 20)
    }
    
    private func dial(size: CGFloat) -> some View {
        ZStack {
            // Gold halo when aligned
            Circle()
                .fill(isFacingQibla ? Color.yellow.opacity(0.35) : Color.teal.opacity(0.12))
                .frame(width: size + 20, height: size + 20)
                .blur(radius: 28)
                .animation(.easeInOut(duration: 0.4), value: isFacingQibla)
            
            Circle()
                .fill(Color.clear)
                .frame(width: size, height: size)
                .glassEffect(.regular, in: .circle)
            
            // Radar sweep
            AngularGradient(gradient: Gradient(colors: [.clear, Color.teal.opacity(0.22)]), center: .center)
                .mask(Circle().frame(width: size - 12, height: size - 12))
                .frame(width: size - 12, height: size - 12)
                .rotationEffect(.degrees(radarRotation))
                .onAppear {
                    withAnimation(.linear(duration: 5).repeatForever(autoreverses: false)) { radarRotation = 360 }
                }
            
            // The rose: ticks and cardinal letters turn with the heading so north stays north
            ZStack {
                ForEach(0..<72, id: \.self) { i in
                    let major = i % 18 == 0
                    let minor = i % 6 == 0
                    Capsule()
                        .fill(Color.white.opacity(major ? 0.9 : minor ? 0.5 : 0.22))
                        .frame(width: major ? 3 : 1.5, height: major ? 16 : minor ? 11 : 7)
                        .offset(y: -(size / 2) + 16)
                        .rotationEffect(.degrees(Double(i) * 5))
                }
                ForEach(Array(["N", "E", "S", "W"].enumerated()), id: \.offset) { index, letter in
                    Text(letter)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(index == 0 ? .red : .white.opacity(0.85))
                        .offset(y: -(size / 2) + 42)
                        .rotationEffect(.degrees(Double(index) * 90))
                }
            }
            .rotationEffect(.degrees(-viewModel.currentHeading))
            .animation(Self.dialMotion, value: viewModel.currentHeading)
            
            // The Kaaba pointer: a needle from the centre with the Kaaba at its tip
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 46, height: 46)
                        .shadow(color: isFacingQibla ? .yellow.opacity(0.9) : .black.opacity(0.25), radius: isFacingQibla ? 18 : 4)
                    Text("🕋").font(.system(size: 26))
                }
                Capsule()
                    .fill(LinearGradient(colors: [isFacingQibla ? .yellow : .teal, .clear], startPoint: .top, endPoint: .bottom))
                    .frame(width: 5, height: size / 2 - 70)
                Spacer(minLength: 0)
            }
            .frame(height: size)
            .rotationEffect(.degrees(qiblaRotation))
            .animation(Self.dialMotion, value: qiblaRotation)
            
            // Where the phone points: fixed at the top
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 12))
                .foregroundColor(isFacingQibla ? .yellow : .white.opacity(0.9))
                .offset(y: -(size / 2) - 10)
            
            Circle()
                .fill(isFacingQibla ? Color.yellow : Color.teal)
                .frame(width: 10, height: 10)
                .animation(.easeInOut, value: isFacingQibla)
        }
        .opacity(hasLocation ? 1 : 0.35)
    }
    
    private var statusCard: some View {
        VStack(spacing: 6) {
            Text(AppTranslations.catalogString(isFacingQibla ? "You're facing Mecca" : "Turn to face Mecca", language: appLanguage))
                .font(.custom("AvenirNext-Bold", size: 20))
                .foregroundColor(isFacingQibla ? .yellow : .white)
                .animation(.easeInOut, value: isFacingQibla)
            
            if !CLLocationManager.headingAvailable() {
                // No magnetometer (or the Simulator): the bearing below is still usable with a physical compass
                Text(AppTranslations.translate("Compass unavailable", to: appLanguage))
                    .font(.custom("AvenirNext-DemiBold", size: 15))
                    .foregroundColor(.white.opacity(0.6))
            } else if !isFacingQibla {
                let degrees = Int(abs(offset).rounded())
                Label("\(AppTranslations.translate(offset > 0 ? "Turn right" : "Turn left", to: appLanguage)) · \(degrees)°",
                      systemImage: offset > 0 ? "arrow.turn.up.right" : "arrow.turn.up.left")
                    .font(.custom("AvenirNext-DemiBold", size: 15))
                    .foregroundColor(.teal)
                    .contentTransition(.numericText())
            }
            
            // The magnetometer's own error estimate: past the threshold, ask for the figure-8 (iOS shows its
            // calibration screen at the same time, now that the delegate allows it)
            if let accuracy = viewModel.headingAccuracy, accuracy < 0 || accuracy > PrayerViewModel.poorHeadingAccuracy {
                Label(AppTranslations.translate("Move your device in a figure 8 to calibrate the compass", to: appLanguage), systemImage: "exclamationmark.triangle.fill")
                    .font(.custom("AvenirNext-DemiBold", size: 12))
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
            }
            
            HStack(spacing: 6) {
                Text("\(AppTranslations.translate("Qibla", to: appLanguage)) \(Int(viewModel.qiblaDirection.rounded()))°")
                if let distance = distanceText {
                    Text("·")
                    Text(distance)
                }
            }
            .font(.custom("AvenirNext-Medium", size: 13))
            .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(Material.ultraThinMaterial)
        .cornerRadius(22)
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
    
    private var locationCard: some View {
        VStack(spacing: 10) {
            Text(AppTranslations.translate(viewModel.locationError ?? "iPrayer uses your location to calculate prayer times and the Qibla direction.", to: appLanguage))
                .font(.custom("AvenirNext-Medium", size: 14))
                .foregroundColor(.white.opacity(0.75))
                .multilineTextAlignment(.center)
            
            let asksPermission = viewModel.locationAuthorization == .notDetermined
            Button {
                Haptics.tap()
                if asksPermission {
                    viewModel.requestLocationAccess()
                } else if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            } label: {
                Text(AppTranslations.translate(asksPermission ? "Enable Location" : "Open Settings", to: appLanguage))
                    .font(.custom("AvenirNext-Bold", size: 15))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .glassEffect(.regular.tint(.teal).interactive(), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(16)
        .background(Material.ultraThinMaterial)
        .cornerRadius(22)
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}
