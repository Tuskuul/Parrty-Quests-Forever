# Party Quests Forever 1.1.6-beta13 beta build record

Baseline: beta12, 4f73f09e9b10d116088ecabde811da995516f5fd.

Beta12 live result: The user supplied an in-combat report with setup ready,
prepared layout active, outside-combat collapsed=true, native collapsed=false,
and the native quest module shown. The accompanying recording visibly shows
native + opening quest rows from the pre-closed state while a bear attacks, then
Party Quests opening its pane. This verifies that reproduction in a solo test;
it does not establish group progress, sharing or broad addon compatibility.

New feature: Share quests > Open shareable uses the existing checkbox list.
Native IsPushableQuest filters own quests. Absence is established only by a current
party member's complete addon log no older than 120 seconds. Partial native data,
stale logs and unavailable logs never prove absence. Completion history is not
queried. Hover identifies known missing members without extra list columns.

Offers reuse the bounded snapshot transport with an explicit, validated G/1
purpose record and a distinct copied Offer marker carrying the original owner.
Only selected quest titles are transmitted. Copy, chat drafting and Import retain
purpose; ordinary snapshot behavior remains compatible. Recipient rows request
the actual quest rather than expanding a progress snapshot. Offers require beta13
on both clients and current same-party character identity.

Q request packets and A acknowledgments use existing SPQLOG1 whispers. Both ends
validate current party identity, token, purpose and selected quest membership.
Owner rechecks live own-log membership/native shareability. Requests/attempts are
throttled, confirmations are bounded to eight and expire after 90 seconds, link
limits/expiry remain six published snapshots and 15 minutes. Group departure,
abandoned quests and expired offers cannot trigger an owner push.

Native source checked at Gethe/wow-ui-source bebcb6bf309cf41b41bd74f8ca651e6a105b2676:
Vanilla/QuestLogFrame.xml calls QuestLogPushQuest on its Share button;
QuestLogDocumentation.lua exposes IsPushableQuest, GetSelectedQuest and
SetSelectedQuest. The owner selects the offered ID, verifies selection, attempts
QuestLogPushQuest, and restores the prior selection even on failure. A successful
Lua return is not proof of delivery or acceptance. Combat never invokes it.
Exceptions/explicit rejection or matching blocked-action events switch that
session to owner confirmation. A manual confirmation also revalidates state.
If the client rejects that click too, the UI directs the owner to its native
Share Quest button. No claim that remote-triggered native sharing has been proven.

Validation: 24 source files parse; 19 Lua regression suites; 7 auto-tag tests.
New simulated two-client test covers filtering, stale-log exclusion, no completion
history calls, minimal payload, checkbox UI, copy/return/draft/import, purpose
binding, packet transfer, recipient click, native selection restoration, normal
attempt acknowledgment, throttling, outsider/unoffered/expired/abandoned rejection,
combat deferral, explicit owner confirmation and blocked-action fallback.

Live checks when both players have beta13:
1. Compare Open shareable against both real logs, including a shared quest and a
   non-shareable quest. Check hover names and empty/waiting states.
2. Select a subset; send via Share to chat, then repeat via Copy Share link.
3. Recipient opens the offer list and requests one quest. Verify the actual normal
   share prompt, correct quest, original owner selection and normal acceptance.
4. Try while owner is in combat: no share until an explicit confirmation afterward.
5. Leave party or abandon an offered quest; verify requests cannot share it.
6. Verify full/selected log snapshots still expand normally, WIM chat paths and
   Copy/Import draft preservation. Inspect /spq report on both clients if delivery
   fails; offer-request, offer-push-attempt/deferred and transfer stages are bounded.

Keep stable main at 1.1.5. Questie interoperability is not part of this beta.
