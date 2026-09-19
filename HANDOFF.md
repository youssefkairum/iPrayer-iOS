# iPrayer — Handoff Notes

Written 18 September 2026; updated 19 September 2026 after the post-release round (PRs #7 to #14). This is the context a future session
needs that is *not* obvious from the code: where things stand, why decisions were made, how to test,
and what is still open. The README describes the product; this describes the work.

---

## 1. Where things stand

- **Version:** 1.1.0, build 3 (App Store has 1.0). Deployment target iOS 26.0, Xcode 27, Swift 6.2 mode with
  `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and approachable concurrency on the app target.
- **Repo:** `youssefkairum/iPrayer-iOS` on GitHub (renamed from `iPrayer`; the local remote points at the
  new name). `gh` is logged in as `youssefkairum` (a second account, `brentwelldigital`, is also present).
  `gh` lives in `~/.local/bin`, which `~/.zshrc` now adds to PATH.
- **Merged to `main`:** PR #1 (reorganisation + first bug pass), PR #2 (up to the Quran reader rebuild + README),
  PR #3 (project file ordering), PR #4 (Home card shows the following day), PR #5 (the whole 1.1.0 feature
  branch: recitation + downloads + storage manager, Verse of the Day + widgets, Dua library, What's New,
  compact About/Settings, one-screen Home, motion + haptics, Arabic reader labels, privacy manifests),
  PR #6 (Apple Watch companion + complications + two-way sync). The watch targets were written straight
  into project.pbxproj (ids `B7A1C1..`); shared into the watch by explicit file reference: SharedPrayerSchedule,
  AppTranslations, HomeWidgetsData, UserDefaultsKeys, SharedWatchState. Phone side: PhoneWatchSync.swift.
- **Also merged (19 September 2026), via the umbrella PR #15:** #7 tracker day reset + iPad reader viewport fill ·
  #8 onboarding overhaul (one scaffold, animated slides, fixed-height controls, honest sync copy, catalog
  "Skip for now", fresh installs start in the phone's language) · #9 Tasbih overhaul (dhikr chips, target chips,
  cycle position, reset confirmation) · #10 Qibla overhaul (glass dial + rose, needle, turn guidance, distance)
  · #11 translated copyright line (RTL-ordered) · #12 Today's Prayers widget + What's New rebuilt in four
  sections · #13 Settings card when a paired watch lacks the app · #14 watch production hardening (background
  location refresh, city + Hijri + "then" line, container backgrounds, Crown counting, complication relevance).
  **`main` is the complete state; no branch is open, no PR is pending; all feature branches were deleted.**
- Conventions that held up: one branch per change cut from `main`; the translation table
  (AppTranslations.swift) is the usual conflict point, resolved by keeping both sides then checking for
  duplicate keys (a duplicate dictionary literal key crashes at runtime); Xcode re-extracts the String Catalog on
  every build and leaves it modified, discard that unless a commit means to include it.
- **19 September 2026, later:** PR #16 (`account-deletion`, MERGED to `main`, branch deleted) carried the release:
  the App Store account-deletion flow (section 6), build number 4, the README licence made consistent (all rights
  reserved; the MIT claim and the missing LICENSE file are gone), `docs/AppStoreRelease.md` (submission checklist,
  release notes, review notes, privacy answers, a draft rights email to EveryAyah) and `docs/screenshots/` (iPhone
  6.9" and iPad 13", five screens each, simulator captures). Release configuration builds clean.
  A Release archive of `main` (1.1.0 build 4, widget + watch app + complication embedded, development-signed; Xcode
  re-signs for distribution on upload) was built with `xcodebuild archive` and filed in
  `~/Library/Developer/Xcode/Archives/2026-09-19/iPrayer 1.1.0 (4).xcarchive`, so Organizer can upload it directly.
  **Next (owner only): Organizer > Distribute App (or re-archive), paste `docs/AppStoreRelease.md` into App Store
  Connect with `docs/screenshots/`, submit; device pass in section 6; the EveryAyah email.**

## 2. Map of the code

```
iPrayer/
  iPrayerApp.swift            root: permissions timing, What's New trigger, midnight refresh, window scheme
  SharedPrayerSchedule.swift  compiled into BOTH targets: prayer calc params, day schedule, PrayerPalette
  SharedVerseOfTheDay.swift   compiled into BOTH targets: the 31-day verse schedule the app writes for the widget
  PrayerAttributes.swift      Live Activity state (nonisolated), also in the widget target
  Views/
    ContentView.swift         custom floating tab bar (Liquid Glass); visited tabs kept alive, compass excluded
    PrayerListView.swift      Home: date line + location pill, one-line greeting, hero card, tracker + Dua of the Day,
                              Tomorrow strip (coloured symbols, time, AM/PM), Verse of the Day; entrance stagger
    QuranView.swift           surah list, pinned search (names + verse text), bookmarks, Continue Reading
    SurahDetailView.swift     reader screen: text size/theme/reciter/download menu, verse action bar, playback bar
    MushafTextView.swift      UITextView-based reader: page-by-page loading, highlights, resume, auto-follow
    OnboardingView.swift      one scaffold (progress capsules, language menu, fixed-height controls that crossfade)
                              + 4 slides that animate in once; fresh installs start in the phone's language
    WhatsNewView.swift        four sections (Quran / Every day / Everywhere / Look and feel), prayer-coloured
                              tiles, contentVersion gate; `-debugShowWhatsNew 1` forces it
    TasbihView.swift          Dhikr chips (6 phrases, `tasbihDhikr` key), target chips, position-in-cycle count,
                              whole band taps, reset confirmation
    QiblaCompassView.swift    glass dial + 72-tick rose, needle to the Kaaba, turn guidance card, distance from
                              SharedPrayerConfig coords in device units, no-location card
    HomeWidgets.swift         streak/tracker card, Dua of the Day card, Verse of the Day card (2-line cap)
    DuaLibraryView.swift      search + category chips (Liquid Glass), cards with copy/share, repeat badge, evening text
    AudioStorageView.swift    downloaded-audio manager: per reciter / per surah sizes and deletion
    AboutView.swift           fits one screen; acknowledgements as provider name + subtitle
    SettingsView.swift        Account, Prayer Calculation, Notifications, Quran Audio, General (language + about)
    Motion.swift              AppEntrance flag, CardPressStyle, .entrance(index:shown:) stagger
    SettingsView.swift        + Apple Watch card (only when PhoneWatchSync says paired && !installed)
    PrayerTheme.swift         PrayerTheme (reads PrayerPalette) + AppAppearance (status-bar scheme flip)
  ViewModels/PrayerViewModel  location, Adhan calc, notifications (7 days + pre-prayer), widget config, Live Activity
  Managers/
    QuranDataCache.swift      actor: slim JSON decode, display re-encoding, verse search, Verse-of-the-Day pool
    QuranAudioPlayer.swift    AVQueuePlayer per-verse streaming/local, prefetch, session mgmt, failure handling
    QuranAudioDownloads.swift per-surah ZIP download (fallback per verse), backup-excluded storage
    QuranBookmarks.swift      bookmarks store (JSON in UserDefaults, iCloud-synced)
    VerseOfTheDay.swift       date-based pick, refreshes on day change / foreground; shares 31 days with the widget
    CloudSyncManager.swift    NSUbiquitousKeyValueStore sync incl. tracker/streak with date-guarded merge
    AccountManager.swift      Sign in with Apple, credential-revocation check, shared sign-in handler
    NotificationManager.swift daily Quran reminders (in-app language)
  Utilities/
    QuranTextEncoder.swift    Tanzil→KFGQPC display re-encoding, basmala removal, Arabic digits, search folding
    AppTranslations.swift     in-app translation table (9 languages) + catalogString(...) for xcstrings keys
    ZipArchive.swift          minimal ZIP reader (stored + deflate, CRC-checked)
    Haptics.swift             tap / soft / rigid / selection / success / warning, used everywhere
    DeepLinks.swift           DeepLinkRouter: iprayer://verse/S/A -> Quran tab pushes the reader
  Models/DuaLibraryData.swift 50 duas with sources; duaOfTheDay(); displayArabic swaps the Arabic comma
    UserDefaultsKeys.swift    UDKey enum — every persisted key
  Localizable.xcstrings       String Catalog (Text literals); InfoPlist.xcstrings localises the location prompt
  quran-uthmani.json          Tanzil Uthmani text, slimmed to number/text/numberInSurah/page/juz (1.76 MB)
  adhan.caf                   IMA4 notification sound (mp3 is ignored by iOS)
  PrivacyInfo.xcprivacy       required-reason API declaration (UserDefaults, CA92.1 + 1C8F.1)
  SharedWatchState.swift      compiled into iPhone app + watch app: WatchSyncPayload (settings/location down,
                              Tasbih + tracker up) with the same date-guard rule as iCloud; Tasbih uses tasbihUpdatedAt
  Managers/PhoneWatchSync.swift  WCSession on the phone: updateApplicationContext down, applies wrist changes up
iPrayerWidget/                widget computes its own timeline with Adhan from SharedPrayerConfig; Live Activity UI
  TodayPrayersWidget.swift    systemMedium/Large: all six times, passed ticked/dimmed, next highlighted; entry per
                              prayer time, reload at midnight; computes with Adhan from SharedPrayerConfig
  VerseOfTheDayWidget.swift   systemMedium/Large + accessoryRectangular/Inline from SharedVerseSchedule; font is a
                              widget resource registered in iPrayerWidget/Info.plist (INFOPLIST_KEY_ form is NOT merged)
iPrayerWatch/                 watchOS app (min 10.0): WatchModel (one-shot fix on activation, 6-hourly background refresh
                              `iPrayerWatch.refresh`, ignores fixes that barely moved, reverse-geocoded city, Hijri date,
                              next + following prayer, Adhan via PrayerSchedule, writes SharedPrayerConfig for the
                              complications), WatchSync (WCSession), Views/WatchRootView (NavigationStack + vertical TabView
                              with per-page container backgrounds: next prayer, today, tracker) + WatchPages (Tasbih with
                              Digital Crown, Qibla with distance + no-compass state)
iPrayerWatchWidget/           NextPrayerComplication: accessoryCircular/Corner/Rectangular/Inline from SharedPrayerConfig,
                              with TimelineEntryRelevance so the Smart Stack surfaces it near prayer time
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
- **The reader runs on TextKit 2, and must stay there.** Reading `textView.layoutManager` anywhere silently drops a
  UITextView to TextKit 1, and TextKit 1's RTL justification draws the marks of each line's last word on top of the
  letter instead of above it (the "tashkeel overlap on the last word at the left" the owner saw on his phone). One
  `layoutManager.ensureLayout` call had been doing exactly that. TextKit 2 answers geometry questions about text it
  has not laid out yet with estimates (a verse 2,700 pt down was reported at 15,000 pt, and the reader scrolled into
  nothing), so `Coordinator.ensureFullLayout` lays the loaded text out before any `firstRect` measurement. Side
  effects of TextKit 2: justification spreads space between words instead of stretching letters, and the verse
  highlight is drawn per line fragment. Bold Text was investigated and ruled out: glyph positions are identical.
- **Reader line spacing is 0.7 em** (was 0.5). Measured with CoreText: the stacked pause marks the encoder attaches
  above a word reach 1.15 em above the baseline and the line above descends 0.5 em, so at large sizes they touched.
- **Two arrival marks in the reader** (`VerseMark`): `.destination` (gold) for a bookmark, search result or deep link,
  `.resume` (green, the recitation colour) for Continue Reading. Either clears when a verse is tapped.
- **References follow the app language everywhere**: bookmark and search rows use the reader's own rule (Arabic name
  and Arabic-Indic digits in Arabic, transliteration otherwise) and the Continue Reading headline leads with the
  Arabic name in Arabic.
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
- **Home fits one 6.1" screen with the tab bar.** The budget is tight (about 9 pt spare with a signed-in name):
  greeting on one line (name in the same Text, shrinks before it wraps), location pill on the date line,
  Tomorrow as one row, verse preview capped at two lines. Adding height anywhere on Home pushes the verse
  under the tab bar; the owner rejected a two-line greeting for exactly that reason.
