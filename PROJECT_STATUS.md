# PROJECT_STATUS.md — MYASSISTANT (Flutter app)
_Handoff document · updated 16 July 2026 · read together with the same file in `MYASSISTANT_BACKEND`_

## What this project is
"MYASSISTANT / Hari" — a voice-first personal AI assistant app (Flutter, Android-first with iOS reference)
per the client's Project Scope document (45 features, groups A–M) and UI Design V1.0
(Peacock `#0F6B66` / Marigold `#F6A21E` / Ink `#0E1B1D` / Mist `#F2F6F5`, Sora + Inter fonts, "bloom orb").
Backend is a separate repo: `MYASSISTANT_BACKEND` (Node/Express, Gemini provider, Dockerised).

## Repo layout
```
lib/
├── main.dart                  # 5-tab shell (Assistant/Chat/Today/Calls/You), announcement banner, haptics
├── theme/app_theme.dart       # FULL light + dark themes, Sora/Inter via google_fonts
├── models/                    # ChatMessage, RemoteConfig
├── services/
│   ├── api_service.dart       # BASE_URL via --dart-define; /chat, /config, warm() ping
│   ├── voice_service.dart     # speech_to_text capture + fallback wake watching + flutter_tts
│   ├── assistant_controller.dart  # SINGLETON brain: wake→listen→answer→speak loop, UI-independent
│   └── update_service.dart    # Play in-app update / App Store link
├── widgets/                   # update_button, coming_soon (empty-state)
└── screens/                   # 8 screens; Chat + Voice Home are LIVE, rest are honest empty states
assets/icon/                   # generated bloom-orb app icon + adaptive foreground
assets/wake/                   # PLACE hey_hari_android.ppn HERE (Porcupine model, user-trained)
```
Note: `android/`/`ios/` folders are NOT in the repo — generated locally once with
`flutter create . --platforms=android,ios --org com.myassistant`.

## Done so far (chronological)
1. **Build fix** — `CardTheme` → `CardThemeData` (Flutter 3.27+ breaking change).
2. **Full redesign per UI Design V1.0** — brand theme (light **and** dark, fully specified:
   cards, chips, nav bar, inputs, buttons), Sora headlines/Inter body, brand mark in app bar,
   marigold announcement banner.
3. **All mock data removed** — no fake user "Arjun", gold rates, HDFC bill, fake devices/memories.
   Daily/Inbox/Smart-Home/Docs/Calls use a shared `ComingSoon` widget; Privacy shows real
   "Nothing yet / Not connected" states with disabled Export/Erase.
4. **App icon** — bloom-orb PNGs generated in `assets/icon/`, wired via `flutter_launcher_icons`
   (run `dart run flutter_launcher_icons` once locally).
5. **Dark-mode + layout fixes** — theme-aware colors everywhere (was white-on-white chips),
   orb layout via LayoutBuilder, SafeArea, haptic feedback (orb/chips/tabs/send).
6. **Voice loop LIVE** — "Hey Hari" wake word → capture question (live partial transcript)
   → backend `/chat` → answer shown in transcript card **and spoken via TTS**; conversation
   context kept; orb tap = instant listen; tap while speaking = interrupt.
7. **Screen-off architecture** — `AssistantController` singleton runs the loop independent of UI.
   Two wake engines: **Porcupine** (on-device, ~100 ms, screen-off; needs user-trained
   `assets/wake/hey_hari_android.ppn` + `--dart-define=PICOVOICE_ACCESS_KEY=...`) with automatic
   fallback to Android-recognizer transcript watching (foreground-only). Microphone
   **foreground service** via `flutter_foreground_task` keeps the process alive with screen off.
   Backend warm-up ping fires the instant the wake word triggers (latency).
8. **Battery toggle** — wake-word switch persists via shared_preferences; OFF releases mic and
   stops the foreground service entirely.
9. **API fix** — flutter_foreground_task 8.17 signatures (TaskStarter / eventAction).

Last commit at time of writing: `3e04298` on `main`.

