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
