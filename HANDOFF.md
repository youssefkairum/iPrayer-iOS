# iPrayer — Handoff Notes

Written 18 September 2026 at the end of a long working session. This is the context a future session
needs that is *not* obvious from the code: where things stand, why decisions were made, how to test,
and what is still open. The README describes the product; this describes the work.

---

## 1. Where things stand

- **Version:** 1.1.0, build 3 (App Store has 1.0). Deployment target iOS 26.0, Xcode 27, Swift 6.2 mode with
  `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and approachable concurrency on the app target.
- **Repo:** `youssefkairum/iPrayer-iOS` on GitHub (renamed from `iPrayer`; the local remote points at the
  new name). `gh` is logged in as `youssefkairum` (a second account, `brentwelldigital`, is also present).
  `gh` lives in `~/.local/bin`, which `~/.zshrc` now adds to PATH.
- **Merged:** PR #1 (reorganisation + first bug pass — merged by the author after its first two commits),
  PR #2 (everything up to the Quran reader rebuild + README), PR #3 (project file ordering).
- **Open:** PR #4 `home-card-following-day` → `main` (Home card shows the following day; catalog entries).
- **Uncommitted, on the `home-card-following-day` branch, all building with zero warnings:**
  prayer-colour palette shared with widget/Live Activity · What's New page · Liquid Glass · bookmark
  "you are here" highlight · update-detection fix for the What's New page · Verse of the Day from the
  whole Quran · Quran recitation (streaming) · offline audio downloads (ZIP) · audio source licence
  findings + in-app acknowledgements · playback bug fixes (previous, switch verse, scroll jump, offline
  runaway) · audio session off the main thread · next-surah link spacing · location purpose string +
  localisation · privacy manifests + export-compliance flag · downloaded-audio storage manager
  (Settings > Manage Downloads: per reciter, per surah, verified on device) · compact About + Settings
  (Language folded into General) · Home fits one screen (Tomorrow strip, Dua of the Day card, 2-line
  verse cap, one-line greeting) · app-wide motion + haptics (Haptics.swift, Motion.swift) · Dua library
  rebuilt (31 duas, search, category chips, copy/share, Home card deep-links to today's dua) · reader
  references follow the app language (Arabic name + digits) · Hisn al-Muslim morning/evening adhkar (50 duas
  total, repeat counts, evening variants) · Verse of the Day Home Screen widget (`iPrayerVerseWidget`: the app
  writes 31 days of verses to the App Group via SharedVerseOfTheDay.swift, compiled into both targets; the font
  is a widget resource registered in iPrayerWidget/Info.plist) · `iprayer://verse/S/A` deep link (DeepLinks.swift)
  handled in ContentView/QuranView, which also replaced the debug-only open-surah path. NOT verified: the widget
  rendered on a Home Screen (the simulator can't add one non-interactively); the deep link and the shared
  schedule were.
  **First job for the next session: commit this as separate commits, one per feature, then PR.**
  Do not lump it into PR #4 unreviewed.

## 2. Map of the code

```
iPrayer/
  iPrayerApp.swift            root: permissions timing, What's New trigger, midnight refresh, window scheme
  SharedPrayerSchedule.swift  compiled into BOTH targets: prayer calc params, day schedule, PrayerPalette
  PrayerAttributes.swift      Live Activity state (nonisolated), also in the widget target
  Views/
    ContentView.swift         custom floating tab bar (Liquid Glass); visited tabs kept alive, compass excluded
    PrayerListView.swift      Home: hero card, tracker, "Tomorrow" schedule card, Verse of the Day, location cards
    QuranView.swift           surah list, pinned search (names + verse text), bookmarks, Continue Reading
    SurahDetailView.swift     reader screen: text size/theme/reciter/download menu, verse action bar, playback bar
    MushafTextView.swift      UITextView-based reader: page-by-page loading, highlights, resume, auto-follow
    OnboardingView.swift      4 slides: welcome, features, location (asks permission), sign-in
    WhatsNewView.swift        one-line bullets; contentVersion gate
    HomeWidgets.swift         streak/tracker card, Duas card, Verse of the Day card
    PrayerTheme.swift         PrayerTheme (reads PrayerPalette) + AppAppearance (status-bar scheme flip)
  ViewModels/PrayerViewModel  location, Adhan calc, notifications (7 days + pre-prayer), widget config, Live Activity
  Managers/
    QuranDataCache.swift      actor: slim JSON decode, display re-encoding, verse search, Verse-of-the-Day pool
    QuranAudioPlayer.swift    AVQueuePlayer per-verse streaming/local, prefetch, session mgmt, failure handling
    QuranAudioDownloads.swift per-surah ZIP download (fallback per verse), backup-excluded storage
    QuranBookmarks.swift      bookmarks store (JSON in UserDefaults, iCloud-synced)
    VerseOfTheDay.swift       date-based pick, refreshes on day change / foreground
    CloudSyncManager.swift    NSUbiquitousKeyValueStore sync incl. tracker/streak with date-guarded merge
    AccountManager.swift      Sign in with Apple, credential-revocation check, shared sign-in handler
    NotificationManager.swift daily Quran reminders (in-app language)
  Utilities/
    QuranTextEncoder.swift    Tanzil→KFGQPC display re-encoding, basmala removal, Arabic digits, search folding
    AppTranslations.swift     in-app translation table (9 languages) + catalogString(...) for xcstrings keys
    ZipArchive.swift          minimal ZIP reader (stored + deflate, CRC-checked)
    UserDefaultsKeys.swift    UDKey enum — every persisted key
  Localizable.xcstrings       String Catalog (Text literals); InfoPlist.xcstrings localises the location prompt
  quran-uthmani.json          Tanzil Uthmani text, slimmed to number/text/numberInSurah/page/juz (1.76 MB)
  adhan.caf                   IMA4 notification sound (mp3 is ignored by iOS)
  PrivacyInfo.xcprivacy       required-reason API declaration (UserDefaults, CA92.1 + 1C8F.1)
iPrayerWidget/                widget computes its own timeline with Adhan from SharedPrayerConfig; Live Activity UI
```

Two localisation systems coexist: `Localizable.xcstrings` for `Text("literal")` and `AppTranslations`
for anything built as a `String`. `String(localized:)` follows the *device* language, so anything that
must follow the *in-app* language (notifications, some labels) goes through
`AppTranslations.catalogString` or `AppTranslations.translate`.

## 3. Decisions and why (don't relitigate without reading)

- **Quran text vs font.** The text is Tanzil Uthmani; the font is KFGQPC Hafs, which expects its own
  codepoints and draws placeholder blobs for five Tanzil ones. `QuranTextEncoder.displayText` re-encodes
  signs for display only (open tanween → U+0657/065E/0656, iqlab → vowel + U+06E2, sukun U+0652 → U+06E1,
  U+06DF → U+0652, imala U+06EA → U+065C, ishmam U+06EB → U+06EC, pause marks attached to previous word).
  Verified by shaping all 6,236 verses: zero placeholder glyphs, zero fallback fonts. Two compromises the
  font forces: kasra-iqlab uses the *high* small meem (99 places); the low seen of 52:37 is dropped (1 place).
  Letters are never touched; copy/share/search use the standard text. Surahs 95 & 97 spell the basmala
  with an extra shadda — verse 1 drops its first four words instead of prefix-matching.
- **Verse markers** are Arabic-Indic digits drawn by the font as ornaments (no bitmaps).
- **Reader layout** is one justified paragraph per Madani mushaf page (data has `page`), with page/juz footer.
- **Audio source:** EveryAyah (`https://everyayah.com/data/<reciter>/SSSAAA.mp3`; per-surah ZIPs at
  `<reciter>/zips/SSS.zip`, stored not deflated, containing `SSS000.mp3` = basmala). The live site has no
  terms; the archived 2013 About page states CC BY-NC 2.5 Canada and asks for **max two connections** per
  person — the app keeps to that (2 concurrent downloads; 1-item lookahead when streaming). Reciters'
  own rights are unverified. Keep the app free of ads/purchases; recommend emailing the host. In-app
  acknowledgements are in AboutView.
- **Widget** computes its own timeline (Adhan linked into the extension) from `SharedPrayerConfig` in the
  App Group; it no longer depends on entries the app writes.
- **Permissions:** location asked on an onboarding slide (or a Home card if skipped); notifications
  asked after onboarding once prayer times are visible. Never at launch.
- **What's New** shows once to updaters. Version 1.0 had *no* onboarding, so "finished onboarding" can't
  identify an updater; `installedAsUpdate` is decided once at first launch from an already-answered
  location prompt or existing settings.
- **Home card** shows the *following* day (tomorrow, or the day after once the hero card has moved to
  tomorrow after Isha) so it never duplicates the hero card's detail screen.
- **Liquid Glass** applied to the control layer only (tab bar, buttons, pills, bars). Content cards keep
  the blur material on purpose (HIG + performance).
- **Reader status bar:** the window scheme flips light while the paper theme is on screen
  (`AppAppearance`); app content is pinned dark. `statusBarHidden` and toolbarColorScheme alone did not work.
- **Deployment target 26.0** everywhere (was 26.1/26.6/26.2). iPad is targeted and cannot be dropped.
- **Deleted on purpose:** the seven-verse Verse-of-the-Day list, DuaWidget, dhikr counter, KaabaIcon
  catalog, unused API structs, `adhan.mp3`.

## 4. Building, running, testing

```bash
# Build (Debug, iPhone 17 simulator id 4C176C57-22AF-4DEA-8CBE-F0A635D5950B)
xcodebuild -project iPrayer.xcodeproj -scheme iPrayer -destination 'platform=iOS Simulator,id=4C176C57-22AF-4DEA-8CBE-F0A635D5950B' -configuration Debug build
# Install / launch / screenshot without Xcode
xcrun simctl install <sim> path/to/iPrayer.app
xcrun simctl location <sim> set 30.0444,31.2357          # Cairo; needed or Home stays on "Locating..."
xcrun simctl launch <sim> youssefkairum.iPrayer -debugInitialTab quran -debugOpenSurah 2 -debugOpenVerse 255
xcrun simctl io <sim> screenshot --type=png out.png       # captures no status bar / Dynamic Island layer
```

**Debug-only launch arguments** (compiled out of Release):
`-debugInitialTab quran|tasbih|qibla|settings` · `-debugOpenSurah N` · `-debugOpenVerse N` ·
`-debugOnboardingSlide N` · `-debugShowWhatsNew 1` · `-debugAudioBaseURL https://unreachable.invalid`
(fails every verse, to test offline handling). Any UserDefaults key can also be overridden for one run,
e.g. `-lastSeenWhatsNewVersion 1.0.0` or `-hasSeenOnboarding YES`.

**Simulator quirks learned the hard way**
- The iOS Simulator MCP tool (`attach`/`tap`/`swipe`/`text`) works, but each call takes ~25 s to return.
  Any "screenshot one second after the tap" is really 30 s later — test on long surahs, and correlate with
  `log show` timestamps instead of trusting screenshot timing. `screenshot`/`inspect`/`launch` in that
  tool are unreliable; use `simctl` for those.
- `simctl launch` sometimes drops launch arguments on the first launch after `simctl install`: launch
  once, terminate, launch again.
- `simctl spawn <sim> defaults write <bundle>` writes a domain the app *reads* but its own writes go to the
  container plist (`get_app_container … data`/Library/Preferences). Read state from the container plist.
- `simctl pbcopy` needs `LC_ALL=en_US.UTF-8` for Arabic.
- Runtime logs: `xcrun simctl spawn <sim> log show --last 60s --predicate 'process == "iPrayer"'`.
- No Simulator.app in Xcode 27 to drive with AppleScript.
- **Device vs simulator paths:** on a real iPhone `FileManager.enumerator(at:)` hands back URLs whose
  `/private/var` prefix differs from the root URL it was given. Never derive structure by counting path
  components from the root (it broke the download inventory on device while passing in the simulator);
  walk up from the file with `deletingLastPathComponent()` instead.

**Verification tooling in the scratchpad (recreate if needed):** a Swift CoreText script that shapes
every verse with the bundled font and counts placeholder glyphs / fallback fonts — rerun it if the
encoder or the font changes.

## 5. Verified vs not verified (as of this handoff)

Verified on the iPhone 17 simulator (screenshots + logs): every tab, onboarding incl. the real location
prompt, What's New for update vs fresh install, Home "Tomorrow" card, Verse of the Day + tap-through,
reader open-at-verse with gold mark, selection with no scroll jump, text size + dark theme, next-surah
link, verse search incl. modern spelling, bookmarks, recitation start/follow/previous/switch-verse,
ZIP download of Al-Baqara (< 30 s), offline failure handling (via debug host), Live Activity colours on
the Lock Screen, Liquid Glass surfaces, iPad portrait (Home, reader), string tables per language.

Not verified: iPad landscape · Dynamic Island appearance (capture can't show it) · Home Screen widget
on a real Home Screen · Live Activity "Now" state · pre-prayer reminder firing · true Airplane-Mode
playback of downloaded audio · two-device iCloud sync · real midnight rollover · audio *sound* (can't
hear the simulator; timings from the player log match file lengths) · Lock Screen playback controls.

## 6. Open items

**Compliance / release**
- Account deletion (guideline 5.1.1 v): sign-out keeps name/email in iCloud KVS by design; add
  "Sign out and delete my data" that also clears the iCloud keys.
- Audio rights: contact EveryAyah; stay non-commercial.
- App Privacy label: "Data Not Collected" is defensible (nothing goes to developer servers).
- Onboarding says "We never share your data" — soften (location goes to Apple geocoding, IP to audio host).
- New screenshots for the store; review notes pointing at recitation + audio background mode.
- README claims MIT and a LICENSE file; there is no LICENSE file and the README also says
  "All rights reserved" — author's call.
- Translations were written by the model: Arabic/French/German/Turkish confident; Urdu/Hindi/Russian/
  Chinese need a native read.

**Features suggested, not built**
- Cache-as-you-listen (save streamed verses), background `URLSession` downloads, "download all",
  single-file-per-surah audio with the host's timing files (removes inter-verse gaps), mini player
  outside the reader, continuous play into the next surah, Quran translations (no data bundled),
  right-to-left tweaks beyond layout mirroring, native system `TabView` for the full Liquid Glass tab
  behaviour, reopen What's New from Settings > About.

**Known cosmetic**
- Two What's New bullets wrap at default text size.
- Arabic hero card: the "at <time>" line is correct now (first-strong isolate); keep that pattern for any
  new interpolated time strings.

## 7. Data and licensing

- Quran text: Tanzil Project Uthmani text in the alquran.cloud JSON layout; verse text byte-identical
  to the original (only unused fields were removed). Tanzil requires attribution, no modification.
- Font: KFGQPC Uthmanic Script HAFS (family "KFGQPC Uthmanic Script HAFS", PostScript
  "KFGQPCUthmanicScriptHAFS"). Registered via UIAppFonts only — do not also register with CoreText.
- Audio: EveryAyah, see §3. Downloaded audio lives in Application Support/QuranAudio and is excluded
  from backups (Apple requires that for re-downloadable content).
- Prayer times: Adhan Swift (BatoulApps), linked into app and widget.
