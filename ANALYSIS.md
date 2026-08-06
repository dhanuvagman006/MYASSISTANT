# ANALYSIS.md — Project Audit (App + Backend)

_Aura/Section-1 deliverable · 07 Aug 2026 · covers `MYASSISTANT` (Flutter) and `MYASSISTANT_BACKEND` (Node/Express)_

## 0. The single most important finding

**The Aura master prompt assumes a native Kotlin/Compose Android app (Hilt, Room, Jetpack, KDoc). This project is Flutter + a Node/Express backend.** Every blueprint recommendation must be translated, not transplanted. A "complete architectural refactor to Clean Architecture with Hilt" would mean rewriting the app from scratch — that is rejected. The existing stack is sound and already implements a meaningful slice of the Aura vision (see §5). The plan (IMPLEMENTATION_PLAN.md) adapts Aura's *goals* to this stack's *idioms*.

## 1. Repository structure

### App (`MYASSISTANT`) — Flutter, 36 Dart files
```
lib/
  main.dart                     — entry, boot sequence, root navigation
  models/     (7)               — chat_message, memory_item, place, reminder,
                                  remote_config, user_document, vision_result
  screens/    (12)              — voice_home (primary), auth, inbox, calls, daily,
                                  documents, face (D-ID WebView), interview,
                                  lock, privacy, upgrade
  services/   (12)              — api_service (all HTTP), assistant_controller
                                  (wake-word/STT/TTS state machine), auth_service,
                                  call_service, notification_service (v19 zonedSchedule),
                                  phone_state_guard, region_language, app_lock,
                                  style_prefs, update_service, voice_service, app_strings
  theme/ widgets/               — app_theme tokens; 5 shared widgets
android/                        — minSdk per Flutter default; 10 permissions declared
```
Build: Flutter/Gradle. Plugin KGP deprecation warnings pending (11 plugins, see §7).

### Backend (`MYASSISTANT_BACKEND`) — Node 20 / Express, ~55 files
```
src/
  server.js                     — helmet, CORS, rate-limit (60/min), route mounting
  routes/                       — chat (sync + SSE stream), stt (Whisper), vision,
                                  docs, memory, privacy, places, region, config,
                                  auth, admin, appUpdate
  services/ai/router.js         — provider switch (currently Gemini-only ⚠️)
  services/intents.js (595 ln)  — regex intent layer: weather, news, nearby,
                                  reminders, calendar, email draft, doc recall,
                                  food order, briefing, meeting prep
  services/tools/               — weather, news, places, currency, units
  memory/                       — extractor + store + gemini-embedding-001
                                  semantic recall (cosine in Node, graceful fallback)
  docs/                         — Gemini doc analysis + SQLite FTS5 BM25 recall
  google/                       — OAuth tokens, Gmail/Calendar API, focus
  meetings/ reminders/          — extraction, CRUD stores
  did/                          — D-ID Agents face mode + custom-LLM bridge
  agentcall/                    — Plivo outbound agent calls
  billing/                      — Razorpay plans + per-feature enforcement
  swiggy/                       — food-ordering MCP integration
  middleware/auth.js            — X-App-Key + Google ID token (AUTH_DISABLED dev flag ⚠️)
db: Postgres (pg) + SQLite FTS5. Deploy: Docker (node:20-alpine, non-root), k8s manifests.
```

## 2. Architecture

- **App:** pragmatic service-locator style — singleton services (`AssistantController.instance`), `StatefulWidget` + `setState`. No DI framework, no formal layering. Appropriate at this size; will strain past ~25 screens.
- **State:** setState + a few ValueNotifiers. No Riverpod/Bloc. Config changes handled by Flutter defaults; no process-death restoration for in-flight voice sessions.
- **Navigation:** imperative `Navigator.push`. No typed routes.
- **Backend:** classic layered Express — routes → services → stores. Clean module boundaries per feature. Intent layer runs *before* the LLM (regex → tools → prompt injection), which is a cost-efficient router pattern.

## 3. AI pipeline (current)

