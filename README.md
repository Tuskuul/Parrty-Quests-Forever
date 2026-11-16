# Party Quests Forever

<img src="docs/project-icon.png" alt="Party Quests Forever icon" width="512">

[Full-size artwork](docs/artwork/PartyQuestsForever-adventure.png)

Track party quests and available objective progress in **WoW Forever 1.60.1**.
Choose a Blizzard-styled tracker sidebar or a separate resizable window, combine shared quests, and group quests by player and zone.

## Current build

**1.1.6-beta14**, a testing build with **Share to chat**, **Copy Share link** and **Import**. Choose a full log or selected quests, then prepare a chat link or copy an in-game share string. Copy uses Ctrl+C; Import uses Ctrl+V. The original owner must stay online and the link must still be available. Copied strings use character-addon whispers and require this beta or newer; existing Battle.net sharing stays on Share to chat. All stable tracker fixes remain included. Native discovery remains limited to what the client exposes. Copy and Import replace the chooser until closed, preserving its selection and draft.

Beta8 adds compact quest progress updates between backward-compatible full-log syncs, quicker event-driven native queries, bounded tooltip-cache retries, native objective completion flags, and an inset selection highlight. Native polling remains limited to readable client data. Combat visibility no longer adds secure children to Blizzard's module layout frames; the intermittent native-pane blanking report still needs live verification.


Combat auto-collapse is under **Display → Collapse during combat**. It leaves the compact header visible; the Party Quests button can reopen the prepared contents during combat. Beta12 was visually verified reopening a tracker closed before combat on the tested Forever client. A manually opened view stays open until collapsed again or combat ends. It restores the previous expanded or collapsed view afterward; disable it to leave the tracker expanded during combat. Changes to this setting during combat apply afterward.

Beta9 streamlines Settings into Display, mode-specific Layout, Quests and Tools. Duplicate show/collapse/scan controls and developer-only actions are removed from the menu. Diagnostics and native recovery are under **Show troubleshooting**; saved preferences remain unchanged. The API inspector remains available with `/spq inspect`, and existing developer slash commands remain available.

Beta10 follows a full code audit: transient quest-data failures retain the last known log; party/snapshot packets retry bounded transport failures; delta updates stay authoritative over native observations; and Share preserves chat drafts edited while its chooser is open. Combat refresh uses budgeted data queries, display-mode changes wait for combat exit, and native modules are no longer forcibly reopened on every hide. `/spq report` now records frame protection and secure click stages. Native +/- and spontaneous blanking still require live verification; the build does not claim those reports resolved.

Beta11 queues Settings requests made in combat and opens the panel once combat ends. Unrelated blocked UI actions no longer disable native tracker recovery. `/spq report` distinguishes disabled combat setup, unavailable APIs and failed initialization, with the failed phase and error when available.

Beta12 prepares the underlying native layout outside combat even when the tracker is visually collapsed. While combat auto-collapse is enabled, the main button uses that prepared visibility path outside combat as well. Both combat buttons can then reopen prepared modules without calling the native full layout; combat exit restores the prior visual collapse. Disabling the option returns collapse control to Blizzard. The closed-before-combat case was subsequently verified in the user's beta12 recording; group progress and quest offers are separate tests.

## Quest offers

Open **Share quests → Open shareable**. This uses the same checkbox list as Select quests, filtered to quests in your own log that the client marks shareable and at least one party member is not currently on. Hover a title to see which known members are missing it. Only recent complete addon logs prove absence; unavailable or stale logs do not. No completion-history or prerequisite lookup is used for this list.

Select the quests to offer, then **Share to chat** or **Copy Share link**. Both players need beta13 or newer and must remain in the same party. The recipient opens the offer list and clicks **[Request share]** on a quest. The owner rechecks the published selection, current party membership, ownership and native shareability, then attempts the normal party quest share. Normal acceptance requirements still apply, and native sharing may offer the quest to other eligible party members as well.

Combat defers sharing to an owner confirmation. If the automatic native call fails or records a blocked action, a **Share quest** confirmation appears on the owner; subsequent requests use confirmation for that session. The original quest-log selection is restored. If that confirmation is also rejected by the client, use the normal quest-log Share Quest button. Native attempts are reported as attempts, not proof of delivery or acceptance. The user's subsequent beta13 reports recorded two native share attempts on the owner and matching acceptance events/current quests on the recipient. This supports that tested automatic path; other restrictions still apply.

