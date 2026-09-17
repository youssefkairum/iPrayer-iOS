import SwiftUI

struct DuaLibraryView: View {
    @Environment(\.presentationMode) var presentationMode
    @AppStorage(UDKey.appLanguage.rawValue) private var appLanguage: String = "en"
    let data = DuaLibraryData.shared
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(gradient: Gradient(colors: [Color(hex: "0F2027"), Color(hex: "203A43"), Color(hex: "2C5364")]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(data.categories, id: \.self) { category in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(AppTranslations.translate(category, to: appLanguage))
                                .font(.custom("AvenirNext-Bold", size: 22))
                                .foregroundColor(.teal)
                                .padding(.horizontal)
                            
                            ForEach(data.duas(for: category)) { dua in
                                DuaCardView(dua: dua, appLanguage: appLanguage)
                            }
                        }
                        .padding(.bottom, 10)
                    }
                }
                .padding(.vertical, 20)
                .padding(.bottom, 80) // To account for tab bar if needed
            }
        }
        .navigationTitle(AppTranslations.translate("Duas Library", to: appLanguage))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "chevron.backward")
                        .foregroundColor(.white)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}

struct DuaCardView: View {
    let dua: AuthenticDua
    let appLanguage: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(dua.arabicText)
                .font(.custom("KFGQPC Uthmanic Script HAFS", size: 24))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineSpacing(10)
                // "trailing" means left once the app itself is right-to-left, so pin the direction instead
                .environment(\.layoutDirection, .rightToLeft)
            
            if appLanguage != "ar" {
                Divider().background(Color.white.opacity(0.2))
                
                Text(AppTranslations.translate(dua.englishTranslation, to: appLanguage))
                    .font(.custom("AvenirNext-Medium", size: 16))
                    .foregroundColor(.white.opacity(0.9))
                    .lineSpacing(4)
            }
            
            HStack {
                Spacer()
                Text(AppTranslations.translate(dua.reference, to: appLanguage))
                    .font(.caption)
                    .foregroundColor(.teal)
                    .padding(.top, 5)
            }
        }
        .padding(20)
        .background(Material.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}
