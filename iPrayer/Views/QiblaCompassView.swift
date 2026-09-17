//
//  QiblaCompassView.swift
//  iPrayer
//
//  Created by Youssef Keram on 11/23/25.
//

import SwiftUI

struct QiblaCompassView: View {
    @EnvironmentObject var viewModel: PrayerViewModel
    
    @State private var radarRotation: Double = 0
    
    // Constants for layout
    let dialSize: CGFloat = 300
    let outerRingWidth: CGFloat = 20
    
    // Logic to determine if pointing at Qibla (within 5 degrees)
    var isFacingQibla: Bool {
        let difference = abs(viewModel.currentHeading - viewModel.qiblaDirection)
        let adjustedDifference = min(difference, 360 - difference)
        return adjustedDifference < 5
    }
    
    // Rotations
    var northRotation: Double {
        -viewModel.currentHeading
    }
    
    var qiblaRotation: Double {
        viewModel.qiblaDirection - viewModel.currentHeading
    }
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(gradient: Gradient(colors: [Color(hex: "0F2027"), Color(hex: "203A43"), Color(hex: "2C5364")]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 40) {
                
                // Header
                HStack {
                    Text("Qibla Compass")
                        .font(.custom("AvenirNext-Bold", size: 34))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                Spacer()

                ZStack {
                    // Outer Glow Ring (Gold when facing)
                    Circle()
                        .stroke(isFacingQibla ? Color.yellow.opacity(0.6) : Color.clear, lineWidth: 20)
                        .frame(width: dialSize + 10, height: dialSize + 10)
                        .blur(radius: 15)
                        .animation(.easeInOut, value: isFacingQibla)
                    
                    // Main White Dial Ring
                    Circle()
                        .stroke(Color.white.opacity(0.8), lineWidth: 2)
                        .frame(width: dialSize, height: dialSize)
                        .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                    
                    // Inner Background & Radar
                    ZStack {
                        Circle()
                            .fill(Material.ultraThinMaterial)
                            .frame(width: dialSize - outerRingWidth, height: dialSize - outerRingWidth)
                        
                        // Radar Sweep
                        AngularGradient(
                            gradient: Gradient(colors: [Color.clear, Color.teal.opacity(0.3)]),
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        )
                        .mask(Circle().frame(width: dialSize - outerRingWidth, height: dialSize - outerRingWidth))
                        .rotationEffect(.degrees(radarRotation))
                        .onAppear {
                            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                                radarRotation = 360
                            }
                        }
                        
                        // Center dot
                        Circle()
                            .fill(Color.teal)
                            .frame(width: 8, height: 8)
                    }

                    // Minimalist Dot Markers (Compass Bearings)
                    ZStack {
                        ForEach(0..<36) { i in
                            VStack {
                                Circle()
                                    .fill(i % 9 == 0 ? Color.white : Color.white.opacity(0.3))
                                    .frame(width: i % 9 == 0 ? 6 : 3, height: i % 9 == 0 ? 6 : 3)
                                Spacer()
                            }
                            .frame(height: dialSize - 15)
                            .rotationEffect(.degrees(Double(i) * 10))
                        }
                    }
                    .rotationEffect(.degrees(northRotation))
                    .animation(.easeInOut(duration: 0.2), value: northRotation)

                    // Qibla Indicator
                    VStack {
                        // The Arrow Tip
                        Image(systemName: "arrowtriangle.up.fill")
                            .resizable()
                            .frame(width: 14, height: 14)
                            .foregroundColor(isFacingQibla ? .yellow : .teal)
                        
                        // The Kaaba Icon Wrapper
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 44, height: 44)
                                .shadow(color: isFacingQibla ? .yellow.opacity(0.8) : .black.opacity(0.2), radius: isFacingQibla ? 20 : 3)
                            
                            // Glowing ring around Kaaba when aligned
                            if isFacingQibla {
                                Circle()
                                    .stroke(Color.yellow, lineWidth: 2)
                                    .frame(width: 48, height: 48)
                                    .blur(radius: 2)
                            }
                            
                            // Kaaba Emoji
                            Text("🕋")
                                .font(.system(size: 28))
                        }
                        
                        Spacer()
                    }
                    .frame(height: dialSize + 70) // extend beyond ring
                    .rotationEffect(.degrees(qiblaRotation))
                    .animation(.spring(response: 0.6, dampingFraction: 0.5), value: qiblaRotation)
                }
                
                Spacer()
                
                // Status Text
                VStack(spacing: 10) {
                    Text(isFacingQibla ? "You're facing Mecca" : "Turn to face Mecca")
                        .font(.custom("AvenirNext-Bold", size: 22))
                        .foregroundColor(isFacingQibla ? .yellow : .white)
                        .animation(.easeInOut, value: isFacingQibla)
                    
                    Text("Qibla bearing: \(Int(viewModel.qiblaDirection))°")
                        .font(.custom("AvenirNext-Medium", size: 16))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.bottom, 120) // Padding for tab bar
            }
        }
        .onAppear {
            viewModel.startCompass()
        }
        .onDisappear {
            viewModel.stopCompass()
        }
        .onChange(of: isFacingQibla) { _, newValue in
            if newValue {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        }
    }
}
