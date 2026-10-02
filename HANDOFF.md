# iPrayer — Handoff Notes

Written 18 September 2026; updated 3 October 2026, after Siri (#32), the non-Gregorian calendar fix (#33)
and the language-consistency round (#34). Everything through PR #34 is merged to `main`. This is the context a future session
needs that is *not* obvious from the code: where things stand, why decisions were made, how to test,
and what is still open. The README describes the product; this describes the work.

---

## 1. Where things stand

- **Version:** 1.1.1, build 14 (App Store has 1.0; a 1.1.0 build 3 was uploaded on 18 September, see Archives). Deployment target iOS 26.0 (watchOS 10.0 on the watch
  targets), Xcode 27. The Swift 6.4 *toolchain*, but still the Swift 5 *language mode*
  (`SWIFT_VERSION = 5.0` in all eight configurations) — which is why the capture rule below is a warning
  and not yet an error. `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and approachable concurrency are on for
  the app target.
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
  release notes, review notes, privacy answers, a draft rights email to EveryAyah) and `docs/screenshots/` (since
  superseded, see below). Release configuration builds clean.
- **Swift 6 capture rule, now swept (#23).** A `[weak self]` capture is a MUTABLE variable, so a concurrently
  executing closure may not reference it: bind with `guard let self` BEFORE starting the `Task`, never inside.
  This bit three times in one round (the orientation observer, the debug compass timer, the remote-command
  handlers). All four targets are swept and a build with `SWIFT_STRICT_CONCURRENCY=complete` reports no
  captured-var diagnostics. It is a warning under the project's current settings and an error once the Swift 6
  language mode is on, so it does not break archives today.
- **20 September 2026, compass device round — MERGED (#22).** The first compass fix was verified only on the
  Simulator and failed on the owner's phone: silent haptics and still-laggy tracking. Causes and the rules that
  came out of it are the two §3 bullets on gating haptics and on shipping a readout. Build 7.
- **20 September 2026, bug and polish round — ALL MERGED to `main`.** PR #20: the tracker carrying yesterday's
  ticks into a new day, Continue Reading resuming one verse early, a stale Live Activity for the previous prayer
  staying on the Lock Screen. PR #21: the Qibla dial made rigid (one curve for rose and needle), detent haptics
  as the phone turns, and the animated background pattern rasterised (~12% CPU to ~5%). Build 6, archived at the time as
  `iPrayer 1.1.0 (6).xcarchive`; that archive, and the stale 4 and 5, have since been deleted. No branch or
  PR is open.
  The three §3 bullets on tracker ordering, the one-curve dial and the ratchet must not be undone.
- **20 September 2026:** the owner's post-release notes were fixed and merged: #17 splash → onboarding hand-off and
  reliable slide entrances, #18 Qibla heading accuracy, #19 reader (TextKit 2, line spacing, green resume mark,
  Arabic references). Build was bumped to 5 for that round. `main` is again the complete state with no open
  PR or branch.
- **20 September 2026, diagnostics removed — MERGED (#24).** The owner asked for the compass diagnostics
  UI to go and for the haptics to be simply on: the Compass Haptics toggle, the Test Haptic button, the
  `taptic engine / low power mode` line and the Compass Diagnostics toggle are gone, and with them
  `Haptics.testCompassPair()`, `Haptics.supportsHaptics` (the file's only `CoreHaptics` use), the
  compass's `diagnosticsLine` and both `UDKey` cases. The detent is now unconditional: `ratchet.begin`
  runs whenever the compass runs. Neither removed key was in a sync list and nothing iterates
  `UDKey.allCases`, so a stored `compassHapticsEnabled = false` is simply ignored and those users get
  their haptics back. Build 8, archived. See the two §3 bullets for what the readouts taught and for the
  ratchet's actual design.
- **20 September 2026, onboarding and watch round — MERGED (#25, #26).** #25 added a fifth onboarding
  step offering the Apple Watch install, shown only when a watch is paired and iPrayer is not on it, and
  fixed six shipped Arabic/Urdu strings whose paragraph flipped to left-to-right (§3). #26 gave the watch
  tracker the iPhone's rule — a prayer is only tickable once its time has passed — added the day-change
  refresh the watch was missing, and rebuilt the next-prayer "then" line as a single `Text`. Build 9,
  archived. Two §3 rules came out of it and must not be undone: the RTL first-strong isolate rule, and
  that watchOS mirrors GLYPHS if you set `\.layoutDirection`.
- **Screenshots (20 September 2026).** `docs/screenshots/` now holds 32 captures, replacing the earlier
  ten English-only ones: iPhone 6.9" (1320x2868, seven screens), iPad 13" (2064x2752, six screens) and Apple
  Watch 44mm (368x448, three screens), each in BOTH English and Arabic. Named
  `<device><size>-<en|ar>-<NN>-<screen>.png`. Captured on the simulator with debug launch arguments and a
  frozen 9:41 status bar; the streak, tracker and Tasbih counts are seeded so the cards are not empty.
  Two deliberate omissions: no onboarding Apple Watch step for iPad, because an iPad cannot pair
  a watch and that screen would be unreachable for anyone who saw it in the listing; and the watch has no
  Quran or Duas page to shoot. The 44mm watch was chosen over the Ultra because it gives 368x448, a size the
  App Store lists, where the Ultra gives 422x514.
- **20 September 2026, Arabic round — MERGED (#27, #28, #29).** Shooting App Store screenshots in BOTH
  languages found the Qibla dial MIRRORED in Arabic: the app-wide RTL layout flipped the rose, so E drew
  left and W right and the Kaaba marker pointed at the mirror image of the bearing. At Cairo's 136° that
  sent Arabic and Urdu users about 88° wrong, and it had shipped that way since RTL went in. #27 pinned
  `dial(size:)` to `.leftToRight` (§3) and added 32 screenshots. #28 replaced the Home tracker's hardcoded
  `F D A M I` with each prayer's icon, and fixed chip rows that opened at the LTR end in Arabic. #29 gave
  the watch the same compass harness the phone has. Build 10, archived.
- **20 September 2026, the last Arabic pass — MERGED (#31).** The Home greeting was built from an ENGLISH
  format string, so a Latin comma shipped in all eight languages; Arabic and Urdu want ، (U+060C) and
  Chinese ，(U+FF0C). The name is now isolated too. The ORDER was never wrong — the owner asked, and the
  answer is that a right-to-left line ENDS on the left, which is why the name sits there. Build 12.
- **2 October 2026, the non-Gregorian calendar round — MERGED (#33). BUILD 12 WAS NEVER UPLOADED AND MUST
  NOT BE.** Testing on a Simulator set to region Saudi Arabia, whose default
  calendar is Hijri, the app CRASHED AT LAUNCH. Every tester until then had a Gregorian device (Egypt).
  Three things were wrong on any phone whose calendar is Hijri, Persian, Japanese, Buddhist and so on, all
  three in build 12, the first two introduced since 1.0: (1) the day number behind the Dua and Verse of
  the Day went negative and the Home screen indexed an array with it — the crash; (2) NO adhan and NO
  pre-prayer reminder was ever delivered, silently, because the notification triggers carried Gregorian
  numbers with no calendar and iOS read them in the device's (§3); (3) the copyright line said © 1448.
  Fixed in #33, with the Today's Prayers widget's reload date on the night the clocks go forward, which the
  same audit turned up. Two things it found were NOT calendar bugs and were left for a separate change: #34, below.
  Build 13.
- **2 October 2026, Siri — MERGED (#32).** The owner asked for Siri
  "in the languages". Built as App Intents inside the app target: six shortcuts that need no setup (next
  prayer, a named prayer's time, Qibla bearing; open the compass, Continue Reading, Tasbih), spoken phrases
  in the seven app languages Siri has, titles and answers in all nine (§3 for what decides which language).
  `iprayer://open/<tab>` came with it. An adversarial review before the PR found three navigation bugs in
  the first version, all invisible on a cold launch, and two wrong answers around midnight (§3); all five
  are fixed and re-tested. Nobody has SPOKEN to it yet: that needs the owner's iPhone (§5, §6). Build 13.
- **2–3 October 2026, language consistency — MERGED (#34).** These are the two bugs the
  calendar audit found and left. Two places formatted with the DEVICE locale while the screen
  around them was in the in-app language: the Qibla tab's distance (an Arabic phone with the app in
  English showed "١٬٢٨٦ كم" on an English screen) and the watch's three clock times (with the app in
  Arabic the page said "5:30AM" beside a complication saying "5:30 ص"). Both fixed; the rule is in §3.
  Verifying it turned up two more things on the watch, fixed in the PR's second commit so it can be dropped
  on its own: the watch's Qibla page had the same distance fault, and the Today list split a passed
  prayer's time across two lines ("6:49A" / "M") in every language. On 3 October the owner asked for what
  that round had found to be fixed too, and it is, one commit each: the Qibla tab's bearing and turn lines
  read word-first in Arabic and Urdu (§3), and the watch's Today page no longer puts a tick on a passed
  prayer, which is what cut "Sunrise" to "Sun…" on the 40mm. A review before the merge (3 October) added
  three small things: the Qibla distance is rewritten when the language changes under a showing compass
  (iCloud, or a second iPad window), the watch clock uses the complication's DateFormatter so the two agree
  on the leading zero in the 24-hour languages ("06:49", not "6:49"), and a passed prayer on the watch's
  Today page tells VoiceOver "Passed" now that the tick is gone. Merged with the version bump: 1.1.1, build
  14, at the owner's choice of number. Five App Store screenshots go stale and the owner does not want them
  retaken (§6).
- **Archives.** Release archives are built with `xcodebuild archive` (widget + watch app + complication
  embedded, development-signed; Xcode re-signs for distribution on upload). Keep exactly ONE current: each
  new build's archive supersedes the last, and 4 through 11 were deleted in turn; build 12's, the one with
  the launch crash, was moved to the Trash on 2 October rather than deleted, and can be emptied; build
  13's followed it on 3 October. The CURRENT archive, and the only one to distribute, is
  `~/Library/Developer/Xcode/Archives/2026-10-03/iPrayer 1.1.1 (14).xcarchive`. An older 1.1.0 archive sits
  in `~/Library/Developer/Xcode/Archives/2026-09-18/` under Xcode's default name: it is BUILD 3, and its
  record says it was UPLOADED to App Store Connect on 18 September. (This file called it "pre-1.1.0" until
  an audit read its Info.plist on 2 October.) It predates everything since, the calendar fix included. App Store
  Connect itself was not checked; if it still lists build 3 when a build is attached, pick 14, never 3.
  The version became 1.1.1 with build 14 (3 October); `WhatsNewView.contentVersion` stays "1.1.0" on
  purpose, since that page describes the 1.1 release and a bug-fix number must not show it twice.
  **Next (owner only): try Siri on a real iPhone first (§6), then Organizer > Distribute App on that 1.1.1
  (14) archive, paste `docs/AppStoreRelease.md` and `docs/AppStoreListing.md` into App Store Connect with
  `docs/screenshots/`, attach build 14, and submit.
  The 20 September device pass (§5) predates Siri and the calendar fix. The other loose end is the EveryAyah
  rights email, drafted in `docs/AppStoreRelease.md` and not sent.**

## 2. Map of the code

```
iPrayer/
  iPrayerApp.swift            root: permissions timing, What's New trigger, midnight refresh, window scheme
  SharedPrayerSchedule.swift  compiled into BOTH targets: prayer calc params, day schedule, PrayerPalette
  SharedVerseOfTheDay.swift   compiled into BOTH targets: the 31-day verse schedule the app writes for the widget
  PrayerAttributes.swift      Live Activity state (nonisolated), also in the widget target
  Views/
    ContentView.swift         custom floating tab bar (Liquid Glass); visited tabs kept alive, compass excluded;
                              obeys DeepLinkRouter.pendingTab (Siri, iprayer://open/..) and rebuilds the stack
                              (navigationEpoch) so a pushed reader is popped first
    PrayerListView.swift      Home: date line + location pill, one-line greeting, hero card, tracker + Dua of the Day,
                              Tomorrow strip (coloured symbols, time, AM/PM), Verse of the Day; entrance stagger
    QuranView.swift           surah list, pinned search (names + verse text), bookmarks, Continue Reading
    SurahDetailView.swift     reader screen: text size/theme/reciter/download menu, verse action bar, playback bar
    MushafTextView.swift      UITextView-based reader: page-by-page loading, highlights, resume, auto-follow
    OnboardingView.swift      one scaffold (progress capsules, language menu, fixed-height controls that crossfade)
                              + 4 slides that animate in once, plus a conditional 5th (Apple Watch) at tag 3
                              which makes sign-in's tag computed, not fixed; fresh installs start in the
                              phone's language
    WhatsNewView.swift        four sections (Quran / Every day / Everywhere / Look and feel), prayer-coloured
                              tiles, contentVersion gate; `-debugShowWhatsNew 1` forces it
    TasbihView.swift          Dhikr chips (6 phrases, `tasbihDhikr` key), target chips, position-in-cycle count,
                              whole band taps, reset confirmation
    QiblaCompassView.swift    glass dial + 72-tick rose, needle to the Kaaba, turn guidance card, distance from
                              SharedPrayerConfig coords (app language, device's km or miles), no-location card
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
    DeepLinks.swift           DeepLinkRouter.open(tab, verse:): the ONE way in from outside. iprayer://verse/S/A
                              -> Quran tab pushes the reader; iprayer://open/<tab>; the Siri open-intents
    UserDefaultsKeys.swift    UDKey enum — every persisted key
  Intents/PrayerIntents.swift Siri / Shortcuts (App Intents, in the app, no extension, no entitlement): three
                              intents that ANSWER (next prayer, a named prayer, Qibla bearing), three that OPEN
                              (compass, Continue Reading, Tasbih), the AppShortcutsProvider with the phrases,
                              and `-debugSiriDialogs 1`
  Models/DuaLibraryData.swift 50 duas with sources; duaOfTheDay(); displayArabic swaps the Arabic comma
    HomeWidgetsData.swift     tracker + streak + the App Group payload the widgets and watch read
    QuranModel.swift          Surah / Ayah / SurahMetadata
  Localizable.xcstrings       String Catalog (Text literals); InfoPlist.xcstrings localises the location prompt
  AppShortcuts.xcstrings      what Siri LISTENS for: phrases per Siri language (7 of the 9; no Urdu, no Hindi)
  AppIntents.xcstrings        shortcut TITLES and what Siri SAYS, all nine languages (table "AppIntents")
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
- **Tracker ordering rules (bug round, 20 Sep 2026). Order matters on BOTH sync paths and this is the whole bug.**
  `checkAndResetTracker` must read `todaysTrackerFromCloud` BEFORE assigning `lastTrackerDateStr`: that setter
  publishes the new date to the App Group KVS and the watch synchronously, so the shared store would satisfy its
  own freshness guard while its array was still yesterday's, and yesterday's ticks came straight back as "today's
  progress from another device". `applyCloudValues` must likewise capture the local `lastTrackerDate` BEFORE its
  write loop, because `accepted` is walked in the caller's key order and the same-day OR-merge would otherwise be
  decided against a date it had just imported. `todaysTrackerFromCloud` also returns nil unless
  `CloudSyncManager.isSyncing`, since a signed-out device still holds whatever the last session left in the store.
  Signed out, none of this fires, which is why the simulator never caught it.
- **Reading position has three sources, not one.** The verse at the top of the screen (`verseAtTop`, probed INSIDE
  the first visible line, not in the 30 pt container inset, or it returns the line above), the verse the reader
  taps, and the verse being recited. Selection and recitation both record directly from SurahDetailView; the
  follow-the-recitation scroll reports the verse it moved to (`revealingVerse`) rather than measuring the top,
  because `reveal` deliberately parks that verse 90 pt down. A programmatic restore scroll sets
  `isRestoringPosition` and reports nothing at all: its own scroll events used to overwrite the saved bookmark
  with verse 1 while the view was still at the top.
- **One Live Activity, always.** ActivityKit ends an activity itself once it passes the active-duration cap (an
  Isha-to-Fajr gap does this nightly) and the system keeps DRAWING it for hours afterwards, frozen on that prayer.
  Such an activity is not `.active` or `.stale`, so it must be ended explicitly with `.immediate` before a new one
  is requested, or the previous prayer sits beside the current one. `pendingActivity` covers `Activity.activities`
  lagging behind a successful `request`.
- **Tracker day rules (PR #7).** A saved tracker is adopted only if saved today; a new day starts from today's
  iCloud tracker when another device has one (never blanks over it); same-day ticks merge with OR and the
  streak keeps the larger count, on both the iCloud and the watch paths; the model observes the day change and
  foreground itself. The Tasbih uses `tasbihUpdatedAt`, last touch wins.
- **Fresh installs start in the phone's language.** `AppTranslations.preselectLanguageFromDeviceIfNeeded` runs
  in `iPrayerApp.init` after the update-vs-fresh decision. It reads the PERSISTED defaults domain because a
  registered "en" default makes `string(forKey:)` look chosen on a brand-new install.
- **Onboarding controls have a fixed height (104 pt) and crossfade**; slides animate in once and never out.
  Anything else made the features -> location page change feel rough.
- **A right-to-left `layoutDirection` MIRRORS DRAWN GEOMETRY, not just text and rows.** This is the bug that
  shipped in the Qibla compass: the app sets `\.layoutDirection` to `.rightToLeft` for Arabic and Urdu
  (iPrayerApp.swift), and SwiftUI horizontally mirrored the whole dial — E drew on the left, W on the right,
  and the Kaaba marker pointed at the mirror image of the bearing. At Cairo's 136° that sent Arabic and Urdu
  users about 88° wrong, on the one screen whose whole job is to be correct about a direction. Fixed in #27
  by pinning `dial(size:)` to `.leftToRight`.
  MEASURED, not assumed: a marker at `.offset(y: -80).rotationEffect(.degrees(90))` lands at x=179.5 under
  LTR and x=19.5 under RTL in a 200-wide box, with y unchanged — a pure horizontal mirror, which maps a
  rotation of +θ to −θ. Pinning `.leftToRight` inside an RTL ancestor restores x=179.5 exactly, so it fixes
  rather than double-flips, and inside an LTR ancestor it is pixel-identical to doing nothing, so it cannot
  affect English.
  **The rule: anything whose meaning is its ANGLE must be pinned; anything whose meaning is reading order
  must not.** So the dial is pinned and the text around it is not. Cardinal points are facts about the world.
  Two places are pinned for this reason: the Qibla dial, and the Tasbih bead ring (TasbihView.swift, the two
  trimmed Circles with `.rotationEffect(.degrees(-90))`), which used to fill ANTI-clockwise in Arabic — the
  owner asked for it to match. A tally advances the same way whichever way the language reads. Each Circle
  carries the pin itself rather than being wrapped, so no layout moves, and the count in the middle is text
  and is left alone. SF Symbol turn arrows do NOT auto-flip, so "turn left" keeps a left-turning arrow.
- **An RTL string that opens with a Latin word flips the WHOLE paragraph to left-to-right.** Unicode bidi
  P2/P3 takes a paragraph's direction from its first STRONG character, skipping isolates — so
  `"iPrayer غير مثبّت..."` is laid out LTR and its clauses land in the wrong order on screen. This is the
  same trap App Store Connect sprang on the Arabic description, and it was live in the shipped app: the
  Apple Watch card's message and the Urdu location, "Tap to open" and "More in iCloud" strings all flipped.
  Fix: wrap Latin runs in a first-strong isolate, `\u{2068}…\u{2069}`, which is what the Home card's time
  and the copyright line already do. **Wrap a whole PHRASE in one isolate, never word by word** — separate
  isolates are placed as separate RTL units, so `⁨Liquid⁩ ⁨Glass⁩` renders "Glass Liquid".
  Check it by taking each `ar`/`ur` value's first strong character (skipping isolate runs) and flagging any
  that is `L`; ignore values that are entirely English, which are a missing translation, not a direction bug.
- **The onboarding's Apple Watch step ADDS and REMOVES itself asymmetrically (PR #25).** It appears only when a
  watch is paired and iPrayer is not on it — the same condition as the Settings card — which makes the
  step count 5 instead of 4 and pushes sign-in from tag 3 to tag 4. `WCSession` activates at launch and
  answers ASYNCHRONOUSLY, so the answer lands while onboarding is already on screen, and the two
  directions need opposite rules. ADDING may only happen while `currentTab < watchTab`, or someone
  reading the sign-in page would find a watch prompt in its place. REMOVING is always allowed, even with
  the step on screen, and clamps `currentTab`: it can only carry them forward onto sign-in, which is
  where the step was leading anyway.
  The trap underneath it: iOS installs an embedded watch app OVER THE AIR, and `isWatchAppInstalled` is
  false for the whole transfer. Read raw, the flag says "not installed" loudest for exactly the people
  who left automatic install ON and are about to have it — the opposite of who the step is for. So the
  positive must HOLD for `watchSettleSeconds` before it counts, while a correction is believed at once.
  Anything else keyed off an async capability check needs the same asymmetry.
- **Onboarding entrance timing (PR #17, merged).** The onboarding sits under the splash from launch, so
  its welcome slide used to play its entrance unseen and then "pop" when the splash faded. Now `AppEntrance.splashDismissed`
  is set when the splash starts fading, the welcome slide waits for it, and the onboarding settles in from 0.94 scale
  like the main app. Each slide also gates its entrance on an `appeared` state set one run-loop turn after its first
  render (`slideEntrance`): the paged TabView sometimes built the next page only at the moment of a fast Continue tap,
  with `shown` already true, so nothing changed and nothing animated.
- **"Sign in with Apple" text follows the device language** (Apple's button, no API). Not replaced with a custom
  button: review risk for little gain.
- **NEVER gate a haptic on sensor quality, and never trust a haptic tested only on the Simulator.** Shipping a
  `headingAccuracy <= 15` gate silenced BOTH the new detent and the `success()` chime that had worked for
  months: `CLHeading.headingAccuracy` sits at 20-35° indoors on a real iPhone, which is exactly where a Qibla
  compass is used. Two rounds of Simulator testing missed it because `-debugSpinCompass` hardcoded
  `headingAccuracy = 5` and a perfect 30 Hz metronome — the two inputs that keep every gate open. The harness
  now reports a deliberately poor 25° for that reason. A gate on a haptic has exactly one failure mode,
  silence, so gates fail OPEN or do not exist. The ratchet went from eleven ways to swallow a click to two.
  Second structural trap in the same code: a 0.25 s "stream gap" plus `headingFilter = 1` made it incapable of
  clicking below ~4°/s, which is slower than every final aim. `headingFilter` is now
  `kCLHeadingFilterNone`, which is also what lets a short spring track the wrist.
- **When a bug lives only on the owner's device, ship them a readout.** That is how #22 was diagnosed: a
  Test Haptic button, a `taptic engine / low power mode` line in Settings and an opt-in
  `acc · reads · clicks · taptic` line on the compass. Reads climbing with clicks at zero is our bug; both
  climbing with nothing felt is the phone (Low Power Mode alone silences every UIFeedbackGenerator AND caps
  ProMotion at 60 Hz, which reads as "sluggish and no haptics" from outside the app). **All of that shipped
  UI was removed once it had done its job** — the owner asked for it gone and the haptics to be simply on.
  Rebuild it the same way if a device-only haptics bug ever comes back; the history is in #22.
- **The compass ratchet (`Haptics.Ratchet`) is the app's only STREAMED haptic, and that is why it is a class.**
  The other sensations build a generator per call and throw it away, which is right for a press because the
  finger is already down and the engine's 50-100 ms cold ramp is masked. A stream cannot do that, so one
  generator is held for the life of the screen and re-`prepare()`d after each click. ONE notch size at every
  speed: 5°, which divides 360 so the lattice closes on itself. It is anchored on the QIBLA, not on north:
  `update(angle:)` is fed `qiblaDirection - currentHeading`, so notch 0 is the Qibla itself and a click
  always falls an exact multiple of 5° from it. That is the point — the one angle the detent must mark is
  the one it is measured from. It does NOT follow that clicks line up with the rose's 72 ticks: those are
  drawn on north and carried by `.rotationEffect(-currentHeading)`, so the two coincide only when the
  bearing is itself a multiple of 5 (Cairo is 136°, so every click lands 1° past a mark). A notch counts
  only after a WHOLE notch of travel from the last one, in
  either direction, which is wider than any hand tremor — necessary now that `headingFilter` is
  `kCLHeadingFilterNone` and readings arrive unfiltered. There are exactly two ways it can stay quiet: the
  dial has not crossed a notch, or the last click was under 90 ms ago. `success()` at the lock has hysteresis
  (enter 5°, release 8°) so it cannot re-fire on a heading sitting on the line. The earlier design — speed
  tiers, a stream-gap timer, a warm-up count, a mute window, a reversal dead zone and an accuracy gate —
  was removed in #22: between them they could swallow a click eleven different ways, and the compass felt
  dead. Nothing about the FEEL can be judged without a real iPhone; there is no Taptic Engine on the
  Simulator at all.
- **The compass dial is ONE object and must move on ONE curve.** The rose turns by `-currentHeading` and the
  needle by `qiblaDirection - currentHeading`; those differ by a constant, so the Kaaba tip sits exactly over the
  Qibla mark on the rose only while both use the same animation. They used to use two (an `easeInOut(0.2)` and a
  `spring(0.55, 0.65)`), so mid-turn the tip visibly detached from its own mark, which is what read as "sluggish".
  Both now use one critically damped `spring(response: 0.25, dampingFraction: 1)`: a spring is retargeted in
  flight and carries velocity into the next reading, where a timing curve restarts from a standstill 20 to 50
  times a second and never leaves its slow-in shoulder. The needle also takes the CONTINUOUS angle, never the
  wrapped `offset` (which is for the turn text only) — re-wrapping made it swing the long way round whenever the
  phone swept past the bearing opposite the Qibla.
- **`BackgroundPatternView` is expensive and is on six screens.** Its few hundred stroked shapes were re-stroked
  every frame for as long as the screen was open, because it rotates forever: measured at ~12% CPU sustained on
  the Qibla tab against 0% on tabs without it. `.drawingGroup()` rasterises it once and halves that, with no
  visible change. Anything else long-lived and animated on those screens pays the same tax, so measure before
  adding one. Note the radar sweep was measured and is NOT the cost.
- **Qibla heading accuracy (PR #18, merged).** The bearing is a great-circle computation (Adhan `Qibla`), exact
  for any location fix; all error is in the heading. True heading is preferred (declination-corrected; needs a location
  fix, which the app has), magnetic is the fallback. `headingOrientation` follows the device orientation while the
  compass is on (portrait-only headings put north 90° off on a sideways iPad). The delegate now allows iOS's figure-8
  calibration screen, only while the Qibla tab is showing. `headingAccuracy` is published; past 15° (or invalid) the
  status card asks for the figure 8. `currentHeading` is unwrapped (shortest signed change added each reading) so the
  dial never spins the long way through north; read it modulo 360. No magnetometer (Simulator) shows "Compass
  unavailable" with the bearing and distance kept. Only the fallback is simulator-verifiable; heading, calibration
  prompt and orientation need a device.
- **The in-app language and the device are TWO locales, and a formatted value has to say which one it
  takes.** `Locale.current`, a `MeasurementFormatter` or `DateFormatter` with no locale set, a bare
  `date.formatted(date:time:)` and `Text(date, style: .time)` all follow the DEVICE. On the phone the last
  one happens to be right, because iPrayerApp puts `\.locale` in the environment; the watch sets no such
  thing, so there it was wrong. The rule that every target now follows: WORDS, DIGITS and the CLOCK
  CONVENTION come from the app language (`Locale(identifier: appLanguage)`, or `model.language` on the
  watch — `WatchModel.clockStyle` is the one place the watch's time format lives), and the only thing taken
  from the device is the UNIT SYSTEM, which is a fact about where the person lives and not about what they
  read: `var c = Locale.Components(identifier: language); c.measurementSystem =
  Locale.current.measurementSystem`. Measured in a standalone script: device ar_SA + app en gives
  "1,235 km", device en_US + app ar gives "767 ميل". One consequence to know about rather than fix: a
  language-only locale decides 12 or 24 hour by the LANGUAGE (en and ar 12-hour, fr/de/tr/ru/zh 24-hour),
  so an English-language app on a 24-hour phone shows "9:15 PM". The phone, the widgets and the
  complication have always done that; the watch pages now match them instead of the device.
- **A `Text("\(word) \(number)")` literal is laid out LEFT-TO-RIGHT in Arabic and Urdu.** An interpolated
  literal is a `LocalizedStringKey`, not a `String`, and the Qibla tab's two lines built that way read
  number-first: "136° القبلة" and "53° · استدر يساراً". It shipped, and it sat in the committed Arabic
  screenshots unnoticed. Build the `String` first and show it with `Text(verbatim:)`, which takes its
  direction from its own first strong character, and put the number in a first-strong isolate
  (`\u{2068}136°\u{2069}`) or the degree sign lands on the wrong side of it. `Label` needs the
  `Label { Text(verbatim:) } icon: { }` form for the same reason. Observed on screen and fixed by the
  change; WHY the key lays out left-to-right was not isolated.
- **Copyright line** is built by `AppTranslations.copyrightLine`: RTL languages lead with the phrase, the
  Latin name+year sit in a first-strong isolate.
- **Tasbih changing the dhikr keeps the count** (people run one count across phrases).
- **Deployment target 26.0** for the iPhone app and widget; **watchOS 10.0** for the watch app and complications
  (nothing in them needs newer; Series 4/5 top out at watchOS 10). Everywhere else 26.0 (was 26.1/26.6/26.2). iPad is targeted and cannot be dropped.
- **`Calendar.current` is not Gregorian, and for a prayer app it often is not.** Region Saudi Arabia
  defaults to the Hijri (Umm al-Qura) calendar, Iran and Afghanistan to the Persian, Thailand to the
  Buddhist, and anyone can pick one in Settings. Two rules, each learned from a shipped-in-archive bug:
  (1) never take year/month/day from `Calendar.current` and hand them to anything that assumes Gregorian —
  Adhan, a Gregorian `Calendar`, a number shown as a year. Year 1448 read as Gregorian is five centuries
  before 1970; `SharedVerseSchedule.dayNumber` did exactly this, went negative, and a bare `%` on a negative
  number is a negative array index. (2) `calendar.dateComponents(_:from:)` does NOT stamp its result with
  the calendar, and `UNCalendarNotificationTrigger` resolves bare components in the DEVICE calendar: build
  them with `PrayerViewModel.triggerComponents(for:in:)`, which sets `.calendar`. The Daily Quran reminder
  is the one place that is right without it, because both its sides use `Calendar.current`. Day STAMPS
  (tracker, streak, iCloud, watch) were audited and are safe: Gregorian + `en_US_POSIX` + `yyyy-MM-dd`.
  Day arithmetic (`startOfDay`, adding days, `isDateInTomorrow`) is calendar-independent and fine anywhere;
  "now + 24 hours" is not a day, on two nights a year.
- **Siri: three settings decide three things, and none of them is the in-app language.** The PHRASES Siri
  listens for follow the SIRI language. The TITLES in Shortcuts and Spotlight follow the DEVICE language.
  The ANSWER is a `LocalizedStringResource` the SYSTEM resolves. So an answer is never built with
  `AppTranslations` (that would put in-app Urdu into a French Siri voice) and never carries a pre-formatted
  time: the prayer name is a nested resource and the time is `\(date, format:)`, so both land in the
  sentence's language and the user's own clock style. Siri has no Urdu and no Hindi: those two get titles and
  answers, and `AppShortcuts.xcstrings` has no phrases for them and cannot.
- **Siri's two catalogs each have one way to be wrong silently.** `AppShortcuts.xcstrings` must be the
  `stringSet` shape Xcode writes, keyed by each shortcut's FIRST Swift phrase (change one, change the other);
  every phrase carries `${applicationName}` exactly once and at most one parameter; Arabic phrases END with
  the app name so the line does not open on a Latin word. `AppIntents.xcstrings` keeps every key `manual`, or
  the next build marks them stale. The six prayer NAMES stay in `Localizable.xcstrings`: Siri's training step
  reads spoken parameter values from the default table only. Phrase validation is only trustworthy on a
  CLEAN build; an incremental one can skip it. The catalogs are now the source of truth and are edited by
  hand (they were first generated by a throwaway script that is not in the repo).
- **Siri answers with the NEXT occurrence, from days -1...+1, and names no day.** A day's Isha can fall
  after midnight (Bordeaux in June, 00:11), and where the civil date runs ahead of the sun (Apia) "today's"
  times all land tomorrow; with only 0...+1 "next prayer" skipped a prayer that had not happened yet. "When
  is Fajr" asked at night means tomorrow's, which differs by an hour on the night the clocks change, so the
  sentence is "Fajr is at 5:22 AM." with no "today" in any language. Next PRAYER skips Sunrise, as the
  notifications do; asked for by name, Sunrise is answered.
- **Coming in from outside is `DeepLinkRouter.open(tab, verse:)`, and it REPLACES the navigation stack.**
  ContentView bumps `navigationEpoch`, the stack's `.id`, so that a pushed reader is popped and the tab bar
  is back. Three things follow, each found by review and reproduced, none visible on a cold launch:
  (1) QuranView must NOT observe `router.pendingVerse` — the instance about to be thrown away fires first,
  takes the verse and pushes onto dead state, and a warm tap on the Verse of the Day widget lands on the
  surah list; the new instance's `openLinkedVerseIfPossible` is the only consumer (run from its `onAppear`, and again once its own surah list has loaded). (2) Do not bump when the compass is both
  showing and requested: rebuilt in place, the new view's `onAppear` runs BEFORE the old one's
  `onDisappear`, and the shared view model is left with the compass stopped. (3) `pendingTab` is cleared
  with `DispatchQueue.main.async`, because `@Published` publishes in willSet and a clear made inside the
  subscriber is overwritten when the assignment completes (a second iPad window then replays the tab).
- **Siri never WRITES.** "Mark Fajr as prayed" and "count one" were left out on purpose: a misheard phrase
  should not be able to change the tracker or a count. Add them only with a confirmation step.
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
`-debugOnboardingSlide N` · `-debugShowWhatsNew 1` · `-debugWatchStep 1` (forces onboarding's Apple Watch
step without a paired watch; the REAL condition is reachable on a Simulator too — see the Apple Watch note
below) · `-debugSpinCompass 1` (turns the compass at 30 Hz and
reports a deliberately POOR 25° accuracy, since the simulator has no magnetometer; change the timer interval
to rehearse a slow aim, which is the case that used to be silent) · `-debugHeadingAccuracy 5` (overrides
that 25°, for rehearsing a well-calibrated phone or for a screenshot, where the figure-8 prompt is not the
state worth showing; the DEFAULT stays 25 on purpose, see §3). `-debugSpinCompass 1` works on the WATCH
as well, where it both fakes the heading and satisfies `WatchModel.headingAvailable` — without it the
watch's Qibla page can only ever be seen in its "Compass unavailable" state, since no Simulator has a
magnetometer. Set it with `simctl spawn <watch> defaults write <bundle> debugSpinCompass -int 1` rather
than as a launch argument if you are going to be driving the app for a while: watchOS relaunches it, and
launch arguments do not survive that · `-debugAudioBaseURL https://unreachable.invalid`
(fails every verse, to test offline handling) · `-debugLogNotifications 1` (logs, for every prayer
notification as it is scheduled, the instant wanted and the instant iOS will actually fire it:
`[Notify] prayer_Fajr_1 wanted … fires …`; the two must match, and "NEVER" is what a Buddhist-calendar
device used to print) · `-debugSiriDialogs 1` (logs every Siri answer in all nine
languages, resolved as the system would, plus one line for what THIS device says with nothing forced; read
with `simctl spawn <sim> log show --last 1m --predicate 'process == "iPrayer" AND eventMessage CONTAINS "SiriDialog"'`). Any UserDefaults key can also be overridden for one run,
e.g. `-lastSeenWhatsNewVersion 1.0.0`, `-hasSeenOnboarding YES`, `-appLanguage ar`, `-userName "Youssef Keram"`
(the last one shows the signed-in greeting without signing in).
Deep links: `xcrun simctl openurl <sim> "iprayer://verse/2/255"` (the simulator shows an "Open in iPrayer?"
confirmation first).
Fresh-install-in-Arabic test: `simctl uninstall`, install, then launch with
`-AppleLanguages "(ar)" -hasSeenOnboarding NO -installedAsUpdate NO` (the sim's already-granted location makes
the app think it is an update otherwise). `-tasbihCount 47` seeds the Tasbih. If `xcodebuild` says the build
database is locked, Xcode is building at the same time: wait and retry.

**Apple Watch:** the watchOS 27.0 runtime IS installed and three pairs already exist — `xcrun simctl list pairs`
shows the iPhone 17 sim paired with an Apple Watch Ultra 4. (This paragraph used to say no runtime existed;
it was stale.) Run the `iPrayerWatch` scheme (Xcode autocreates it) with both booted. On a real watch,
WatchConnectivity needs the phone app opened once.
**Staging `paired && !installed`,** which the onboarding watch step and the Settings card both need: boot the
iPhone and its paired watch, then confirm the watch app is absent with
`xcrun simctl get_app_container <watch-udid> youssefkairum.iPrayer.watchkitapp app` (it errors when not
installed). That is the state a fresh simulator is already in, so the real branch — not just
`-debugWatchStep 1` — can be exercised.

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
- **A device language different from the app's, for one run:** add `-AppleLanguages "(ar-EG)" -AppleLocale
  ar_EG` to the launch arguments next to `-appLanguage en`. The location pill turning into "القاهرة" is the
  proof the device side took. The reverse is `-AppleLocale en_US -appLanguage ar`, which also gives miles.
  This changes the locale for that one process only; the Hijri test in §5 changes the whole simulator.
- **The watch's language, once it has ever been paired and synced, cannot be set with `defaults write`.**
  The phone's sync payload writes `appLanguage` into the watch app's CONTAINER plist, and that wins over
  the simulator-level domain `simctl spawn <watch> defaults write` reaches. Drive it the real way: with
  both simulators booted, launch the PHONE app with `-appLanguage ar`, then relaunch the watch app, and
  confirm with `plutil -p $(xcrun simctl get_app_container <watch> youssefkairum.iPrayer.watchkitapp
  data)/Library/Preferences/youssefkairum.iPrayer.watchkitapp.plist`. The phone pushes whatever language
  it was LAST launched in, so an English phone run silently turns the watch back. A watch that has never
  synced (an unpaired 40mm, say) does take the `defaults write`.
- The watch's Today and Tracker pages are Lists, and a List swallows the page swipe until it has scrolled
  to its end: from launch, the Qibla page is six upward swipes away, not four. The Simulator tool's
  `swipe` works on a watch UDID.
- `simctl io <sim> screenshot` has been unable to write into the repo; capture to a temp folder.
- `simctl launch` needs `--terminate-running-process` and the argument string split by the shell (zsh: `${=A}`),
  otherwise the arguments are passed as one word and silently ignored. Give a fresh launch 30 s before a capture.
- **Fresh-install tests: run `simctl spawn <sim> defaults delete <bundle>` first.** That simulator-level domain
  (written by an earlier `defaults write`) survives `simctl uninstall` and the app reads it; a stale
  `hasSeenOnboarding = 1` there sent every "fresh" install to Home + What's New and launch-argument overrides were
  dropped on top. After deleting it, uninstall + `privacy reset all` + install shows onboarding with no arguments.
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
encoder or the font changes. And a Python bidi audit over `AppTranslations.swift` that reports every `ar`
and `ur` value whose first strong character is left-to-right (see the §3 rule) — rerun it whenever a
translation is added, because the failure is invisible until someone who reads the language looks at it.

## 5. Verified vs not verified (as of 2 October 2026)

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
Verified on the simulator for #17 to #19: onboarding (all four slides, English and Arabic, fresh install
in the phone's language, stable page change), Tasbih (seeded count), Qibla (Cairo bearing 136°), copyright
line in Arabic on the splash, What's New (Arabic), the iPad reader at 14 pt loading through page 8.

Verified for #20 to #23 (20 September 2026): the owner confirmed on their own iPhone that the compass detent
ratchet and the alignment chime both fire and that the dial tracks without lag — on the second attempt; the
first fix was Simulator-verified only and was silent on the phone (§3). The tracker day reset, the Continue
Reading position and the duplicate Live Activity were fixed and build-verified. The Swift 6 capture sweep
(#23) is build-verified across all four targets with `SWIFT_STRICT_CONCURRENCY=complete`.

Verified for #26 on the paired Apple Watch Ultra 4 simulator, in Arabic, computing Cairo times: at
4:19 pm الفجر, الظهر and العصر are full-strength while المغرب (6:54 pm) and العشاء (8:10 pm) are dimmed
and untappable, and the next-prayer line leads with ثم — the OWNER confirmed that reads correctly, after
I had misread the same line from a screenshot and called it fine. NOT verified: a real midnight on a real
watch, and the Digital Crown on the Tasbih page (untouched, but the one thing here a screenshot cannot
catch).

Verified for the onboarding Apple Watch step on the iPhone 17 simulator, against its REAL trigger and not
only the debug flag: with the paired Apple Watch Ultra 4 booted and the watch app absent from it, the step
appears on its own and the progress row shows five dots. Also checked with `-debugWatchStep 1`: the slide,
"Not now" advancing to sign-in, sign-in sitting fifth, Arabic and Urdu mirroring, and the four-step flow
unchanged without a watch. NOT verified: the over-the-air install window on a real watch, which is what
`watchSettleSeconds` exists for and which no Simulator reproduces, since its installs are instant.

Verified for the RTL fix on the iPhone 17 simulator, by reading the rendered text rather than the source:
the Apple Watch message and the location slide now open with their Latin word at the RIGHT (logical first)
in both Arabic and Urdu, and "Available Apps" stays one unit. Before the fix the owner spotted that the
Arabic "did not make sense" — the clauses were in the wrong order. NOT verified: the remaining un-isolated
Latin runs in otherwise-correct RTL values, and the twelve Urdu entries still holding verbatim English.

Verified for #24 on the iPhone 17 simulator: Settings > General is now App Language, App Version & Info,
Rate iPrayer and Manage Notifications & Location, with nothing else; the Qibla status card carries no
readout; and under `-debugSpinCompass 1` the ratchet logged 184 clicks, so removing the toggle did not
silence it. That build's archive contained zero hits for all four removed strings. NOT verified:
how any of it FEELS — there is no Taptic Engine on the Simulator, which is exactly what caused #22.

Verified for the calendar fix (#33, 2 October 2026) on the iPhone 17 simulator switched to a HIJRI device
(`simctl spawn <sim> defaults write "Apple Global Domain" AppleLocale ar_SA`, then shutdown and boot; put
`en_EG` back afterwards): build 12's code crashes at launch there (crash report: `duaOfTheDay`, index out
of range); the fixed code opens Home, shows the same Verse of the Day as a Gregorian device, and under
`-debugLogNotifications 1` every scheduled prayer's "wanted" and "fires" instants are identical. NOT
verified: an adhan actually ARRIVING on a Hijri-calendar iPhone (the trigger dates are right; delivery
needs a device and a wait); the copyright year and the widget's reload date were fixed by reading, and the
date arithmetic checked in a standalone script, not on screen. Other calendars (Persian, Japanese,
Buddhist) were measured in standalone scripts only.
Verified for Siri (#32, 2 October 2026) on the iPhone 17 simulator, clean build: metadata extraction,
phrase validation and Siri training all ran; the Shortcuts app lists the six shortcuts with ARABIC titles on
a simulator rebooted into Arabic, plus a tile per prayer; Next Prayer answers by tap; Tasbih opens its tab;
Continue Reading cold-launches into the reader at the last-read verse with the GREEN mark; a warm
`iprayer://verse/2/255` (Quran tab already visited) lands in the reader with the GOLD mark, and a second
link with the reader open replaces it; `iprayer://open/tasbih` with the reader open pops it; a second
`iprayer://open/qibla` under `-debugSpinCompass 1` leaves the dial turning; `-debugSiriDialogs 1` printed
all three answers coherently in nine languages, and on the Arabic simulator the unforced line came out in
Arabic with Arabic-Indic digits. NOT verified, and only a device can: SPEAKING to Siri in any language, how
each Siri voice reads "136°", and the language of the answer as displayed — the Simulator draws every
result banner in English, its own "Done" button included, even when rebooted into Arabic, so the banner
proves nothing either way. Also not verified: the second-window replay fix on a real iPad (reasoned and
reproduced in a Catalyst harness only).

Verified for build 13 (both merged, 2 October 2026): a clean Debug build of the combined code with phrase
validation; it launches to Home and logs the Siri answers; the Release ARCHIVE reports 1.1.0 (13), embeds
the widget extension and the watch app, carries `Metadata.appintents` and the per-language
`AppShortcuts.strings` / `AppIntents.strings`, and its binary has zero hits for `debugSiriDialogs`,
`debugLogNotifications`, `[Notify]` and `debugSpinCompass` against a positive control. NOT re-run on the
combined build: the Hijri-simulator launch and the tap-through of each shortcut, which were done on each
branch separately; the two changes share no code.

Verified for #34 (2 October 2026), every case as a screenshot of the rendered screen and each bug first
REPRODUCED on `main`'s code in the same harness (`main` as of build 12; #32 and #33 touch none of these
files). Qibla tab, iPhone 17 simulator at Cairo: device Arabic
(ar_EG) + app English reads "Qibla 136° · 1,286 km" where `main` reads "١٬٢٨٦ كم"; device en_US + app
Arabic reads "799 ميل"; device en_EG + app Arabic reads "1,286 كم"; and, re-shot after merging build 13
in, device ar_SA (Hijri) + app English reads "1,286 km". Watch, Apple Watch Ultra 4 simulator
paired with that phone, device English, language pushed over WatchConnectivity: in Arabic the next-prayer
page reads "5:30 ص" and "ثم الشروق 6:49 ص" (ثم still leads, at the right) where `main` reads "5:30AM" and
"6:49 AM"; the Today list reads "5:29 ص", "6:49 ص", "12:45 م", each on one line at full size, where `main`
breaks "6:49A" / "M"; the Qibla page reads "1,286 كم". In English the same three pages read "5:30 AM",
"6:49 AM" and "1,286 km", and the longest name, Maghrib, fits at full size. Also checked on the 40mm
simulator (the narrowest): times stay on one line in both languages. NOT verified: any of it on a real
watch or phone; the other seven languages on screen (their strings were measured in a standalone script
only); a device that is right-to-left AND on a 24-hour clock; and the complication beside the page on a
real face, which is the comparison the bug was first described by.
Verified for the 3 October additions to #34. Qibla tab under `-debugSpinCompass 1` on the iPhone 17
simulator: Arabic reads "استدر يميناً · 33°" and "القبلة 136° · 1,286 كم", the word at the right and the
degree sign right of its number; Urdu reads "دائیں مڑیں · 12°" and "قبلہ 136° · 1,286 کلو میٹر"; English is
unchanged, "Turn left · 49°" and "Qibla 136° · 1,286 km". Watch Today page without the tick, on the 40mm
simulator: every name whole in English ("Maghrib" beside "11:23 AM"), Arabic, French ("Lever du soleil")
and German ("Sonnenaufgang", which needed the name's minimum scale lowered from 0.7 to 0.6); and on the
49mm in English and Arabic. NOT verified: a PASSED row on screen — every capture was taken just after
midnight, when all of the day's prayers are still ahead, so the dimmed state was not seen, only left
unchanged in the code; and the five other languages on the watch.

Verified for 1.1.1 (14) (3 October 2026, #34 merged with three review fixes): a Debug build of the branch
at its merge state; the Release ARCHIVE reports 1.1.1 (14) and embeds the widget extension and the watch
app. NOT verified on screen: the three review fixes themselves (the language-change rewrite of the
distance, the watch clock's leading zero, the VoiceOver value) — each was established by the reviewer in a
standalone script against the same Foundation, not in the simulator.

**DEVICE PASS DONE — 20 September 2026.** The owner went through the whole standing "not verified" list on
their own iPhone and Apple Watch and reported everything working. That closes, all at once: the tracker
across a real midnight on two devices · the Today's Prayers widget rendered · the Verse of the Day widget on
a Home Screen and a Lock Screen, INCLUDING the KFGQPC font question that §6 had flagged as a possible
system-font fallback · the watch complications on a face · watch background refresh · Crown sensitivity on
the watch Tasbih · the Settings "install on watch" card · WatchConnectivity round-trips both ways · how the
haptics feel · iPad landscape · Dynamic Island · the Live Activity "Now" state · the pre-prayer reminder
firing · Airplane-Mode playback of downloaded audio · two-device iCloud sync · the real midnight rollover of
verse/dua/widget · audio sound · Lock Screen playback controls.

A future session should take that as tested, not as "reasoned about" — several of these (the tracker
ordering bugs of #20, the compass of #22) were things only a real device could ever have settled.

STILL not verified, and NOT a device question: the model-written translations in Urdu/Hindi/Russian/Chinese
need a reader of those languages. This is now sharper than it looks — a bidi audit on 20 September found
twelve Urdu entries still holding verbatim English (the dua translations, "Quran 3:173", "Sunan an-Nasa'i"),
which no amount of device testing surfaces.

## 6. Open items

**Compliance / release**
- Account deletion (guideline 5.1.1 v): DONE (PR #16, merged, branch deleted): Settings > Account has "Sign out and
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
- Store screenshots and review notes: DONE in `docs/` (see above). `docs/screenshots/` holds the 32 raw
  simulator captures and `docs/screenshots/captioned/` the same 32 with a headline drawn in; upload either
  set. Not yet uploaded to App Store Connect. Neither the release notes nor the listing text mentions Siri
  yet: that copy is the owner's, in two languages, and was left for them to decide.
- Licence: README now says all rights reserved (matching the in-app copyright line) with the bundled data's own
  licences pointed to; the MIT badge and LICENSE reference were removed. Switch to MIT later if wanted, but note the
  Tanzil text, KFGQPC font and EveryAyah audio could not be MIT anyway.
- Translations were written by the model: Arabic/French/German/Turkish confident; Urdu/Hindi/Russian/
  Chinese need a native read. This now includes 39 dua translations (7 languages each). The 20 September
  bidi audit also found TWELVE Urdu entries that are still verbatim English — the dua translations plus
  "Quran 3:173", "Quran 2:201", "Quran 3:8", "Quran 17:24", "Quran 20:114" and "Sunan an-Nasa'i". Those are
  missing translations, not direction bugs, and they are the first thing a native reader should be pointed
  at. Rerun the audit (§4) to list them again.
- Verse widget: DONE — the owner confirmed on a device that the KFGQPC font renders in both Home Screen
  sizes and the Lock Screen rectangular family, so the system-font fallback is not needed. Keep the font
  registered through UIAppFonts only (§7); that is what makes it work in the widget process.

**Siri (#32)**
- Needs the owner on a real iPhone: say each phrase to Siri in English and Arabic; confirm the answer is
  spoken in the Siri language and that the degree sign is read as "degrees"/"درجة" (if it is not, switch
  that sentence to a word, which needs plural variations in Arabic and Russian).
- `INAlternativeAppNames` in iPrayer-Info.plist teaches Siri two other ways to hear the app's name:
  "آي براير" and "I Prayer". The Arabic spelling is the model's guess at how the owner says it; confirm it.
- The Siri strings in Urdu, Hindi, Russian and Chinese are model-written, like the rest (see above).
- Not built, on purpose: voice actions that WRITE (mark a prayer, count a tasbih). Not built, could be:
  a "Siri" row in What's New, a Shortcuts link in Settings, the same intents on the watch.

**Features suggested, not built**
- Cache-as-you-listen (save streamed verses), background `URLSession` downloads, "download all",
  single-file-per-surah audio with the host's timing files (removes inter-verse gaps), mini player
  outside the reader, continuous play into the next surah, Quran translations (no data bundled),
  right-to-left tweaks beyond layout mirroring, native system `TabView` for the full Liquid Glass tab
  behaviour, reopen What's New from Settings > About, choosing the calculation method on the watch,
  local adhan notifications on the watch (phone notifications already mirror to it).

**Left open by #34**
- **Five App Store screenshots are stale now that #34 is merged,** plus their `captioned/` versions. The owner was
  asked on 3 October and does NOT want them retaken for now, so leave them unless asked.
  `iphone69-ar-06-qibla` and `ipad13-ar-06-qibla` show "136° القبلة · 1,286 km" where the app now writes
  "القبلة 136° · 1,286 كم", and the turn line number-first; `watch44-ar-01-next-prayer` shows "6:54PM" and
  "8:10 PM" (now "6:54 م", "8:10 م"); `watch44-ar-03-qibla` shows "1,286 km"; and
  `watch44-en-01-next-prayer` shows "6:54PM" where the app now writes "6:54 PM", a space apart. If they are
  ever retaken: the caption tool was never committed, so the captioned five would have to be composited
  onto the existing captioned images, and a next-prayer shot taken at night shows Fajr, not Maghrib.
- **Other interpolated `Text` literals that mix a translated word with a number** were not audited in
  Arabic: "Version 1.1.0" (About, What's New), the Tasbih's "of 33" and "2 cycles · 66", the reader's
  "Verse 12", "Downloading audio 40%", and the watch's Tasbih and streak lines. They share the construction
  that put the Qibla lines number-first (§3), so each is a candidate; none was looked at on screen.

**Known cosmetic**
- What's New was rebuilt in PR #12 (merged via #15); still to check: the four sections at larger Dynamic Type.
- Arabic hero card: the "at <time>" line is correct now (first-strong isolate); keep that pattern for any
  new interpolated time string, and see the §3 bidi rule for why it matters beyond cosmetics.

## 7. Data and licensing

- Quran text: Tanzil Project Uthmani text in the alquran.cloud JSON layout; verse text byte-identical
  to the original (only unused fields were removed). Tanzil requires attribution, no modification.
- Font: KFGQPC Uthmanic Script HAFS (family "KFGQPC Uthmanic Script HAFS", PostScript
  "KFGQPCUthmanicScriptHAFS"). Registered via UIAppFonts only — do not also register with CoreText.
- Audio: EveryAyah, see §3. Downloaded audio lives in Application Support/QuranAudio and is excluded
  from backups (Apple requires that for re-downloadable content).
- Prayer times: Adhan Swift (BatoulApps), linked into app and widget.
