import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage(UDKey.appLanguage.rawValue) private var appLanguage: String = "en"

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var body: some View {
        ZStack {
            // Background Gradient
            LinearGradient(gradient: Gradient(colors: [Color(hex: "0F2027"), Color(hex: "203A43"), Color(hex: "2C5364")]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)

            // Background Effect
            BackgroundPatternView()
                .opacity(0.3)
                .edgesIgnoringSafeArea(.all)

            VStack(alignment: .leading, spacing: 0) {
                // Top Custom Nav Bar
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.backward")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .glassEffect(.regular.interactive(), in: .circle)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)

                // Title
                Text("About")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                // Everything is sized to fit a 6.1" screen without scrolling; the ScrollView is only a
                // fallback for smaller devices and accessibility text sizes.
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        // App Icon and Version
                        VStack(spacing: 10) {
                            if let icon = Bundle.main.icon {
                                Image(uiImage: icon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 84, height: 84)
                                    .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 19, style: .continuous)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                                    .shadow(color: .black.opacity(0.5), radius: 12, x: 0, y: 4)
                            } else {
                                Image(systemName: "moon.stars.fill")
                                    .font(.system(size: 42))
                                    .foregroundColor(.white)
                                    .frame(width: 84, height: 84)
                                    .background(Color.teal)
                                    .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                                    .shadow(color: .teal.opacity(0.5), radius: 12, x: 0, y: 4)
                            }

                            VStack(spacing: 2) {
                                Text("iPrayer")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)

                                Text("\(AppTranslations.catalogString("Version", language: appLanguage)) \(appVersion)")
                                    .font(.system(size: 15))
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.top, 12)

                        // Resources Section
                        section(title: Text("Resources")) {
                            LinkRow(title: "Terms of Use", icon: "doc.text.fill", url: "https://x3roe.com/iprayer-terms.html")
                            LinkRow.divider
                            LinkRow(title: "Privacy Policy", icon: "hand.raised.fill", url: "https://x3roe.com/iprayer-privacy.html")
                            LinkRow.divider
                            LinkRow(title: "Developer Website", icon: "safari.fill", url: "https://x3roe.com/")
                        }

                        // Acknowledgements. The recitation audio (CC BY-NC) and the Tanzil Quran text both require attribution.
                        section(title: Text(AppTranslations.translate("Acknowledgements", to: appLanguage))) {
                            LinkRow(title: "Tanzil Project", subtitle: AppTranslations.translate("Quran text", to: appLanguage),
                                    icon: "book.closed.fill", url: "https://tanzil.net")
                            LinkRow.divider
                            LinkRow(title: "EveryAyah.com", subtitle: AppTranslations.translate("Recitation audio", to: appLanguage),
                                    icon: "headphones", url: "https://everyayah.com")
                            LinkRow.divider
                            LinkRow(title: "Adhan by Batoul Apps", subtitle: AppTranslations.translate("Prayer times", to: appLanguage),
                                    icon: "clock.fill", url: "https://github.com/batoulapps/adhan-swift")
                        }

                        Text("© \(String(Calendar.current.component(.year, from: Date()))) Youssef Keram. All rights reserved.")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 6)
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationBarHidden(true)
    }

    private func section<Content: View>(title: Text, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            title
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.gray)
                .padding(.horizontal, 5)

            VStack(spacing: 0) {
                content()
            }
            .background(Material.ultraThinMaterial)
            .cornerRadius(22)
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .padding(.horizontal, 20)
    }
}

struct LinkRow: View {
    let title: String
    var subtitle: String? = nil
    let icon: String
    let url: String

    static var divider: some View {
        // A solid 1pt line rather than Divider: its hairline can fall between pixels on a device and vanish
        Rectangle().fill(Color.white.opacity(0.15)).frame(height: 1).padding(.leading, 56)
    }

    var body: some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .foregroundColor(.teal)
                    .font(.system(size: 18))
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 1) {
                    Text(LocalizedStringKey(title))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.teal)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                }
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 11)
            .padding(.horizontal, 18)
        }
    }
}

#Preview {
    AboutView()
}
