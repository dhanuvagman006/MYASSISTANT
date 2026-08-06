# GAP_ANALYSIS.md — Current State vs. Aura Blueprint

_Section-2 deliverable · 07 Aug 2026 · read after ANALYSIS.md_

Legend: complexity L/M/H/VH. "Approach" is stack-honest (Flutter + Node), not the blueprint's Kotlin-native assumptions.

| Capability | Current | Target (Aura) | Gap & why it matters | Cx | Recommended approach |
|---|---|---|---|---|---|
| Multi-agent orchestration | Single LLM call + pre-LLM intent/tools | Orchestrator→DAG→specialists→Critic | No task decomposition; complex asks ("plan my Mysuru→Tokyo trip") get one-shot answers | H | Backend-side: planner loop in Node using Gemini function-calling; persist task state in Postgres; SSE progress events to app. **Do not** build agents in the app. |
| Critic / self-correction | None | Output validation + retry | Hallucinated tool args go unchecked | M | Cheap second pass (flash model) validating tool results against schema before reply |
| On-device SLM (Tier 2) | None | 3–7B local model | Offline = dead app; all PII goes to cloud | VH | Defer. Interim: on-device STT fallback exists; add rule-based PII scrub in app before upload. True SLM via `flutter_gemma`/MediaPipe LLM later, behind flag |
| Model routing | Regex intents (good Tier-1 analogue) | NPU router | Adequate for now | – | Extend regex layer; add embedding-based intent match for paraphrases |
| Vector memory | ✅ embeddings + cosine | Same, scalable | Scale ceiling at ~10k rows/user | L | Migrate to pgvector when p95 recall >150ms |
| Graph memory (PKG) | ❌ | Entities + typed edges | Can't answer "who did I meet at X" relationally | M | New Postgres tables `entities`/`edges`; extractor already produces facts — extend it to emit (subject, relation, object) triples. No graph DB needed at this scale |
| Memory decay | ❌ | Relevance scoring | Budget fills with stale facts | L | `last_hit_at` + hit counter; decay term in cosine ranking |
| MCP client (general) | Swiggy-specific | Generic client, N servers | Each integration is bespoke | M | Extract Swiggy MCP plumbing into generic `src/mcp/client.js` (JSON-RPC over HTTP/SSE); server registry table; expose as tools to the intent layer |
| Screen parsing (Accessibility) | ❌ | Read any app's UI | Blueprint's flag-ship trick | H | Flutter can't do this; needs a Kotlin `AccessibilityService` via platform channel. Play-policy risk is real — user-triggered only. Phase 4 |
| Notification intelligence | Local reminders only | Read/summarize/reply to all notifs | Major daily-value gap | H | Kotlin `NotificationListenerService` + platform channel → backend classify (existing intent layer) → digest in app. Phase 3 |
| Clipboard intelligence | ❌ | Auto-suggest on copy | "How did it know" moment, cheap | M | Android 10+ limits background clipboard reads; use foreground/share-sheet paths |
| Share-sheet interception | ❌ | Universal share target | Zero-friction ingestion of URLs/text/images into chat+memory | L | `receive_sharing_intent` package + intent-filter; route to `/chat` or `/docs`. **Highest value-per-effort gap in the list** |
| Ambient command palette (overlay) | App-open voice home | Query from any screen | Context-switch cost | M | `SYSTEM_ALERT_WINDOW` overlay via platform channel or `flutter_overlay_window`; OEM-permission fallback = quick-settings tile + notification action |
| Proactive suggestions | ❌ | Contextual bottom sheet | Reactive-only assistant | M | Server-side suggestion engine (time/calendar/reminders/memory) → new `/suggestions` → card strip on voice_home. Start rule-based |
| Screen-off wake word | ❌ (regressed) | Always listening | Core ambient promise broken | M | Replace removed plugin: native Kotlin foreground service hosting Porcupine, platform channel to Flutter |
| Provider fallback | Gemini only | Multi-provider | Contract + availability risk | L | Re-add second provider in `ai/router.js` behind env; health-based failover |
| Offline capability | ❌ | Graceful degradation | Network loss = silence | M | Queue outbound in app (sqflite); canned offline replies for reminders/local queries |
| Automation engine | ❌ | Trigger→condition→action | Power-user retention | H | Phase 4; reminders infra is the seed |
| Audit log of AI actions | Partial (implicit in stores) | Immutable user-visible log | Trust prerequisite for autonomy | L | `actions_log` table + privacy-screen view. **Must land before more autonomy** |
| Cert pinning / secure storage | ❌ / SharedPreferences | Pinned TLS, Keystore | See security register | L | `http` → `dio` with pinned cert; `flutter_secure_storage` |
| Wear OS / Android Auto | ❌ | Companion surfaces | Nice-to-have | H/VH | Defer to Phase 5 |
| Streaming perf (prompt cache/KV) | SSE works | Cached prompts | Cost + latency | L | Gemini context caching for the static system prompt |

## Prioritized gap list (impact ÷ effort)

1. **Security hotfixes** (token revoke, AUTH_DISABLED guard, secure storage, pinning)
2. **Build health**: KGP plugin sweep — existential for future builds
3. **Provider fallback** — contract requirement, one file
4. **Share-sheet interception** — biggest wow per line of code
5. **Screen-off wake word** (native service) — restores the ambient promise
6. **Audit log** — cheap, unlocks trust for everything autonomous
7. **Memory decay + graph triples** — deepens existing strength
8. **Generic MCP client** (generalize Swiggy) → calendar/files/search servers
9. **Proactive suggestions** (rule-based v1)
10. **Notification intelligence** (native listener)
11. **Orchestrator/Critic loop** (backend)
12. **Overlay palette, offline queue, automation engine, screen parsing, SLM, wearables** — later phases
