# Questie compatibility audit — 1.1.7-beta3

This beta promotes the alpha6 compatibility work, includes all stable 1.1.6 features and shared tracker fixes, and uses the normal `SimplyPartyQuestsDB` settings. The older `SimplyPartyQuestsAlphaDB` declaration remains so its separate table survives beta logout; beta does not import or overwrite it. Install only one version in the `SimplyPartyQuests` folder. Alpha6 remains available on its original branch/tag for reference.

## Evidence and limits

Questie source examined: [`7ae74a192ce3697d9ad46ebe2d85d632275bf1d3`](https://github.com/Questie/Questie/tree/7ae74a192ce3697d9ad46ebe2d85d632275bf1d3), whose Forever TOC declares interface 16001, version 12.9.0. This is an upstream source snapshot, not proof about every packaged release or the installed client. Public database API examined: [QuestieDB API](https://github.com/Questie/QuestieDB/blob/master/docs/api.md). Run the live matrix below against the exact installed Questie and QuestieDB releases and record versions in `/spq report`.

The automation checks Lua syntax and executes mocked regression suites. It cannot establish Blizzard secure-code behavior, absence of native taint, actual texture/font appearance, or server-side quest acceptance. Full compatibility is not claimed.

## Ownership and behavior

| State | Party view | Native repair | Native combat controls |
|---|---|---|---|
| Questie absent | Saved sidebar/window choice | Saved preference | Existing behavior |
| QuestieDB only | Saved choice; fallback names/zones | Saved preference | Existing behavior |
| Questie loaded, tracker explicitly false | Saved choice, including Blizzard sidebar | Saved preference | Paused |
| Questie tracker true | Independent dock beside Questie when requested and available; popout fallback | Paused, including manual requests | Paused |
| Questie loaded, profile missing/invalid | Temporary popout | Paused | Paused |
| Tracker switched off during combat | Keep popout until combat ends | Paused until safe transition | Paused |

Questie tracker ownership comes from a guarded, read-only check of `Questie.db.profile.trackerEnabled`. That setting is an internal read surface, not part of the stable public API; an unreadable or changed structure takes the conservative popout route. Hiding Questie's map markers is independent of disabling its tracker. No Questie setting is written, and its tracker is never automatically disabled.

`db.displayMode` remains the requested preference. A common effective-mode function is used by visibility, minimap/slash toggles, settings, collapse and docking. Docking while Questie owns the tracker records the preference but does not seize the native frame. With Questie's tracker enabled, beta2 docks our independent pane beside its named UI frame when requested and available. Disabling Questie's tracker returns to the Blizzard sidebar. Existing window hide state is respected. Beta uses existing normal settings; there is no silent import from the earlier alpha table.

## Paths examined

| Path | Finding and alpha action |
|---|---|
| Native tracker redraw | Our repair reads native counters and may call `QuestObjectiveTracker:MarkDirty()`. Suppress queue/execution/verification while Questie owns the tracker. Cancel in-flight bookkeeping without turning off the saved repair option. |
| Shared native header | Our sidebar stretches artwork, changes title anchors, hides the native backdrop and individual module controls. Restore our saved edits once outside combat and stop applying them while Questie owns the tracker. Permanent OnShow/SetCollapsed hooks check ownership and become inert. |
| Secure combat controls | Our existing state driver/module hooks could affect Blizzard even with our popout selected. Do not arm them when Questie is loaded, including maps-only mode. Disable an existing controller and its overlay outside combat. Its disabled state handler performs no native Show/Hide operations. |
| Late load during lockdown | Addon Lua does not change protected controller attributes during combat. Cleanup is deferred. OptionalDeps gives normal Questie startup priority. Artificially loading Questie for the first time in combat after our secure controls have already been armed can leave those controls active until lockdown ends; this requires live acceptance or a reload outside combat. |
| Own-window combat behavior | Collapse only the unprotected addon popout, preserve its saved expanded/collapsed preference, allow manual reopening, and restore it after combat. Questie itself is untouched. |
| Native quest watches/focus | Questie hooks `C_QuestLog.AddQuestWatch`/`RemoveQuestWatch` on Forever. Our compatibility layer never adds/removes watches to force agreement. Existing focus highlighting only reads native super-tracking state. |
| Party roster/discovery | Continue SPQ and native APIs. Do not require every party member to install Questie or SPQ. Native-only discovery still depends on readable client data and must not be described as cross-zone reliable. |
| Questie progress | Questie has `QuestieComms:GetQuest`, a remote cache and party-objective drawing. These are private runtime modules. Alpha does not import, iterate, inject into or synchronize their caches. No Questie protocol messages are sent. |
| SPQ communications | Retain `SPQ1`, bounded full/delta log sync, snapshots and offer requests. Questie uses a different prefix. Keeping separate transports avoids feedback loops and invented cross-addon completeness. |
| Public notifications | When ready, register Questie's public `RegisterForQuestUpdates` once per API object. Validate IDs and schedule the existing coalesced local-log read. Do not copy callback data into party progress. Failed registrations back off ten seconds. No public API is required for coexistence. |
| QuestieDB | Optional, read-only `LibQuestieDB.RequireContract(1)` and `Quest.Get`. Native quest titles and own-log zone headers take precedence. Unknown entities, absent functions, unsupported contract or thrown errors fall back. No negative lookup cache hides later corrections. |
| Requirements and eligibility | Retain our existing requirements/acceptance logic. QuestieDB prose is not an ordered objective-progress list; its static requirements do not guarantee acceptance. Do not infer readiness or auto-request eligibility from descriptive text. Richer live prerequisite reconciliation is future work. |
| Item/kill/escort progress | Continue native/SPQ observations. Do not use our inventory, QuestieDB objective IDs or a map pin as evidence that somebody else completed a step. Escort/sequenced objectives remain native data limitations. |
| Map/minimap pins | Add no competing pins or waypoints. Questie already draws party objectives in its upstream module. Our minimap button remains an independent launcher. Minimap position can be moved if buttons overlap. |
| World-map toolbar | Questie uses Krowi overlay buttons; our existing Share Quest Log button sits in the map title bar. No direct shared anchor was identified in the inspected paths, but spacing requires live checks in small/fullscreen maps and with other map addons. The popout and Settings provide share access too. |
| Native/Questie links | Questie handles `questie:` and native `quest:` links. Our snapshot links use `addon:SPQLOG` and retain namespaced handlers. Preserve native/WIM/Battle.net routing and drafts. Test interleaved links; do not replace Questie's tooltip handler. |
| Tooltips | Our native structured-tooltip observation remains; compatibility adds no new tooltip modifications. Questie may add presentation lines. Duplicate native counts, name ambiguity and restricted data remain covered by our existing parser guards, but hook ordering needs a live test. |
| Performance | No new scan across QuestieDB or private remote logs. Detection runs within the existing ticker; metadata reads concern displayed/discovered quests. Public updates wake a coalesced reader. Existing discovery budgets and SPQ message pacing remain. |

## Popout presentation

Uses `BasicFrameTemplateWithInset` and the existing shared `StyleQuestDialog` parchment helper. Dark ink and dark inline progress markers replace the former dark-panel palette; class names are darkened for contrast. Keeps collapsible shared/player/zone/quest rows, independent scrolling, dragging, resizing and size persistence. Close records the hidden preference; the close control stays above the drag region. Adds Share quest log with chat-draft capture. Clamps scroll offset when groups collapse. Parchment atlas falls back to the classic quest-greeting texture when unavailable. No real QuestFrame controls or quest-acceptance scripts are inherited.

Mocked UI tests verify control actions, narrow layout construction, text palette, parchment fallback and scroll behavior. They do not verify final pixels. Inspect the window in-game at 380 px minimum width, typical 460 px width, and larger sizes; also test UI scale, long names, wrapped objectives and all supported locales.

## Live acceptance matrix (wider coverage pending)

[User-reported live observations](QUESTIE-LIVE-TESTS.md) include alpha6 with Questie 12.11.0 maps-only in a party of four through three combat exits, with no recorded blocked actions or processing errors. Counters were reported working. Questie tracker-enabled mode and broader combinations still need coverage.

| Test | Expected result |
|---|---|
| No Questie; fresh alpha settings | Existing Blizzard sidebar, normal native combat controls, independent alpha settings. |
| QuestieDB only | Fallback title/zone where native data is absent; no UI ownership override. |
| Questie tracker enabled before login | Popout; Questie tracker remains usable; no SPQ native overlay/repair. |
| Questie maps only before login | Blizzard sidebar usable; SPQ native combat collapse paused. |
| Toggle tracker on/off and reload | Correct effective view; requested display mode retained; no stuck native header/background/buttons. |
| Toggle tracker off in combat | Popout persists until combat ends; native layout untouched during lockdown. |
| Enter/leave combat, manually reopen popout | Only popout collapses; reopening persists; previous choice restored after combat. |
| Missing/broken/older QuestieDB | Native/static fallbacks, no Lua errors, no fabricated progress or eligibility. |
| Shared and unowned quests; item/kill/event/escort | SPQ observations stay correctly assigned and unknown states stay unknown. |
| Mixed clients, disconnect, zone change, leave/rejoin | Existing stale-cache/roster behavior retained; no Questie-only data claimed as a full SPQ sync. |
| Share full/selected logs, offers, copy/import | Same namespace, selection, eligibility and draft behavior as beta16. |
| Interleave native Questie/SPQ links in Blizzard/WIM/Battle.net | Each link opens its own handler; drafts/recipient routing survive. |
| World map small/fullscreen and minimap launchers | All buttons visible, independently clickable, no overlap or dragging conflict. |
| Resize/collapse/close/reopen popout at UI scales | Readable parchment, reachable scrollbar, no stale row/scroll/resize state. |
| `/spq report` | Exact client/build, Questie version, requested/effective view, pending cleanup, callbacks and provider reads visible. |
| Return to working folder | Working version and its previous configuration restored; alpha saved state stays separate. |

If a blocked-action notification appears, capture `/spq report` before a manual repair/reload. A notification's addon name alone is not proof of causation; record the exact steps, Questie version, tracker mode and whether combat was active.

## Deferred integration

Docking into Questie's own frame, publishing SPQ party locations through Questie, using private Questie remote progress, and replacing acceptance metadata are intentionally outside alpha1. None has a stable supported interface verified here. A future adapter should have an explicit read contract and version tests before depending on it. This alpha establishes ownership boundaries and preserves our existing group-browsing/sharing engine.

## Beta2 docking

[Read-only docking design and source reference](QUESTIE-DOCKING.md). Questie owns its own tracker; Party Quests follows its geometry in an independent pane without changing that ownership. The separate window remains selectable. Beta2 live validation is pending.

Beta3 follows the rendered Questie background/border opacity and fade without writing Questie settings, and refines the dock into compact controls/plain headings. See the docking record for appearance fallback and restoration details. Live beta3 appearance validation remains pending.
