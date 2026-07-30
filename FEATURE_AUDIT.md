# FEATURE_AUDIT.md — MYASSISTANT vs. Feature List (Scope doc, 9 July 2026)

_Audited 30 July 2026 against `MYASSISTANT` @ main and `MYASSISTANT_BACKEND` @ main.
Method: full code review of both repos + live backend smoke test (server booted with dev
env; `/health`, `/config`, `/region`, `/privacy/export`, auth gating on `/reminders` and
`/memory` verified responding correctly; `/chat` verified end-to-end up to the Gemini call,
which requires a real `GEMINI_API_KEY`)._

**Legend:** ✅ Implemented · 🟡 Partial / thin · 📱 Implemented but needs on-device verification · ❌ Not built

## Phase 1 — Core Application (24 features)

| Ref | Feature | Status | Evidence / notes |
|-----|---------|--------|------------------|
| A1 | Chat assistant | ✅ | `chat_screen.dart` ↔ `POST /chat` (+ `/chat/stream`), intent layer in `intents.js` |
| A2 | Voice conversation | ✅📱 | Wake→listen→answer→speak loop in `assistant_controller.dart`; tap-to-interrupt; verify wake word, TTS quality, screen-off service on a real phone |
| A3 | Multi-language | ✅ | Backend replies in user's language/script; menus EN/HI/ML in `app_strings.dart`; "I speak…" locale picker; `/region` auto-detect |
| A4 | Style settings | ✅ | `style_prefs.dart` — tone, answer length, voice speed |
| A5 | Live information | ✅ | `tools/news.js`, `weather.js`, `currency.js`, `units.js`; sources returned on `/chat` |
| B1 | Photo questions | ✅ | `POST /vision` + camera/share flow in app |
| B2 | Document reading | ✅ | `POST /docs` → Gemini extraction; FTS5 recall wired into chat |
| B3 | Scan to text (OCR) | 🟡 | Achievable through vision, but no dedicated "scan → editable text → copy/save/share" flow as specified |
| B4 | Screenshot helper | ❌ | No screenshot-intent flow (e.g. poster → calendar entry for approval) |
| C1 | Reminders & to-dos | ✅📱 | `reminders/` routes + `notification_service.dart`; verify notifications with app closed on device |
| C2 | Morning briefing | ✅ | `RE.briefing` intent (calendar + weather + reminders + news); feature flag currently off in `remoteConfig.js` |
| C3 | Nearby places | ✅ | `/places` + `/places/photo`, `RE.nearby` intent |
| C4 | Weather & utilities | ✅ | weather / units / currency tools |
| C5 | Translation helper | 🟡 | Works via chat prompting; no dedicated translation UI |
| D1 | Inbox summary | ✅ | `GET /google/inbox` + `RE.email` intent |
| D2 | Draft replies | ✅ | `POST /google/draft` + `RE.draftReply` (review before send) |
| D3 | Calendar by voice | ✅ | `GET /google/calendar`, `POST /google/event` with pending-event yes/no confirmation |
| D4 | Meeting prep card | ✅ | `GET /google/meeting-prep` + `RE.meetingPrep` |
| E1 | Preference memory | ✅ | `memory/extractor.js` + `/memory` routes + interview flow |
| E2 | Notes & recall | ✅ | Docs store + FTS5 BM25 recall, file surfaced during voice chat |
| E3 | Memory manager | ✅ | `/memory` GET/POST/DELETE + settings UI |
| F1 | Sign-in & app lock | ✅📱 | `/auth` (google/apple/email) + `app_lock.dart`, `lock_screen.dart`; verify biometrics on device |
| F2 | Privacy dashboard | ✅ | `privacy_screen.dart` + `GET /privacy/export` (verified live) |
| F3 | Safety rules | 🟡 | One line in the system prompt ("Decline harmful requests politely") + provider defaults; no care-notes layer for sensitive topics as specified |

**Phase 1 score: 19 ✅ · 3 🟡 · 1 ❌ (B4)** — several ✅ items still need real-device testing (📱).

## Phase 2 — Advanced Capabilities (21 features)

| Ref | Feature | Status | Evidence / notes |
|-----|---------|--------|------------------|
| G1 | Calls on user's behalf | 🟡📱 | `agentcall/` (Plivo engine, AI intro). Needs Plivo credentials, real-call testing, local-language call testing |
| G2 | Call preview & rules | ✅ | `POST /agentcall/preview`, `/agentcall/settings` (limits, hours) |
| G3 | Call results & follow-up | 🟡 | Transcript/summary stored; automatic follow-up (calendar/reminder) not confirmed end-to-end |
| H1 | Automatic sending rules | ❌ | Not built (no rules engine, no log, no master switch) |
| H2 | Cross-app routines | ❌ | Not built |
| H3 | Triggers & schedules | 🟡 | Time-based reminders only; no location/event triggers |
| H4 | Assisted app control | ❌ | No accessibility-service integration |
| I1 | Device control | ❌ | `smart_home_screen.dart` is a ComingSoon placeholder; no Google Home / Matter integration |
| I2 | Scenes & schedules | ❌ | Not built |
| I3 | Status & alerts | ❌ | Not built |
| J1 | Assistant on WhatsApp | ❌ | No WhatsApp Business integration |
| J2 | Business page posting | ❌ | No Facebook/Instagram integration |
| J3 | Share & draft anywhere | ❌ | No Android share-menu target |
| K1 | Health guidance | 🟡 | Generic chat answers only; no urgency indicator, medication reminders (beyond generic reminders), or visit-prep structure |
| K2 | Legal document helper | 🟡 | Contracts can be summarised via B2; no templates / advocate hand-off |
| K3 | Financial insights | ❌ | No Account Aggregator integration. (Razorpay in the backend is the app's own subscription billing — not this feature) |
| K4 | Professional connect | 🟡 | Nearby search covers discovery; no "verified professionals" directory |
| L1 | Price tracking & alerts | ❌ | Not built |
| L2 | Assisted purchase | 🟡 | Swiggy food-ordering flow exists (`swiggy/`); product search/compare/cart across stores not built |
| L3 | UPI payment assist | ❌ | Not built |
| M1 | Offline assistant | ❌ | No on-device model |

**Phase 2 score: 1 ✅ · 7 🟡 · 13 ❌**

## Other contract-level flags
1. **Two AI providers required (Scope §5)** — backend currently has Gemini only; a fallback provider must be re-added before delivery.
2. **`AUTH_DISABLED=true`** must be `false` in production.
3. Several remote-config feature flags (e.g. `morning_briefing`, `voice_mode`) are still off in `remoteConfig.js`.
4. Device-dependent items (wake word, screen-off service, notifications, biometric lock, TTS/barge-in) require testing on physical Android hardware — cannot be verified in CI or a container.

## Bottom line
- Phase 1 is substantially delivered (~21/24), pending device QA and the B3/B4/F3 gaps.
- Phase 2 is early: AI calling and food ordering have real foundations; automation, smart home, social/WhatsApp, finance, commerce, and offline are unstarted.
