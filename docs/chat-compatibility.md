# Chat compatibility implementation and live test

Supports native chat (including replacements retaining native edit boxes),
Blizzard-advertised CHAT_FOCUS_OVERRIDE editors, and optional WIM widget inputs.
This is a compatibility layer, not a universal chat replacement API.

## WIM source inspected

Reviewed WIM commit a0cf0265bd7dc2e28ae79b924073d22304a2e116:
- https://github.com/Legacy-of-Sylvanaar/wow-instant-messenger/blob/a0cf0265bd7dc2e28ae79b924073d22304a2e116/Sources/WindowHandler.lua
- https://github.com/Legacy-of-Sylvanaar/wow-instant-messenger/blob/a0cf0265bd7dc2e28ae79b924073d22304a2e116/Modules/WhisperEngine.lua
- https://github.com/Legacy-of-Sylvanaar/wow-instant-messenger/blob/a0cf0265bd7dc2e28ae79b924073d22304a2e116/Sources/Hooks.lua

Uses the public RegisterWidgetTrigger and RegisterItemRefHandler entry points.
The handler namespace is addon:SPQLOG, leaving other addon hyperlinks untouched.
Current WIM invokes standard chat event filters for incoming/outgoing character
messages; Party Quests uses those filters to preserve actual sender ownership.
It does not infer the sender from a formatted line or the visible WIM tab.
No WIM code or data is bundled. Older forks may expose different APIs; missing
hooks are skipped/reported and do not disable native chat support.

## Manual validation

1. Use two characters running Party Quests 0.15.0; install WIM on at least one.
2. Open the map and type a WIM character-whisper draft; leave the cursor in the
   middle. Click Share Quest Log. Confirm draft, cursor, and recipient remain.
3. Send manually. Confirm the recipient sees a clickable quest-log link in WIM
   and that clicking opens one viewer with the actual sender's snapshot.
4. Repeat with WIM guild/party windows if enabled, and native chat while WIM is
   installed. Confirm no duplicate insertion or unexpected window switches.
5. Repeat with WIM loaded before/after Party Quests and after /reload. Review
   diagnostics hook status if an integration step fails.
6. For other UI replacements, verify native drafts, guild/party/channel and
   whisper routes, incoming link conversion, and clicks in their actual build.

Automated mocks simulate these APIs and focus changes; they do not establish
that all released or Forever-modified chat addons are compatible. Battle.net snapshot transport is implemented as of 0.16.0; see below. No message is sent by the share action.

## Battle.net route (0.16.0)

Native CHAT_MSG_BN_WHISPER argument 13 supplies the chat account ID, which is
resolved with C_BattleNet.GetAccountInfoByID to gameAccountInfo.gameAccountID.
Data sends use C_BattleNet.SendGameData (or the legacy BNSendGameData alias) and
receives use BN_CHAT_MSG_ADDON. The data-event game-session ID authenticates
responses separately from the visible account label. Incoming Battle.net labels
are not treated as character-whisper destinations. No global chat/link handler
is replaced. Native character sync retains its separate route.

API declarations reviewed in the same Forever UI source snapshot used by this
project, commit bebcb6bf309cf41b41bd74f8ca651e6a105b2676:
- https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_APIDocumentationGenerated/BattleNetDocumentation.lua
- https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua

Test a Battle.net whisper in native chat and WIM with both copies updated, then
repeat across factions/realms. Verify no ordinary character whisper is sent and
the received snapshot matches its sender. Also test friend offline, another
WoW client flavor, expired snapshot, and multiple active game sessions.
API declarations alone do not establish actual Forever server-side delivery.
