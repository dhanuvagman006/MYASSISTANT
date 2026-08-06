# IMPLEMENTATION_PLAN.md — Hari → Aura

_Section-3 deliverable · 07 Aug 2026 · read after ANALYSIS.md + GAP_ANALYSIS.md_

## 0. Governing decisions (mini-ADRs)

- **ADR-001 Keep Flutter + Node.** Rejected: native Kotlin rewrite (blueprint's implicit assumption). Rationale: 36-file app + 55-file backend already deliver voice, memory, tools, streaming, billing; a rewrite burns 3+ months for zero user value. Native Kotlin is used *surgically* via platform channels only where Flutter cannot reach (foreground mic service, NotificationListener, AccessibilityService).
- **ADR-002 Agents live in the backend.** The phone is a thin, reliable voice/UI shell; planning loops, tool orchestration, and the Critic run in Node where they're testable, updatable without app releases, and share the memory stores.
- **ADR-003 Postgres is the only database.** Vector (pgvector when needed), graph (edge tables), audit, tasks — all in Postgres. Rejected: dedicated vector/graph DBs (operational overhead unjustified at this scale).
- **ADR-004 Autonomy requires audit-first.** No new autonomous capability ships before the user-visible action log (Phase 1) exists.
- **ADR-005 State management: introduce Riverpod incrementally**, new screens first; no big-bang migration of working screens.

## Phase 1 — Foundation & Health (do first, small, sequential)

| # | Work item | Repo | Validation |
|---|---|---|---|
| 1.1 | Revoke leaked PAT; fresh fine-grained token; scrub token from any remotes/scripts | both | old token returns 401 |
| 1.2 | ~~Boot-time production refusal for AUTH_DISABLED~~ **already existed** (verified 07 Aug) | backend | ✅ |
| 1.3 | ~~Secure storage migration~~ **already existed**: session JWT is in `flutter_secure_storage` (Keystore/Keychain); remaining SharedPreferences hold only wake/locale/style prefs — no secrets (verified 07 Aug) | app | ✅ |
| 1.4 | Cert pinning: move ApiService `http`→`dio` + pinned SPKI, with remote-config escape hatch for rotation | app | MITM proxy fails |
| 1.5 | KGP plugin sweep: upgrade the 11 flagged plugins; document any that lack fixes | app | `flutter build` clean of KGP warnings |
| 1.6 | ~~Second AI provider~~ **already existed**: Groq→Gemini chain incl. streaming (verified 07 Aug; PROJECT_STATUS was stale) | backend | ✅ |
| 1.7 | `actions_log` + audit module + hooks + GET /actions + privacy export/erasure | **done both sides**: backend (8/8 tests) + app Activity log screen in Privacy | ✅ pending device run |
| 1.8 | Test scaffolding: backend `npm test` suite (supertest on /chat,/memory,/docs mocks); app `flutter_test` for ApiService + AssistantController state machine | both | CI green |
| 1.9 | CHANGELOG.md + /docs/adr/ established | app | committed |

Risk: plugin upgrades may break APIs (as flutter_local_notifications did). Mitigation: one plugin per commit, run on device between each.

## Phase 2 — Core Aura Experience

| # | Work item | Notes |
|---|---|---|
| 2.1 | **Share-sheet target**: text/URL/image/PDF shared from any app → chooser (Ask Hari / Save to memory / Save doc) → `/chat` or `/docs` | `receive_sharing_intent`; the cheapest "wow" |
| 2.2 | **Screen-off wake word**: Kotlin foreground service hosting Porcupine + platform channel; battery-tested (Doze, OEM killers) | replaces removed plugin |
| 2.3 | **Memory v2**: decay scoring (`last_hit_at`, hit count) + graph triples (`entities`,`edges`) emitted by existing extractor; recall merges cosine + 1-hop traversal | pure backend |
| 2.4 | **Generic MCP client**: extract Swiggy plumbing → `src/mcp/client.js`; registry table; first generic servers: web-search, filesystem(user docs), calendar bridge | tools auto-registered into intent layer |
| 2.5 | **Proactive suggestions v1**: rule-based `/suggestions` (time + calendar + reminders + weather + memory anniversaries) → card strip on voice_home; accept/dismiss feedback stored | server-side, updatable without release |
| 2.6 | **Offline queue**: sqflite outbox; reminders/doc-list readable offline; queued asks flush on reconnect | |
| 2.7 | Prompt caching (Gemini context cache) for static system prompt | cost/latency |

## Phase 3 — Agentic Layer

| # | Work item | Notes |
|---|---|---|
| 3.1 | **Orchestrator v1** (backend): goal → Gemini function-calling plan (max 5 steps) → user approval via app dialog → sequential execution with SSE progress → synthesis. Task state in Postgres (resume-safe) | |
| 3.2 | **Critic v1**: schema + sanity validation of each tool result by flash model; one retry with amended args | 90% simulated-failure catch target |
| 3.3 | **Notification intelligence v1**: Kotlin `NotificationListenerService` → platform channel → backend classify (urgent/info/spam) + digest + drafted replies (user sends manually) | special permission onboarding UI |
| 3.4 | **Email triage agent** on existing Gmail integration: classify, draft, propose-archive (audit-logged, approval-gated) | |
| 3.5 | Deep-research mode: multi-search + synthesis with sources, streamed | extends existing news/search tools |

## Phase 4 — Autonomy (all approval-gated + audit-logged per ADR-004)

Automation engine (trigger→condition→action, seeded from reminders infra) · auto-send tier for notification replies per-contact opt-in · Accessibility screen parsing (user-invoked "look at my screen", Kotlin service, Play-policy disclosure) · overlay command palette · cross-app workflows.

## Phase 5 — Experimental

On-device SLM (flutter_gemma/MediaPipe) for offline Q&A + PII pre-scrub · semantic photo search · Wear OS haptics · vocal biomarkers. All feature-flagged via existing `/config` switchboard.

## Milestones & risks

- **M1 (Phase 1)**: "Healthy & trustworthy" — build clean, dual-provider, audited, secure. Risk: plugin breakage (medium/medium; per-commit device testing).
- **M2 (Phase 2)**: "Ambient" — share-in, always-listening, smarter memory, proactive cards. Risk: OEM foreground-service kills (high/medium; vendor allow-list docs, persistent-notification pattern).
- **M3 (Phase 3)**: "Agentic" — plans, critiques, triages. Risk: hallucinated tool args (medium/high; Critic + approval gates).
- **M4 (Phase 4)**: "Autonomous" — acts with consent. Risk: Play policy on Accessibility (medium/high; user-invoked-only + prominent disclosure, overlay fallback).

## Workflow (per Section 9/10 of the master prompt)

Feature branches `feature/phase-{n}-{name}` · Conventional Commits · tests green before push · one logical change per commit · ADR before any new architectural pattern · CHANGELOG updated per merge.

## Immediate next actions (awaiting owner go-ahead)

1. You revoke the leaked PAT and issue a fresh one (I cannot do this for you).
2. I start Phase 1 items 1.2–1.5 on `feature/phase-1-security-and-build-health`.
