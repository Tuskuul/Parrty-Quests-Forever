# Party Quests Forever 1.1.6-beta10 audit

Baseline: beta9, commit 9e6966082260bc6428e1857ca1e6c63306fa6d8b.
Target: WoW Forever 1.60.1, interface 16001, build 70938.
Blizzard source reference: Gethe/wow-ui-source bebcb6bf309cf41b41bd74f8ca651e6a105b2676.

## Scope

Reviewed the runtime modules, TOC load order, saved preferences, protocol readers
and writers, polling/event scheduling, both views, native integration, chat draft
handling, copy/import, character and Battle.net snapshot routing, diagnostics,
static-data structure and the existing tag/packaging workflow. No client is
available here; source review and Lua mocks cannot establish live compatibility.
Static data was checked structurally, not re-certified against every server quest.

## Corrections

| Area | Finding | Change |
| --- | --- | --- |
| Local log | A thrown/restricted/incomplete API response could erase good state | Read atomically under an error boundary, retain prior log, retry after one second; do not publish an unavailable log as a new snapshot |
| Rendering | Unchanged combat heartbeat reads caused full pop-out redraws and sends | Only invalidate/send for actual quest display changes, including zone headings |
| Party protocol | Invalid counts and oversized fields were accepted | Bound IDs, records, strings and numeric counts; reject negative/non-finite numeric fields and malformed readiness |
| Party ordering | Older full snapshots could overwrite newer state | Reject older completed serials, retain legacy serial-1 restart behavior, and request full recovery on a missing delta |
| Freshness | Native observations or membership validation could override fresh deltas once whole-log freshness expired | Timestamp each received quest and protect it independently for 120 seconds |
| Transport | Party packets and outgoing snapshot chunks were removed before checking delivery | Retry transient failures with pacing; bound retries and queue recovery/full sync or abort that snapshot response |
| Combat refs | Beta8 assumed saved refs made ordinary frames valid restricted handles | Check IsProtected inside secure snippets; use ordinary API calls only for currently unprotected modules; add no native secure child guards |
| Native lifecycle | OnHide forced modules visible during Blizzard's own rebuild/empty transition | Remove forced OnHide resurrection; preserve native ownership of those transitions |
| Native wrappers | Wrappers were attached without explicit handle eligibility | Use restricted native OnShow wrappers only on explicitly protected modules; ordinary OnShow handling checks current protection |
| Controls | Shift-refresh did nothing; combat right-click fell through to expansion | Refresh safe sources immediately through bounded tasks; defer catalog work; right-click keeps its meaning and gives limited feedback |
| Display mode | Combat choices partly switched UI state before layout could follow | Queue the latest request, apply once outside combat, allow cancellation by choosing current mode, show pending state in Settings |
| Share drafts | Submit/cancel could restore an obsolete draft over newly typed text | Refuse obsolete draft replacement and preserve current text/recipient; reopening a shown chooser preserves its selection/draft |
| Snapshot consistency | Completion flags were queried a second time after serialization | Use finished flags from the same cached own-log read as the snapshot |
| Preferences | Invalid tables/numbers/positions could break initialization | Normalize known fields and finite layout values; preserve valid preferences and explicit off choices |
| Diagnostics | Captures were documented as memory-only but stored in saved variables | Use session fields and remove old saved captures; retain the user's recording preference |
| Diagnostics | Combat report lacked actual frame protection and handler stages | Add bounded stage history, effective/explicit protection, visibility, height and quiet write-permission observations; limit repeated error notices |
| Display text | Remote text could carry WoW display markup | Escape source text at tracker/pop-out display sinks; do not change stored quest identity |

## Combat implementation boundary

Secure setup occurs outside combat. Native modules are never made protected by
addon-created children. Restricted Show/Hide is conditional on current protection.
Unprotected native modules use normal Lua visibility operations. Unknown or changed
protection is not overridden. A module that Blizzard legitimately hides is not
forced back on. Full native SetCollapsed/Update and repair remain deferred.

The native +/- still uses the dedicated prepared secure overlay from beta7.
The Party Quests button remains on its established secure click path. This audit
corrects invalid-target handling but does not certify native +/- or blanking fixed.
Protection can be affected by other addons and layout relationships. An implicitly
protected module may reappear during a native refresh because its OnShow cannot
be wrapped as if it were explicitly protected; no new child guard is added to
force eligibility. The live report is required to choose the next adjustment.

Quiet CheckAllowProtectedFunctions observations describe the ordinary report
caller's permissions, not what a secure click handler is allowed to do. The
stage history separately establishes whether the click snippet actually ran.

## Validation

- All 23 root Lua source files parse.
- All 17 Lua regression suites pass, including new audit-reliability coverage.
- All 7 automatic-tag tests pass.
- Combat mocks now distinguish effective/explicit protection and reject restricted
  operations on ordinary frame handles. Both protected and unprotected modules
  are exercised; tests no longer require forced native OnHide restoration.
- Regression cases cover unchanged reads, API exceptions/refused secret checks,
  incomplete enumeration, genuine empty logs, invalid payloads, retry pacing and
  failure recovery, serial gaps/restarts, fresh delta ownership, saved-state
  recovery, session capture storage, newer drafts and snapshot retransmission.
- Existing full/selected/copied/imported snapshots, completion flags, UI layout,
  readiness, native repair, appearance, height, opacity and auto-tag tests pass.
- Static tables: 5,233 unique sorted quest IDs; 4,937 unique zone mappings;
  131 zone/category names; 2,132 item-source records; 4,592 requirement records;
  4,244 eligibility records. No duplicate keyed records detected.

## Live checks still required

1. Compare native +/- and Party Quests opening/closing during combat, before and
   after objective changes; capture /spq report while a failure is present.
2. Exercise quest item buttons, empty-to-populated native modules, automatic
   collapse on/off, combat exit restoration and repeated combat transitions.
3. Test Shift-refresh, scrolling and all section expanders, queued/cancelled
   display changes, both sidebar sides and the separate window.
4. Test rapid progress, ready state, quest removal, reload/rejoin and temporary
   transport throttling with mixed addon versions. Older versions receive full
   snapshots; delta support requires beta8 or newer.
5. Test full/selected sharing, copy/import, cancellation after editing chat,
   character/Battle.net routes and WIM recipient/draft preservation.
6. Test Questie with its tracker enabled and disabled, and other UI replacements.
   Questie protocol interoperability is not implemented or claimed supported.

Legacy serial-1 restart compatibility cannot identify a deliberately replayed
serial-1 full snapshot as a separate sender session. Full recovery snapshots are
periodic; this build does not introduce a new incompatible wire protocol.
