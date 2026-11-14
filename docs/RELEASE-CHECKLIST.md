# Party Quests Forever 1.0.3 release record

- Final version: 1.0.3. Upload the ZIP as a Release.
- Install directory: SimplyPartyQuests; saved preferences and protocols preserved.
- Approved full-resolution artwork and matching 256 × 256 TGA included.
- TOC references, archive structure, Lua syntax and runtime asset paths checked.
- Fixes missing Ready tags for complete native party objectives in both views.
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
