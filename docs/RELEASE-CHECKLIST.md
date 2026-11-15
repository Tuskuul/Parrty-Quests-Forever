# Party Quests Forever 1.1.6-beta8 beta build record

- Report: native pane disappears without a click in combat and recovers after combat.
  Removed addon-created secure child guards from native module layout frames.
  Retains secure frame references, state driver, visibility wrappers and beta7 +/- overlay.
  This reduces protection propagation; it is a candidate fix, not a confirmed live diagnosis.
- Fast updates: local reads debounce for 0.2s; changed quests/removals travel in D-prefixed
  multipart messages at least 0.35s apart, with 0.15s packet pacing. Full snapshots remain
  compatible with older receivers, retain a 5s minimum interval and a 15s recovery heartbeat.
  Multipart deltas apply atomically, preserve unrelated quests, reject older delta serials,
  and do not renew whole-log freshness. Requests reset receive sequencing after reloads.
- Native queries: 2s per-quest normal minimum, 5s/10s empty-result backoff for own/foreign
  quests, 0.35s event minimum; periodic batches resume after 1s. API budget remains three
  tasks per tick / 0.75ms; no catalog discovery or native layout writes during combat.
- Tooltip cache notifications: at most 64 query identities, 30s TTL, one retry per 0.2s.
  Event is only a retry hint, never quest credit. Secret values remain unreadable.
- Native completed booleans survive normalization and consumption; readiness still needs
  complete per-player objective coverage. No local counts assigned to another player.
- Sidebar viewport, rows and highlight are inset from the adjacent native pane.
- No item-count UI redesign. Questie network interoperability remains a researched
  possibility, not implemented or advertised as supported in this beta.
- Verify in game: native +/- clicks, spontaneous blanking during progress/combat,
  quest item buttons, combat exit restoration, addon-to-addon rapid item/kill progress,
  completion/removal, and no-addon party progress in and out of combat.
- Automated: 23 source Lua files parse, 16 Lua regression suites, 7 auto-tag tests.
