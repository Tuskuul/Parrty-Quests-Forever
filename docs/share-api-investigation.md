# Forever quest-sharing API findings

Scope: source inspection of Gethe/wow-ui-source's `forever` branch plus automated
mock checks. Native C++ implementation and the user's running client were not
available. This report distinguishes declarations/UI usage from runtime claims.

## Confirmed in the published interface

- `C_QuestLog.IsPushableQuest(questID)` returns one boolean. It takes no recipient,
  unit, GUID, or prerequisite arguments. This is a share-capability query, not a
  specific recipient's acceptance verdict.
- The normal Share button is enabled by `not isQuestDisabled and
  C_QuestLog.IsPushableQuest(questID) and IsInGroup()`.
- `QuestMapQuestOptions_ShareQuest` resolves the quest ID to an own-log index and
  calls `QuestLogPushQuest(questLogIndex)`. It does not use a player target.
- `C_QuestOffer` concerns the current offer/rewards and events. No universal
  arbitrary-quest recipient-eligibility function was found there.
- `QUEST_ACCEPT_CONFIRM` carries player name, quest title, quest ID. It belongs
  to a confirmation flow and is not assumed to fire for every ordinary share.
- `QUEST_DETAIL` is an offer/details event, and `QUEST_ACCEPTED` confirms addition
  to the log. Offer receipt and acceptance are distinct observations.
- `GetMaxNumQuestsCanAccept()` and quest-log counts allow a separate capacity
  check. Forever constants declare a standard quest-log cap of 40; use runtime
  values rather than assuming that cap for every future client.
- Completion, repeatability and session-disabled APIs are separate queries.
  Completion history is character-specific; account history is a different API.
- `GetQuestDifficultyLevel` is not documented as the minimum acceptance level.
- UI error/info events provide a native message identifier plus message text.
  `GetGameMessageInfo(identifier)` can map an identifier to its error name.

## Runtime uncertainties

1. IsPushableQuest is used by the UI for owned quests. Its behavior for a known
   foreign quest ID is not established by that usage or by its boolean signature.
2. A false result outside your log may indicate missing quest data or an ownership
   limitation. Do not equate it with confirmed non-shareability.
3. RequestLoadQuestByID and QUEST_DATA_LOAD_RESULT provide a way to compare before
   and after loading, but a successful data load does not itself prove that every
   field or remote query is supported.
4. Which native share failures reach the recipient versus the sharer needs a
   live test. System/error messages can be correlated with a recent manual share,
   but ambiguous messages must not become permanent eligibility rules.
5. No client-side function exposing the entire prerequisite tree and all server
   acceptance conditions was found in the inspected quest interfaces. This is a
   finding about the inspected declarations, not proof that no undocumented API exists.

## Practical routes away from bundled rules

- Prefer character completion APIs over a third-party completion database.
- If foreign IsPushableQuest works after loading, use its positive results as
  native share-capability evidence, separate from recipient eligibility.
- If it works only for owned quests, another installed copy can query on the
  owner's client and send just the boolean over the addon channel. A player
  without our addon would still need the existing manual-share workflow.
- Let an actual server share attempt produce an offer or failure. A successful
  offer/acceptance is evidence for that character at that time, not proof of a
  universal quest prerequisite rule.
- Unknown prerequisite eligibility stays unknown unless we change the feature
  to an explicit 'request a share attempt' workflow. No such behavior change is
  included in this diagnostic build.

## Test with 0.13.1

1. Have one owned shareable quest, one known unshareable owned quest if possible,
   and a party member's quest that you do not own.
2. Single-click the foreign quest in either addon view, then open Settings >
   Troubleshooting > Inspect share APIs. The inspector itself sends nothing.
3. Wait a few seconds. Have the party member use Blizzard's Share button manually.
   Observe whether a quest offer or a rejection appears. Do not double-click a
   quest during this read-only test; that retains the normal whisper action.
4. Reopen the diagnostic report during/after the 90-second capture and copy it.
   Review names and messages before sharing. The error-ID names avoid relying
   solely on English wording. Capture on both clients if both have the addon.

## Sources

- [Quest-log declarations](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestLogDocumentation.lua)
- [Native Share button and share handler](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/QuestMapFrame.lua) (`QuestMapFrame_UpdateQuestDetailsButtons`, `QuestMapQuestOptions_ShareQuest`)
- [Quest-offer declarations](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestOfferDocumentation.lua)
- [Forever quest constants](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestConstantsDocumentation.lua)
- [Native UI message event handling](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_UIErrorsFrame/Mainline/UIErrorsFrame.lua)
- [Error-name lookup declaration](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/GameErrorDocumentation.lua)
- [Acceptance confirmation dialogs](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_StaticPopup_Game/GameDialogDefs.lua)
