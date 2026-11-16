# Party Quests Forever 1.1.6-beta14 beta build record

Baseline: beta13, 3a156511c78786bf5e84d2f3b8025c4bf4b072fb.

Live beta13 evidence:
- Recipient downloaded Ivry Berkana's offer snapshot, requested quests 95494 and
  899, then recorded acceptance events after each request and both IDs in own log.
- Owner report records two offer-push-attempt stages and result messages for those
  same IDs. No matching owner manual fallback or blocked actions were recorded.
  This supports the tested automatic native share flow, without proving all cases.
- Reverse-side requests included 1361 and 701; the user states that requester is
  too low-level. Bundled eligibility metadata gives minimum levels 30 and 29.

Changes:
- Extract existing local level/race/class checks for reuse before completion
  availability can obscure a known level failure.
- Check requester eligibility while rendering offers and freshly on click.
  Failures are grey/Not eligible, have a reason tooltip, and clicks report
  Not eligible: <reason> locally without sending a Q request.
- Check client-reported quest capacity using GetMaxNumQuestsCanAccept and the
  second GetNumQuestLogEntries result, not a guessed limit or header count.
- Reuse prerequisite, completion, exclusive/chain, parent and other known rules.
  Published native shareability overrides missing static shareable flags for
  offers only; ordinary legacy whisper requests retain their static flag gate.
- Unknown metadata/history and repeatable/profession/reputation uncertainty are
  explicit warnings, not proof of ineligibility. Native acceptance remains final.
- Completion-reader lookups are shared per displayed offer list. Publisher
  filtering, creation and offer payload still do not use completion history.
- Same-party/version/token/selection/rate/expiry guards and owner selection
  restoration remain unchanged. Beta13 owner protocol remains compatible.

Source check: Gethe/wow-ui-source at bebcb6bf309cf41b41bd74f8ca651e6a105b2676,
QuestLogDocumentation.lua documents GetMaxNumQuestsCanAccept as standard accepted
quest limit and GetNumQuestLogEntries as shown-entry and quest-count returns.
Eligibility database provenance and limitations remain in QuestEligibility.lua.

Validation: 24 source files parse; 20 Lua regression suites; 7 auto-tag tests.
New tests use actual 701/1361 metadata and cover low level even with unavailable
completion history, prerequisites, race/class, completed versus repeatable quests,
capacity versus header count, unknown rules, legacy flag gating, recipient UI
reason, zero requests on failure, and fresh level-up eligibility on a cached row.
The simulated two-client test now loads the real eligibility implementation and
still verifies the normal sharing flow. Publisher history-query count stays zero.

Live checks:
1. Lower-level requester opens the same offers and sees Not eligible on 701/1361;
   hover/click identifies required level, and owner sees no new share request.
2. Eligible requester still requests and accepts a quest normally.
3. Unknown/custom rules show Check requirements and remain requestable.
4. Old full/selected log snapshots still expand normally; shared pooled viewer
   rows must not retain offer tooltips/color when reused for a normal snapshot.

Offer TTL remains up to 15 minutes from creation, reusable by multiple current
party members. Owner must stay online; reload or six-link eviction can expire a
link early. Keep stable main at 1.1.5; no automatic stable promotion.