Offer links expire after 15 minutes, share the six-published-link limit with snapshots, and contain selected titles without objective/completion details. Old full-log, selected-log, Copy and Import behavior remains available. Offers use character chat; they do not add Battle.net request routing or Questie interoperability.

Beta14 adds requester eligibility feedback. Quests with known failed acceptance checks are grey and marked **Not eligible**; hover for the reason, or click to display it above the list. Clicking rechecks the current character before sending any request, so gaining a level or changing quest state does not leave a cached row permanently blocked. Checks include available level/race/class rules, prerequisite and completion/chain rules, active ownership and the client-reported quest-log capacity. Unknown custom quests, unavailable history, repeatable availability and unverified profession/reputation rules remain **Check requirements**, rather than being treated as proven failures. Normal game acceptance still decides those cases.

These checks run on the requester. They do not change the publisher's Open shareable list or require party-member completion history. Only the requester needs beta14 for the new notices; beta13 owners remain protocol-compatible. An offer is reusable by multiple current party members for up to 15 minutes from creation while the owner remains online. Reloading the owner or exceeding the six-published-link limit can invalidate it earlier; ownership, shareability and party membership are rechecked per request.

## Install

The addon folder must be named **SimplyPartyQuests**. Put this repository's addon files directly inside `Interface/AddOns/SimplyPartyQuests/`, so `SimplyPartyQuests.toc` sits directly inside that folder. A GitHub source ZIP's repository-named wrapper must be renamed appropriately.

Existing Simply Party Quests users keep their settings. Replace files and `/reload`; a first installation may need a full client restart.

Open **Esc → Settings → AddOns → Party Quests Forever**, or right-click the minimap button. `/spq` remains supported.

Native party quests show **Ready** when the member's reported progress completes every known requirement, even without an explicit turn-in flag. Unknown or partial progress remains unmarked.

Progress queries and sidebar text update during combat. You can expand or collapse players, zones and quests, toggle the party pane, and reopen it during combat. These actions rebuild the addon panel from known data. Discovery, membership checks and native tracker repair wait until combat ends. Client restrictions still affect available data.

The party sidebar background follows the Objective Tracker opacity in Blizzard Edit Mode. It also follows the tracker's live fonts, size, outline, shadow, colors and scale. Appearance changes reflow rows outside combat.

When Blizzard's tracker is empty or hidden, the party pane uses a compact **Party Quests** header at the tracker position. Empty quest sections are omitted.

The party pane shrinks to its contents and expands up to the Objective Tracker height set in Blizzard Edit Mode. Longer lists scroll; there is no separate sidebar height setting.

Ready tags and turn-in text are bright green. Guarded Blizzard tracker refresh defaults on for new or unset preferences; explicit off settings are preserved. It requests redraws only for confirmed numeric mismatches outside combat, checks the result, and pauses after blank or unverifiable results. Settings can disable it.

## Quest-log links

Share now offers **Full log** or **Select quests**. Choose one or more quests and click **Share selected** to share just those entries and their objective progress. Cancel or Escape restores the original chat draft.

Click **Share** in the Party Quests tracker header, or **Share Quest Log** in the main Map & Quest Log title bar, left of fullscreen. It inserts a snapshot link into your current chat draft for you to send. Compatible recipients click to inspect the active quests and objective completion. This is a timestamped snapshot, not lifetime completion history or a live view.

Character chat, WIM and Battle.net whispers are supported. The owner must remain online with the addon for first fetch. Battle.net requires a compatible WoW session and uses its own data route for cross-faction/realm sharing. Not every UI/client/server combination has been tested.

## Documentation

- [Installation, controls and troubleshooting](README.txt)
- [Changelog](CHANGELOG.txt)
- [CurseForge listing copy](docs/CURSEFORGE.md)
- [Release checklist](docs/RELEASE-CHECKLIST.md)
- [Chat integration notes](docs/chat-compatibility.md)

The `.pkgmeta` file sets `package-as: SimplyPartyQuests` to preserve the install folder when a CurseForge-compatible packager is configured. It does not publish a release by itself.

## License and credits

Created by Wolfie. Project code is GPLv3. Static fallback data derives from QuestieDB and historic Questie contributions. The full [upstream notice](third_party/QuestieDB-NOTICE.txt) and [licensing statement, including its historical contributor caveat](third_party/QuestieDB-LICENSE.md), are retained. This addon is not affiliated with Questie. The project icon is original artwork.

## Audit record

See [the beta10 audit](docs/AUDIT-1.1.6-beta10.md) for reviewed components, corrections, test coverage and remaining live-client checks.