1. Wake word (Porcupine, on-device, app-open only — foreground service removed due to AGP 9 plugin break).
2. STT: cloud Whisper via `/stt` (m4a upload) with device STT fallback.
3. `/chat` + `/chat/stream` (SSE): parallel fan-out — intent regex + tool calls + utterance embedding → semantic memory ranking (768-dim, 2200-char budget) + FTS5 doc recall → single Gemini call → voice-friendly reply (1–3 sentences, no markdown, matches user language/script).
4. TTS on device. Phone-state guard releases mic on incoming calls.
5. Face mode: D-ID WebRTC avatar in WebView, words sourced from own backend via custom-LLM bridge.

**Providers:** two-provider chain — Groq (Llama 3.3 70B, latency-first, incl. streaming) → Gemini 2.0 Flash fallback, order via `AI_PROVIDER_ORDER`. _Correction 07 Aug: the initial audit repeated a stale PROJECT_STATUS claim of "Gemini only"._

## 4. Memory system (current)

- **Semantic:** every memory row embedded (gemini-embedding-001, multilingual), stored as JSON text in Postgres — no pgvector. Cosine ranked in Node per query. Fallback to category order on any failure. Tested (`scripts/memory-semantic-test.js`).
- **Documents:** file store + one-shot Gemini extraction (title/category/date/summary/tags) + FTS5 BM25 recall wired into chat; matched files surfaced in the app UI.
- **No graph/relational memory. No memory decay. No on-device memory.**

## 5. What the project ALREADY has from the Aura blueprint

| Aura concept | Status here |
|---|---|
| Tiered routing (cheap router before frontier LLM) | ✅ regex intent layer + tools before Gemini |
| Semantic memory (vector) | ✅ embeddings + cosine recall |
| Document memory + recall | ✅ FTS5 + chat injection |
| Streaming responses | ✅ SSE `/chat/stream` |
| Voice pipeline (wake word, STT, TTS, barge-in on calls) | ✅ |
| MCP integration | ✅ partial — Swiggy MCP (food ordering) |
| Tool use | ✅ weather/news/places/currency/units/Gmail/Calendar |
| Remote config switchboard | ✅ `/config` |
| Vision | ✅ `/vision` multipart |
| Autonomous outbound action | ✅ Plivo agent calls |
| Billing/feature gating | ✅ Razorpay + per-feature enforce |
| Proactive suggestions, notif intelligence, screen parsing, graph memory, multi-agent DAG, offline SLM | ❌ (see GAP_ANALYSIS.md) |

## 6. Security audit

| Severity | Issue |
|---|---|
| **Critical** | GitHub PAT was shared in plaintext chat and embedded in local git remotes; still live at audit time. **Revoke immediately**, re-clone with a fresh fine-grained token. |
| ~~High~~ resolved | `AUTH_DISABLED=true` dev bypass — a boot-time production refusal already exists in server.js (verified 07 Aug; initial audit missed it). |
| **High** | No certificate pinning in the app (plain `http` package). |
| Medium | Session key in SharedPreferences (plaintext) rather than `flutter_secure_storage` (Keystore/Keychain). |
| Medium | Per-user rate limits exist but no abuse alerting; admin route auth model needs review. |
| Low | Uploaded doc files stored unencrypted at rest in `DATA_DIR`. |

## 7. Technical debt register

| Severity | Item |
|---|---|
| High | 11 Flutter plugins apply deprecated KGP — future Flutter versions will fail to build. Upgrade sweep required. |
| High | Screen-off wake word lost (foreground-task plugin removed on AGP 9). Core "ambient" promise degraded. |
| Medium | App test coverage ≈ 0 (no `test/` of substance). Backend has one unit script. |
| Medium | `setState` everywhere; `AssistantController` is trending toward a god object (mic ownership, wake word, TTS, lifecycle). |
| Medium | Embeddings as JSON text — O(n) scan per query; fine to ~10k rows/user, then needs pgvector. |
| Low | Imperative navigation; no deep links. |
| Low | flutter_local_notifications pinned to 19.x (documented, deliberate). |

## 8. Performance notes

- Parallel fan-out in `/chat` (intents ∥ embedding) is good. Health-ping mic warm-up is a nice latency trick.
- Risks: cosine scan growth (above); Whisper round-trip on every utterance (consider on-device STT first-pass for short commands); WebView face mode holds mic exclusively (already handled via onBackground/onForeground).

## 9. Recommendations summary

Keep the stack. Close gaps in this order: (1) security hotfixes, (2) build health (KGP sweep, screen-off wake word), (3) provider fallback, (4) then Aura feature phases — full ordering in IMPLEMENTATION_PLAN.md.
