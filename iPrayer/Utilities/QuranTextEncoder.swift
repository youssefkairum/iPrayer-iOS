//
//  QuranTextEncoder.swift
//  iPrayer
//
//  The bundled verse text uses the Tanzil Uthmani encoding, while the bundled KFGQPC Hafs font
//  expects KFGQPC's own encoding for several recitation signs. Fed the Tanzil codepoints, the font
//  draws placeholder blobs, which is why the reader used to delete more than 15,000 marks.
//
//  This re-encodes those signs for DISPLAY ONLY. Letters are never touched, the source file is
//  unchanged, and copy/share/search keep using the standard text.
//
//  Verified by shaping all 6,236 verses with the font: no placeholder glyphs, no fallback fonts.
//

import Foundation

nonisolated enum QuranTextEncoder {
    
    /// Verse text ready to be drawn with the KFGQPC Hafs font.
    static func displayText(from raw: String) -> String {
        let scalars = Array(raw.unicodeScalars)
        var out = String.UnicodeScalarView()
        out.reserveCapacity(scalars.count)
        
        func put(_ values: UInt32...) { for v in values { out.append(UnicodeScalar(v)!) } }
        
        var i = 0
        while i < scalars.count {
            let current = scalars[i].value
            let next = i + 1 < scalars.count ? scalars[i + 1].value : 0
            
            // Tanween followed by a small meem. Tanzil marks the "open" (successive) tanween with a meem on
            // the opposite side of the vowel, and iqlab with a meem on the same side.
            switch (current, next) {
            case (0x064B, 0x06ED): put(0x0657); i += 2; continue        // open fathatan
            case (0x064C, 0x06ED): put(0x065E); i += 2; continue        // open dammatan
            case (0x064D, 0x06E2): put(0x0656); i += 2; continue        // open kasratan
            case (0x064B, 0x06E2): put(0x064E, 0x06E2); i += 2; continue // iqlab: fatha + small meem
            case (0x064C, 0x06E2): put(0x064F, 0x06E2); i += 2; continue // iqlab: damma + small meem
            case (0x064D, 0x06ED):
                // iqlab with kasra. The font has no small LOW meem (it draws a blob), so the small high
                // meem keeps the sign visible; only its position differs from the printed mushaf.
                put(0x0650, 0x06E2); i += 2; continue
            default: break
            }
            
            switch current {
            case 0xFEFF, 0x06DD:
                break                                   // byte-order mark; end-of-ayah sign (the reader draws its own)
            case 0x06E3:
                break                                   // small low seen (52:37 only): not in this font
            case 0x0652: put(0x06E1)                    // sukun is the "head of khah" shape in this font
            case 0x06DF: put(0x0652)                    // small round zero marking a silent letter
            case 0x06EA: put(0x065C)                    // imala dot below (11:41)
            case 0x06EB: put(0x06EC)                    // ishmam (12:11)
            case 0x0020 where (0x06D6...0x06DC).contains(next):
                break                                   // pause marks stand alone after a space in the source;
                                                        // dropping it attaches the mark to the word it follows
            default:
                out.append(scalars[i])
            }
            i += 1
        }
        return String(out)
    }
    
    /// Every surah except Al-Fatiha (1) and At-Tawba (9) carries the basmala at the start of verse 1, and the
    /// reader shows it as a header. Surahs 95 and 97 spell it with an extra shadda, so a plain prefix match
    /// missed them and showed it twice. Dropping the first four words is exact for all 112.
    static func removingBasmala(from text: String, surah: Int, numberInSurah: Int) -> String {
        guard numberInSurah == 1, surah != 1, surah != 9 else { return text }
        let words = text.split(separator: " ", omittingEmptySubsequences: true)
        guard words.count > 4 else { return text }
        return words.dropFirst(4).joined(separator: " ")
    }
    
    /// Western digits to Arabic-Indic. The KFGQPC font draws these as complete verse-number ornaments.
    static func arabicDigits(_ number: Int) -> String {
        String(String(number).unicodeScalars.map { scalar -> Character in
            guard scalar.value >= 0x30, scalar.value <= 0x39 else { return Character(scalar) }
            return Character(UnicodeScalar(scalar.value - 0x30 + 0x0660)!)
        })
    }
    
    // MARK: - Search
    
    /// Folds text for matching: strips vowel and recitation marks and unifies letter variants.
    /// `daggerAlefAsAlef` turns the superscript alef into a full alef, which is how modern spelling
    /// writes many Uthmani words (الكتٰب / الكتاب). Verses are indexed both ways.
    static func searchKey(_ text: String, daggerAlefAsAlef: Bool = false) -> String {
        var out = String.UnicodeScalarView()
        for scalar in text.lowercased().unicodeScalars {
            switch scalar.value {
            case 0x0670:
                if daggerAlefAsAlef { out.append(UnicodeScalar(0x0627 as UInt32)!) }
            case 0x064B...0x065F, 0x06D6...0x06ED, 0x0640, 0xFEFF, 0x08F0...0x08FF:
                break
            case 0x0623, 0x0625, 0x0622, 0x0671: out.append(UnicodeScalar(0x0627 as UInt32)!)  // alef forms
            case 0x0649: out.append(UnicodeScalar(0x064A as UInt32)!)                          // alef maqsura -> yeh
            case 0x0629: out.append(UnicodeScalar(0x0647 as UInt32)!)                          // teh marbuta -> heh
            default: out.append(scalar)
            }
        }
        return String(out).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
