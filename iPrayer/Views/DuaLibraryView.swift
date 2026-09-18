import SwiftUI

/// Every dua in the library, filterable by category and searchable, with copy and share on each card.
/// Opened from the Home card with `highlightID` set, it scrolls to that dua and marks it.
struct DuaLibraryView: View {
    var highlightID: String? = nil
    
    @Environment(\.dismiss) private var dismiss
    @AppStorage(UDKey.appLanguage.rawValue) private var appLanguage: String = "en"
    private let data = DuaLibraryData.shared
    
    @State private var selectedCategory: String? = nil   // nil = all
    @State private var query = ""
    @State private var highlighted: String? = nil
    
    private var isArabic: Bool { appLanguage == "ar" }
    
    /// Categories that still have something to show after the search
    private var visibleCategories: [String] {
        data.categories.filter { category in
            (selectedCategory == nil || selectedCategory == category) && !filteredDuas(in: category).isEmpty
        }
    }
    
    private func filteredDuas(in category: String) -> [AuthenticDua] {
        let duas = data.duas(for: category)
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return duas }
        let folded = QuranTextEncoder.searchKey(needle)
        return duas.filter { dua in
            QuranTextEncoder.searchKey(dua.arabicText).contains(folded)
                || dua.englishTranslation.localizedCaseInsensitiveContains(needle)
                || AppTranslations.translate(dua.englishTranslation, to: appLanguage).localizedCaseInsensitiveContains(needle)
                || AppTranslations.translate(category, to: appLanguage).localizedCaseInsensitiveContains(needle)
        }
    }
    
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color(hex: "0F2027"), Color(hex: "203A43"), Color(hex: "2C5364")]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)
            
            VStack(alignment: .leading, spacing: 0) {
                header
                searchField
                categoryChips
                
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 14, pinnedViews: []) {
                            if visibleCategories.isEmpty {
                                Text(AppTranslations.translate("No results found", to: appLanguage))
                                    .font(.custom("AvenirNext-Medium", size: 15))
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 40)
                            }
                            
                            ForEach(visibleCategories, id: \.self) { category in
                                let duas = filteredDuas(in: category)
                                HStack(spacing: 8) {
                                    Text(AppTranslations.translate(category, to: appLanguage))
                                        .font(.custom("AvenirNext-Bold", size: 20))
                                        .foregroundColor(.teal)
                                    Text("\(duas.count)")
                                        .font(.custom("AvenirNext-DemiBold", size: 12))
                                        .foregroundColor(.teal)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 2)
                                        .background(Color.teal.opacity(0.15))
                                        .clipShape(Capsule())
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 6)
                                
                                ForEach(duas) { dua in
                                    DuaCardView(dua: dua, appLanguage: appLanguage, isHighlighted: highlighted == dua.id)
                                        .id(dua.id)
                                }
                            }
                        }
                        .padding(.top, 12)
                        .padding(.bottom, 40)
                    }
                    .onAppear {
                        guard let highlightID else { return }
                        highlighted = highlightID
                        // Let the list lay out before jumping to the day's dua
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                proxy.scrollTo(highlightID, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
    }
    
    // MARK: - Pieces
    
    private var header: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            Text(AppTranslations.translate("Duas Library", to: appLanguage))
                .font(.custom("AvenirNext-Bold", size: 28))
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
    
    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField(AppTranslations.translate("Search duas", to: appLanguage), text: $query)
                .font(.custom("AvenirNext-Medium", size: 15))
                .foregroundColor(.white)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }
    
    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            // Liquid Glass: the container lets neighbouring chips blend as they pass each other
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    chip(title: AppTranslations.translate("All", to: appLanguage), selected: selectedCategory == nil) {
                        selectedCategory = nil
                    }
                    ForEach(data.categories, id: \.self) { category in
                        chip(title: AppTranslations.translate(category, to: appLanguage), selected: selectedCategory == category) {
                            selectedCategory = selectedCategory == category ? nil : category
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 6)
        }
        .padding(.top, 6)
    }
    
    private func chip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { action() }
        } label: {
            Text(title)
                .font(.custom("AvenirNext-DemiBold", size: 13))
                .foregroundColor(selected ? .black : .white)
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .glassEffect(selected ? .regular.tint(.teal).interactive() : .regular.interactive(), in: .capsule)
        }
    }
}

struct DuaCardView: View {
    let dua: AuthenticDua
    let appLanguage: String
    var isHighlighted = false
    
    @State private var copied = false
    
    private var shareText: String {
        var lines = [dua.arabicText]
        if let evening = dua.eveningText {
            lines.append("\(AppTranslations.translate("In the evening", to: appLanguage)): \(evening)")
        }
        if appLanguage != "ar" { lines.append(AppTranslations.translate(dua.englishTranslation, to: appLanguage)) }
        lines.append("[\(AppTranslations.translate(dua.reference, to: appLanguage))]")
        return lines.joined(separator: "\n")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(dua.displayArabic)
                .font(.custom("KFGQPC Uthmanic Script HAFS", size: 23))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineSpacing(9)
                // "trailing" means left once the app itself is right-to-left, so pin the direction instead
                .environment(\.layoutDirection, .rightToLeft)
            
            if let evening = dua.displayEvening {
                VStack(alignment: .leading, spacing: 6) {
                    Text(AppTranslations.translate("In the evening", to: appLanguage))
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.gray)
                    Text(evening)
                        .font(.custom("KFGQPC Uthmanic Script HAFS", size: 19))
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineSpacing(7)
                        .environment(\.layoutDirection, .rightToLeft)
                }
            }
            
            if appLanguage != "ar" {
                Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
                
                Text(AppTranslations.translate(dua.englishTranslation, to: appLanguage))
                    .font(.custom("AvenirNext-Medium", size: 15))
                    .foregroundColor(.white.opacity(0.9))
                    .lineSpacing(3)
            }
            
            HStack(spacing: 10) {
                Text(AppTranslations.translate(dua.reference, to: appLanguage))
                    .font(.caption)
                    .foregroundColor(.teal)
                    .lineLimit(1)
                
                if let count = dua.repeatCount {
                    Text("×\(count)")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.black)
                        .fixedSize()
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.teal)
                        .clipShape(Capsule())
                        .layoutPriority(1)
                }
                
                Spacer(minLength: 4)
                
                Button {
                    UIPasteboard.general.string = shareText
                    Haptics.tap()
                    withAnimation { copied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { copied = false }
                    }
                } label: {
                    Label(AppTranslations.translate(copied ? "Copied" : "Copy", to: appLanguage),
                          systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(copied ? .green : .teal)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .glassEffect(.regular.interactive(), in: .capsule)
                }
                .buttonStyle(.plain)
                .layoutPriority(1)
                
                ShareLink(item: shareText) {
                    Label(AppTranslations.translate("Share", to: appLanguage), systemImage: "square.and.arrow.up")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.teal)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .glassEffect(.regular.interactive(), in: .capsule)
                }
                .buttonStyle(.plain)
                .layoutPriority(1)
            }
        }
        .padding(18)
        .background(Material.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isHighlighted ? Color.teal.opacity(0.8) : Color.white.opacity(0.1), lineWidth: isHighlighted ? 1.5 : 1)
        )
        .shadow(color: isHighlighted ? .teal.opacity(0.25) : .clear, radius: 12)
        .padding(.horizontal, 20)
    }
}