10. **Natural multilingual voice** (barge-in was added then REMOVED at user request — too many false triggers on-device; tap-to-interrupt only now) (voice_service.dart, assistant_controller.dart, voice_home_screen.dart):
    - TTS picks the most human voice installed per language (scores neural/wavenet/network
      voices above the robotic "local" defaults) — best free upgrade; a cloud TTS
      (ElevenLabs / Google Cloud) via a backend /tts endpoint is the next step if the
      client wants studio-grade voices.
    - Every reply's language is auto-detected (all Indic scripts + CJK/Cyrillic/Arabic/etc.
      by Unicode ranges; Latin languages by stop-word vote, default en-IN) and the TTS
      voice switches to match.
    - BARGE-IN: while Hari speaks, the recognizer stays open; an echo filter (novel-word
      check vs. the reply text, wake word always passes) detects real user speech, cuts
      TTS mid-sentence, and the same recognition session becomes the next question —
      continuous conversation loop in _answerLoop().
      ⚠️ Caveat to test on device: some Android builds duck/mute TTS while SpeechRecognizer
      is active. If TTS is quiet during barge-in on the test phone, gate barge-in behind a
      flag or move to a raw-audio VAD approach.
    - Multilingual HEARING: "I speak…" language picker (globe pill on Voice Home) —
      Auto (device) + every recognizer locale, searchable, persisted (stt_locale_id).
    - Backend system prompt updated: reply in the user's language & script, 1–3 spoken
      sentences, no markdown/emojis (replies are read aloud).

11. **Regional language from location** (region_language.dart) — on first run (Auto mode),
    coarse location -> platform geocoder -> Indian state -> language (Karnataka=kn, Kerala=ml,
    TN=ta, AP/TG=te, MH=mr, GJ=gu, PB=pa, WB=bn, Hindi belt=hi, plus country map for abroad),
    validated against the device recognizer's supported locales. Pill shows "Auto · Kannada".
    User's manual pick in the "I speak…" sheet always overrides. Needs
    ACCESS_COARSE_LOCATION in the local AndroidManifest (README updated) and
    `flutter pub get` (new deps: geolocator, geocoding).

12. **Cloud STT (Whisper via Groq)** — device recognizer kept mishearing Kannada as English
    on the test phone, so question capture is now CLOUD-FIRST: app records m4a (record +
    path_provider, silence-stop at 1.6s quiet / 15s max) -> backend POST /stt (multer ->
    Groq whisper-large-v3-turbo, verbose_json) -> {text, language}. Whisper auto-detects the
    language, so no locale is needed for capture. Device STT remains for the wake word and
    as fallback (recorder unavailable / server down -> user repeats once). Run
    `flutter pub get`; backend needs `npm install` + restart (new dep: multer).

## ⚠️ CURRENT STATE / OPEN ISSUE — resume here
- User's last `flutter run` after commit `3e04298` produced **"long lengthy errors" that were
  NOT yet shared or diagnosed**. First suspects, in order:
  1. Stale caches after adding native plugins → `flutter clean && flutter pub get`.
  2. Porcupine/foreground-task Gradle requirements in the LOCAL `android/` folder:
     `minSdkVersion` (Porcupine needs ≥ 21, speech plugins may want ≥ 23 — check
     `android/app/build.gradle(.kts)`), Kotlin/AGP version, `Namespace not specified`,
     or **Manifest merger failed**.
  3. Manifest entries possibly missing/mistyped (see README "Screen-off wake word" section):
     RECORD_AUDIO, FOREGROUND_SERVICE, FOREGROUND_SERVICE_MICROPHONE, POST_NOTIFICATIONS,
     WAKE_LOCK, speech `<queries>`, and the flutter_foreground_task `<service>` block with
     `android:foregroundServiceType="microphone"`.
  Ask the user for the FIRST `Error:` lines + the "What went wrong:" section.

## Not done yet / roadmap
- Resolve the build error above; verify full screen-off wake flow on the Samsung F15
  (battery → Unrestricted is REQUIRED on One UI).
- User still needs to: train "Hey Hari" on console.picovoice.ai → drop `.ppn` in `assets/wake/`.
- Deploy backend to Render (guide already given; free tier cold-start hurts voice latency —
  suggest paid instance or uptime pinger; contract wants India region for production).
- GitHub Actions: build APK on push → GitHub Release; wire update button to it (Layer-2 updates).
- Features not started: Daily briefing (Calendar), Inbox digest (Gmail), Documents/OCR,
  AI phone calling, Smart home, real memory/privacy data, Google Sign-In (F1 — backend auth
  middleware already supports Google ID tokens when AUTH_DISABLED=false).
- X-App-Key header not yet sent by `api_service.dart` (backend dev mode has AUTH_DISABLED=true).

## How to run (dev)
```bash
# backend on the laptop first (see backend repo), then:
flutter pub get
flutter run --dart-define=BASE_URL=http://<LAPTOP_LAN_IP>:3000 \
            --dart-define=PICOVOICE_ACCESS_KEY=<optional>
# physical device over http needs android:usesCleartextTraffic="true" (dev only)
```

## Security notes for the next session
- A GitHub PAT was pasted into a previous chat and used for pushes; it must be **revoked/rotated**
  (github.com → Settings → Developer settings). Never commit it; use a fresh token per session.
- AI keys live ONLY in the backend `.env`; the app never holds provider keys.

