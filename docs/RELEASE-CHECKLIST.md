# Party Quests Forever 1.1.2 release record

- Final version: 1.1.2. Upload the ZIP as a Release.
- Promotes user-tested green Ready labels and synced completion correction.
- Guarded native refresh defaults on for unset preferences; opt-outs persist.
- Retains native refresh result checks, duplicate suppression and pause behavior.
- Test identifiers and startup color sample removed.
- Auto height uses the shared Edit Mode cap; small/empty lists stay compact.
- Height tests cover configuration changes, contraction, scrolling and fallbacks.
- Live font, shadow/outline, palette and scale changes trigger sidebar reflow.
- Appearance checks cover in-place font updates and combat deferral.
- Sidebar background follows Forever Edit Mode background opacity; text is unchanged.
- Opacity checks cover zero/full values, slider changes and unavailable settings.
- Consolidates the 1.0.1–1.0.4 changes and the settings/status wording updates.
- Install directory: SimplyPartyQuests; saved preferences and protocols preserved.
- Approved full-resolution artwork and matching 256 × 256 TGA included.
- TOC references, archive structure, Lua syntax and runtime asset paths checked.
- Enables bounded combat progress polling and text updates in existing sidebar rows.
- Combat tests verify no Blizzard tracker access or sidebar geometry changes.
- Keeps native repair, discovery and membership checks deferred.
- Readiness regression tests use another player's quests with an empty local log.
- Full log / Select quests sharing remains unchanged.
- Verified subset payloads, completion flags, stale/empty selections, draft retention,
  cancellation and popup state with mocked Lua APIs.
- Prior user testing confirmed WIM send/receive and a Battle.net snapshot transfer.
- GPLv3 text and the complete QuestieDB notices, including the historical
  contributor caveat, are retained. This packaging does not resolve that caveat.
- Native discovery remains limited to client-provided information. Not every
  UI build or cross-faction/realm combination has been tested.
- No new live-client test or CurseForge publication was performed during packaging.
