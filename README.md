# MYASSISTANT

AI personal assistant — **Flutter (Dart)**, runs on **Android and iOS** from one codebase.
Scope per Project Scope & Delivery Document, 9 July 2026.

> Note: the scope document (Section 5) names Kotlin and excludes iOS (N1).
> Flutter + iOS is a deviation — record it via a Change Request (Section 13).

## Structure
```
lib/
├── main.dart              # app shell + 5-tab navigation
├── theme/app_theme.dart   # brand palette (Peacock / Marigold / Ink / Mist)
├── models/                # ChatMessage, RemoteConfig
├── services/
│   ├── api_service.dart   # backend calls (chat + config)
│   └── update_service.dart# Play in-app update (Android) / App Store (iOS)
├── widgets/update_button.dart
└── screens/               # the 8 screens from the UI design doc
```

## Screens → design doc
| # | Screen | File | Features |
|---|---|---|---|
| 01 | Voice Home | `voice_home_screen.dart` | A1–A4, M1 |
| 02 | Chat & Live Info | `chat_screen.dart` | A1, A5, C4, C5 — **live** |
| 03 | Daily Briefing | `daily_screen.dart` | C1, C2, D3, D4 |
| 04 | Documents | `documents_screen.dart` | B1–B4 |
| 05 | AI Phone Calling | `calls_screen.dart` | G1–G3 |
| 06 | Inbox & Replies | `inbox_screen.dart` | D1, D2, H1 |
| 07 | Smart Home | `smart_home_screen.dart` | I1–I3, H2, H3 |
| 08 | Privacy & Memory | `privacy_screen.dart` | E1–E3, F1–F3 |

Chat is wired to the backend; the rest use mock data until their data sources land.

## First-time setup
This repo holds the Dart source. Generate the native platform folders once:
```bash
flutter create . --platforms=android,ios --org com.myassistant
flutter pub get
```

Run:
```bash
# Android emulator against a local backend
flutter run --dart-define=BASE_URL=http://10.0.2.2:3000

# iOS simulator against a local backend (needs a Mac + Xcode)
flutter run --dart-define=BASE_URL=http://localhost:3000
```

## How updates work (no rebuild)
Two layers:
1. **Server-driven** — `GET /config` on the backend carries feature flags,
   announcements and changelog. The AI itself runs server-side, so new
   capabilities go live instantly on both platforms with no store release.
2. **Binary updates** — new screens need a store release. The update button
   then uses Play In-App Updates on Android, and opens the App Store on iOS
   (Apple has no in-app update API).

⚠️ Never download and execute code outside the stores — it violates both
Google Play and App Store policy.

## Backend
Separate repo: `MYASSISTANT_BACKEND`. Endpoints used here: `GET /config`, `POST /chat`.

## iOS requirements
A Mac with Xcode is required to build/run iOS, plus an Apple Developer
account ($99/year) to ship. No framework avoids this.