## Update — 19 July 2026: Memory feature (app side)
- **`models/memory_item.dart`** — MemoryItem (id, category, key, value, source,
  updatedAt) + display title helper.
- **`services/api_service.dart`** — `fetchMemories / addMemory / deleteMemory /
  clearMemories` against the backend's new `/memory` routes (session JWT).
- **`screens/privacy_screen.dart`** — "WHAT I REMEMBER" is now LIVE: lists every
  fact with a category icon and per-row forget button, "Teach Hari something"
  dialog (saves with source=user), and confirmed "Forget all". Signed-out and
  offline states handled. No client changes needed for personalization itself —
  the backend injects memory into every /chat reply automatically.

## Update — 19 July 2026 (2): Greeting + location + mic reliability fixes
- **Greeting on sign-in/app open** — `AssistantController.greetOnLaunch()`
  (triggered from Voice Home after init, once per signed-in user): fetches
  /chat/greeting, speaks it, adds it to conversation history; if it ends with a
  question the mic opens automatically so the answer teaches the memory
  extractor. Re-greets when a different account signs in.
- **Location actually accessed now** — `_detectRegionalLanguage` order flipped:
  GPS (`RegionLanguage.candidates()`, triggers the permission dialog) FIRST,
  IP lookup only as fallback. New `RegionLanguage.currentCity()` reverse-geocodes
  "City, State" and it's saved to memory as `current_city` once per session.
  ⚠ Requires ACCESS_COARSE_LOCATION (+ RECORD_AUDIO) in the locally generated
  android/AndroidManifest.xml — android/ is not in the repo.
- **Mic fixes** (the "turns on/off, doesn't recognise" bug):
  1. VAD thresholds were fixed at −30 dBFS — quiet mics never triggered. Now
     ADAPTIVE: ~600 ms ambient calibration, speech = floor +8 dB (clamped
     −55…−22), no-speech window 6→8 s, live `micLevel` 0..1 for the orb.
  2. When the VAD heard nothing, capture DEAD-ENDED. Now it falls back to the
     device recognizer (unless the user cancelled — `lastRecordingCancelled`).
  3. 250 ms mic hand-off delay between stopping wake recognition and starting
     the recorder (they were fighting over the mic).
  4. `VoiceService.reinit()` — mic permission granted after first denial no
     longer requires an app restart (`ask()` retries init).

## Update — 19 July 2026 (3): Voice-reactive orb
- `_BloomOrb` now takes `level` (AssistantController.micLevel, 0..1, both
  capture paths — cloud recorder amplitude AND device recognizer
  onSoundLevelChange). While listening: marigold voice halo blooms with
  loudness, rings and core scale up, glow deepens/spreads. Samples (~5 Hz)
  smoothed with a 180 ms TweenAnimationBuilder so motion is fluid.

## Update — 19 July 2026 (4): Sign-up interview
- **`screens/interview_screen.dart`** — one-time voice onboarding for NEW
  accounts: Hari speaks 4 friendly questions (name, city, work/study, loves),
  auto-listens after each (cloud STT → device fallback, mic level animates the
  indicator), answers editable as text, per-question Skip + top-right "Skip all",
  then lands on the home shell.
- **Routing** — auth responses now carry `isNew` (backend: signup=true, social
  upsert reports `created`); `AuthService.lastSignInWasNew` drives the gate in
  main.dart: AuthScreen → InterviewScreen (new accounts only) → HomeShell.
- **Answer storage** — each answer POSTs to `/memory/interview`, which runs the
  memory extractor with `force:true` (no throttle); if extraction yields nothing
  (e.g. no AI keys) the raw answer is stored keyed by the question, so nothing
  is lost. After the interview the greeting is naturally personal.

## Update — 19 July 2026 (5): Assistant tools (app side)
- **Voice reminders end-to-end** — /chat now sends X-TZ-Offset + X-Geo-Lat/Lng;
  backend intents create reminders; after every answer the app resyncs and
  (re)schedules LOCAL notifications (`services/notification_service.dart`,
  flutter_local_notifications + timezone + flutter_timezone; exact alarms,
  boot-persistent). ⚠ Manifest additions required — documented in the service
  header (POST_NOTIFICATIONS, SCHEDULE_EXACT_ALARM, two receivers).
- **Today screen LIVE** (`screens/daily_screen.dart` rewrite): weather card
  (now + 3-day, icons), reminders with add(+ date/time picker)/complete/delete
  synced to /reminders, top headlines. Pull-to-refresh.
- `models/reminder.dart`; ApiService: reminders CRUD, fetchWeather, fetchNews;
  RegionLanguage caches lastLat/lastLng → ApiService.geo.
