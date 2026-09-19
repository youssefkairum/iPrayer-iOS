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
    @AppStorage(UDKey.compassDiagnostics.rawValue) private var compassDiagnostics: Bool = false
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
    /// Heading readings seen since the screen opened. Counted only while diagnostics are on, so it costs
    /// nothing in the normal case; the body is already re-evaluating on this exact change.
    @State private var headingReadings = 0
    
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
    
    /// One curve for everything the heading moves. A spring is retargeted in flight and carries its
    /// velocity into the next reading, where a timing curve restarts from a standstill on every one and
    /// never leaves its slow-in shoulder. Critically damped, so the dial settles without wobble.
    ///
    /// A critically damped spring following a turning phone sits a fixed 2*response/(2*pi) behind it —
    /// 80 ms at the 0.25 this used to be, about 7 degrees of visible trail at a normal hand sweep, which
    /// is a rose tick and a half. 0.12 cuts that to 38 ms and roughly 3 degrees. It is only usable
    /// alongside `headingFilter = kCLHeadingFilterNone`: at a 1-degree filter a shorter spring just makes
    /// the 1-degree steps visible as steps instead of hiding them.
    private static let dialMotion: Animation = .spring(response: 0.12, dampingFraction: 1)
    
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
    
    /// One heading reading: move the lock latch, then hand the raw angle to the ratchet.
    ///
    /// Nothing here is conditional on the magnetometer's own error estimate any more. It was, and that gate
    /// had exactly one failure mode — silence — on the one screen where silence is the whole complaint.
    /// `CLHeading.headingAccuracy` sits well above 15 degrees indoors on a real iPhone, which is precisely
    /// where this screen gets used; the status card below already asks for a figure-8 in that state, so the
    /// person is told. A click on a rough heading is worth more than a compass that feels broken.
    ///
    /// Both the latch and the ratchet run off `viewModel.currentHeading`, not the animated presentation
    /// value, so a click leads the pixels by the dial spring's settle time. That is the right way round:
    /// hand-to-click stays inside the window where motion and sensation read as one event.
/// A line the owner can photograph and send when the compass still feels wrong, since they cannot run
    /// a debugger for us. `acc` is the magnetometer's own error estimate — the value that used to gate
    /// every haptic on this screen. `reads` against `clicks` says whether headings are arriving at all and
    /// whether the detent is firing on them: reads climbing with clicks stuck at 0 is our bug, both
    /// climbing while nothing is felt is the phone's. Off by default; Settings › General › Compass
    /// Diagnostics.
    private var diagnosticsLine: String {
        let accuracy = viewModel.headingAccuracy.map { String(format: "%.0f°", $0) } ?? "—"
        let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled ? " · LOW POWER" : ""
        let taptic = Haptics.supportsHaptics ? "y" : "n"
        return "acc \(accuracy) · \(headingReadings) reads · \(ratchet.clicks) clicks · taptic \(taptic)\(lowPower)"
    }
    
    private func headingChanged() {
        if compassDiagnostics { headingReadings += 1 }
        let aligned = abs(offset) < (isFacingQibla ? Self.releaseTolerance : Self.facingTolerance)
        if aligned != isFacingQibla {
            isFacingQibla = aligned
            if aligned { Haptics.success() }
        }
        ratchet.update(angle: qiblaRotation)
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
            
            if compassDiagnostics {
                Text(diagnosticsLine)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundColor(.white.opacity(0.55))
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
