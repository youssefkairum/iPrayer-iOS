//
//  TasbihView.swift
//  iPrayer
//
//  Created by Youssef Keram on 11/24/25.
//

import SwiftUI

struct TasbihView: View {
    @AppStorage(UDKey.tasbihCount.rawValue) private var count: Int = 0
    @AppStorage(UDKey.appLanguage.rawValue) private var appLanguage: String = "en"
    @AppStorage(UDKey.tasbihTarget.rawValue) private var cycleTarget: Int = 33
    @State private var ripples: [UUID] = []
    @State private var syncTask: Task<Void, Never>?
    
    var progress: CGFloat {
        if cycleTarget == 0 { return 0 }
        return CGFloat(count % cycleTarget) / CGFloat(cycleTarget)
    }
    
    var completedCycles: Int {
        if cycleTarget == 0 { return 0 }
        return count / cycleTarget
    }
    
    // Dynamically calculate dash array to always perfectly match the target count
    var dashArray: [CGFloat] {
        let target = cycleTarget == 0 ? 1 : cycleTarget
        let circumference = 220 * CGFloat.pi
        let gap = (circumference / CGFloat(target)) - 1
        return [1, max(gap, 0.1)]
    }
    
    // Trim strictly halfway through the gap to avoid lighting up the next bead
    var progressTrim: CGFloat {
        if cycleTarget == 0 || count == 0 { return 0 }
        if count % cycleTarget == 0 { return 1.0 }
        let currentCycleCount = count % cycleTarget
        return (CGFloat(currentCycleCount) - 0.5) / CGFloat(cycleTarget)
    }
    
    var body: some View {
        ZStack {
            // Background Gradient
            LinearGradient(gradient: Gradient(colors: [Color(hex: "0F2027"), Color(hex: "203A43"), Color(hex: "2C5364")]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 15) {
                // Header
                HStack {
                    Text("Tasbih")
                        .font(.custom("AvenirNext-Bold", size: 34))
                        .foregroundColor(.white)
                    Spacer()
                    
                    // Reset Button
                    Button(action: resetCounter) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.8))
                            .padding(10)
                            .background(Material.ultraThinMaterial)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                // Target Picker
                Picker("Target", selection: $cycleTarget) {
                    Text("33").tag(33)
                    Text("99").tag(99)
                    Text("100").tag(100)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .colorScheme(.dark)
                
                // Cycles Tracker
                HStack {
                    Text(AppTranslations.translate("Cycles Completed: ", to: appLanguage))
                        .font(.custom("AvenirNext-Medium", size: 16))
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(completedCycles)")
                        .font(.custom("AvenirNext-Bold", size: 16))
                        .foregroundColor(.teal)
                }
                .padding(.top, 5)
                
                Spacer(minLength: 10)
                
                // Main Interaction Button
                Button(action: incrementCounter) {
                    ZStack {
                        // Ripples
                        ForEach(ripples, id: \.self) { id in
                            RippleEffect()
                        }
                        
                        // Outer Glow
                        Circle()
                            .fill(Color.teal.opacity(0.1))
                            .frame(width: 280, height: 280)
                            .blur(radius: 20)
                        
                        // Background Circle
                        Circle()
                            .fill(Material.ultraThinMaterial)
                            .frame(width: 250, height: 250)
                            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                        
                        // Background Dashed Ring (Beads)
                        Circle()
                            .stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 12, lineCap: .round, dash: dashArray))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 220, height: 220)
                        
                        // Active Progress Ring (Teal Beads)
                        Circle()
                            .trim(from: 0.0, to: progressTrim)
                            .stroke(
                                AngularGradient(gradient: Gradient(colors: [.teal.opacity(0.6), .teal]), center: .center),
                                style: StrokeStyle(lineWidth: 12, lineCap: .round, dash: dashArray)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 220, height: 220)
                            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: count)
                        
                        // Counter Text
                        VStack(spacing: 0) {
                            Text("\(count)")
                                .font(.system(size: 65, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .contentTransition(.numericText(countsDown: false))
                            
                            HStack(spacing: 4) {
                                Text("OUT OF")
                                Text("\(cycleTarget)")
                            }
                                .font(.custom("AvenirNext-Medium", size: 12))
                                .foregroundColor(.teal)
                                .padding(.top, 5)
                        }
                    }
                }
                .buttonStyle(ScaleButtonStyle())
                
                Spacer(minLength: 10)
                
                Text("Tap anywhere on the circle to count")
                    .font(.custom("AvenirNext-Medium", size: 14))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.bottom, 130) // Increased padding to clear tab bar
            }
        }
        .onChange(of: count) { _, newValue in
            // Debounce: every tap would otherwise write to the iCloud key-value store immediately
            syncTask?.cancel()
            syncTask = Task {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                CloudSyncManager.shared.sync(key: "tasbihCount", value: newValue)
            }
        }
        .onChange(of: cycleTarget) { _, newValue in
            CloudSyncManager.shared.sync(key: "tasbihTarget", value: newValue)
        }
        .onAppear {
            if cycleTarget == 0 {
                cycleTarget = 33
            }
        }
    }
    
    // MARK: - Actions
    
    private func incrementCounter() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        
        // Add ripple
        let newRipple = UUID()
        ripples.append(newRipple)
        
        // Remove ripple after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            ripples.removeAll { $0 == newRipple }
        }
        
        withAnimation {
            count += 1
        }
        
        // Special feedback when cycle completes
        if cycleTarget > 0 && count % cycleTarget == 0 && count != 0 {
            let heavy = UIImpactFeedbackGenerator(style: .heavy)
            heavy.impactOccurred()
        }
    }
    
    private func resetCounter() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        withAnimation {
            count = 0
        }
    }
}

// Ripple Animation View
struct RippleEffect: View {
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0.5
    
    var body: some View {
        Circle()
            .stroke(Color.teal.opacity(opacity), lineWidth: 4)
            .frame(width: 250, height: 250)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) {
                    scale = 1.3
                    opacity = 0
                }
            }
    }
}

// Custom Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
