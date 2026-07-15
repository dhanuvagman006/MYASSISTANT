# MYASSISTANT

AI personal assistant for Android — Kotlin + Jetpack Compose (Material 3).
Scope per Project Scope & Delivery Document, 9 July 2026.

## Structure
- `app/` — Android app (min SDK 29 / Android 10+)
- `backend/` — Node.js API server (deploy to India region)

## Getting started
1. Open the root folder in **Android Studio** (Ladybug or newer). Gradle sync will
   download dependencies and generate the wrapper.
2. Generate launcher icons: right-click `res` → New → Image Asset.
3. Backend: `cd backend && npm install && ANTHROPIC_API_KEY=... node server.js`
4. Point the app at your server: edit `BASE_URL` in `app/build.gradle.kts`
   (use `http://10.0.2.2:3000` for the emulator against a local backend —
   requires `android:usesCleartextTraffic="true"` for local testing only).

## How updates work (no rebuild needed)
Two layers:
1. **Server-driven features** — `/config` on the backend carries feature flags,
   announcements and changelog. New AI capabilities ship server-side and are
   switched on remotely. The app reads this on every launch.
2. **Binary updates** — once live on the Play Store, the in-app Update button
   uses Google's official In-App Updates API (flexible or forced).

⚠️ Never download and execute code outside the Play Store — it violates
Google Play policy and risks removal.

## Security
- AI provider keys live ONLY on the backend, never in the APK.
- All user traffic goes app → backend → AI providers.