- **Verse widget data.** The extension cannot read the 1.7 MB Quran, so the app writes the next 31 daily
  verses (font-encoded text + localised reference) to the App Group on every verse refresh and language
  change; the widget builds one entry per local day and asks again when the list runs out.
- **Deep link replaced the debug open path.** `iprayer://verse/S/A` and `-debugOpenSurah` both flow through
  DeepLinkRouter -> QuranView.openLinkedVerseIfPossible, which waits for the surah list to load.
- **Dua cards show a plain comma.** The KFGQPC font draws U+060C as a verse ornament (the circles seen on
  device); `displayArabic` swaps it for display only, copy/share keep the real text.
- **Watch computes its own times.** The watch asks for its own location (one-shot `requestLocation`, kilometre
  accuracy) and only uses the phone's coordinates from the sync payload while it has none of its own. Settings,
  language and translated names come from the phone; the watch never reads iCloud KVS (the phone only syncs
  KVS when signed in, and the KVS id is per bundle id, so WatchConnectivity is the one reliable channel).
- **Wrist changes win by date.** Tracker/streak use the same "newer yyyy-MM-dd wins" rule as CloudSyncManager;
  the Tasbih uses `tasbihUpdatedAt` (set wherever a person changes it) so the last touch wins on either side.
- **Tracker day rules (PR #7).** A saved tracker is adopted only if saved today; a new day starts from today's
  iCloud tracker when another device has one (never blanks over it); same-day ticks merge with OR and the
  streak keeps the larger count, on both the iCloud and the watch paths; the model observes the day change and
  foreground itself. The Tasbih uses `tasbihUpdatedAt`, last touch wins.
- **Fresh installs start in the phone's language.** `AppTranslations.preselectLanguageFromDeviceIfNeeded` runs
  in `iPrayerApp.init` after the update-vs-fresh decision. It reads the PERSISTED defaults domain because a
  registered "en" default makes `string(forKey:)` look chosen on a brand-new install.
- **Onboarding controls have a fixed height (104 pt) and crossfade**; slides animate in once and never out.
  Anything else made the features -> location page change feel rough.
- **"Sign in with Apple" text follows the device language** (Apple's button, no API). Not replaced with a custom
  button: review risk for little gain.
- **Copyright line** is built by `AppTranslations.copyrightLine`: RTL languages lead with the phrase, the
  Latin name+year sit in a first-strong isolate.
- **Tasbih changing the dhikr keeps the count** (people run one count across phrases).
- **Deployment target 26.0** for the iPhone app and widget; **watchOS 10.0** for the watch app and complications
  (nothing in them needs newer; Series 4/5 top out at watchOS 10). Everywhere else 26.0 (was 26.1/26.6/26.2). iPad is targeted and cannot be dropped.
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
e.g. `-lastSeenWhatsNewVersion 1.0.0`, `-hasSeenOnboarding YES`, `-appLanguage ar`, `-userName "Youssef Keram"`
(the last one shows the signed-in greeting without signing in).
Deep links: `xcrun simctl openurl <sim> "iprayer://verse/2/255"` (the simulator shows an "Open in iPrayer?"
confirmation first).
Fresh-install-in-Arabic test: `simctl uninstall`, install, then launch with
`-AppleLanguages "(ar)" -hasSeenOnboarding NO -installedAsUpdate NO` (the sim's already-granted location makes
the app think it is an update otherwise). `-tasbihCount 47` seeds the Tasbih. If `xcodebuild` says the build
database is locked, Xcode is building at the same time: wait and retry.

**Apple Watch:** no watchOS simulator runtime is installed on this Mac (`xcrun simctl list runtimes` shows none),
only the watchOS 27 SDK, so the watch targets BUILD (as part of the iPhone scheme) but have never RUN. Install a
watchOS runtime in Xcode > Settings > Components, pair a watch simulator with the iPhone 17 one, then run the
`iPrayerWatch` scheme (Xcode autocreates it). On a real watch, WatchConnectivity needs the phone app opened once.

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
- `simctl launch` needs `--terminate-running-process` and the argument string split by the shell (zsh: `${=A}`),
  otherwise the arguments are passed as one word and silently ignored. Give a fresh launch 30 s before a capture.
- Store captures on a freshly booted simulator: the first launches take 20 to 30 s to show anything, so wait 30 s
  per screen (12 s gave blank captures). `simctl privacy <sim> grant location <bundle>` works; `grant notifications`
  is refused, so tap Allow once through the Simulator tool. The iPad Pro 13-inch simulator ignored `-hasSeenOnboarding`
  style launch arguments entirely; `simctl spawn <sim> defaults write <bundle> key value` before launching works there.
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
prompt, What's New for update vs fresh install, Home layout with and without a signed-in name (incl. a long
name), Tomorrow strip, Dua of the Day card -> library scrolled to today's dua, Verse of the Day + tap-through,
reader open-at-verse with gold mark, selection with no scroll jump, text size + dark theme, next-surah
link, verse search incl. modern spelling, bookmarks, recitation start/follow/previous/switch-verse,
ZIP download of Al-Baqara (< 30 s), offline failure handling (via debug host), storage manager (single
surah, whole reciter incl. basmala cleanup), Arabic reader labels in the playback bar, Duas library
search/chips/badges/copy-share layout, deep link `iprayer://verse/2/255`, the 31-day shared verse
schedule in the App Group, the widget bundle carrying the font + UIAppFonts, splash -> Home hand-off
mid-entrance, Live Activity colours on the Lock Screen, Liquid Glass surfaces, iPad portrait (Home,
reader), string tables per language.
Verified on the owner's iPhone: storage manager (after the /private/var path fix), About and Duas library.

Verified by the owner: the Apple Watch app runs (the PR #6 version; #14 is build-verified only).
Verified on the simulator for the open PRs: onboarding (all four slides, English and Arabic, fresh install
in the phone's language, stable page change), Tasbih (seeded count), Qibla (Cairo bearing 136°), copyright
line in Arabic on the splash, What's New (Arabic), the iPad reader at 14 pt loading through page 8.

Not verified: PR #7's tracker fix across a real midnight on two devices (reasoned + built only) · the Today's
Prayers widget rendered anywhere · the watch complications on a watch face · the watch background refresh
actually firing · Crown sensitivity on the watch Tasbih · the Settings "install on watch" card (needs a paired
watch without the app) · WatchConnectivity round-trips (Tasbih/tracker both ways, settings down) · the watch on
watchOS 10 specifically · the Verse of the Day widget rendered on a Home Screen or Lock Screen · how the haptics
feel · iPad landscape · Dynamic Island appearance · Live Activity "Now" state · pre-prayer reminder firing ·
true Airplane-Mode playback of downloaded audio · two-device iCloud sync · real midnight rollover of
verse/dua/widget · audio *sound* · Lock Screen playback controls · the model-written translations in
Urdu/Hindi/Russian/Chinese (now including 39 duas and the onboarding, Tasbih, Qibla, What's New strings).

## 6. Open items

**Compliance / release**
- Account deletion (guideline 5.1.1 v): DONE (`account-deletion` branch): Settings > Account has "Sign out and
  delete my data" behind an alert; `AccountManager.deleteAccount` calls `CloudSyncManager.eraseCloudData` (removes
  every synced key from KVS, stops syncing) then `logout()`. On-device data is kept on purpose (deleting the app
  removes it). The Sign in with Apple grant cannot be revoked without a server (the REST revoke endpoint needs a
  client secret), so the alert points to Settings > Apple Account > Sign in with Apple. Verified on the simulator
  in English and Arabic (row, alert, signed-out card, cleared profile keys); the KVS erase is code-verified only,
  the simulator has no KVS file without a real sign-in.
- Audio rights: an email to EveryAyah is drafted in `docs/AppStoreRelease.md`, NOT sent; stay non-commercial.
- App Privacy label: "Data Not Collected" is defensible (nothing goes to developer servers).
- Onboarding copy: DONE in PR #8 (now "backups go to your own iCloud; iPrayer runs no servers").
- "Sign in with Apple" button text follows the DEVICE language (Apple's button; no API). A custom button with
  Apple's official translations is possible but adds review risk; left as is.
- Store screenshots and review notes: DONE in `docs/` (see above). The screenshots are raw simulator captures;
  add frames or captions if wanted. Not yet uploaded to App Store Connect.
- Licence: README now says all rights reserved (matching the in-app copyright line) with the bundled data's own
  licences pointed to; the MIT badge and LICENSE reference were removed. Switch to MIT later if wanted, but note the
  Tanzil text, KFGQPC font and EveryAyah audio could not be MIT anyway.
- Translations were written by the model: Arabic/French/German/Turkish confident; Urdu/Hindi/Russian/
  Chinese need a native read. This now includes 39 dua translations (7 languages each).
- Verse widget: confirm on a device that the KFGQPC font renders in both Home Screen sizes and the Lock
  Screen rectangular family; if not, fall back to the system font in the widget only.

**Features suggested, not built**
- Cache-as-you-listen (save streamed verses), background `URLSession` downloads, "download all",
  single-file-per-surah audio with the host's timing files (removes inter-verse gaps), mini player
  outside the reader, continuous play into the next surah, Quran translations (no data bundled),
  right-to-left tweaks beyond layout mirroring, native system `TabView` for the full Liquid Glass tab
  behaviour, reopen What's New from Settings > About, choosing the calculation method on the watch,
  local adhan notifications on the watch (phone notifications already mirror to it).

**Known cosmetic**
- What's New was rebuilt in PR #12; check the four sections at larger Dynamic Type once merged.
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
