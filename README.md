# Party Quests Forever

<img src="docs/project-icon.png" alt="Party Quests Forever icon" width="512">

[Full-size artwork](docs/artwork/PartyQuestsForever-adventure.png)

Track party quests and available objective progress in **WoW Forever 1.60.1**.
Choose a Blizzard-styled tracker sidebar or a separate resizable window, combine shared quests, and group quests by player and zone.

## Current build

**1.1.7-beta1** brings the Questie compatibility preview to the normal beta branch, including all stable **1.1.6** features and fixes.

Questie's tracker enabled, initializing or unknown: Party Quests temporarily uses its separate parchment window. Questie's tracker disabled: the existing Blizzard sidebar remains available. Your preferred display mode is preserved. Native tracker refresh pauses while Questie owns the tracker; native combat controls pause whenever Questie is loaded. The independent Party Quests window remains usable during combat.

QuestieDB is optional and supplies fallback quest names and zones; native information takes priority. Private Questie progress and network protocols are unused. Questie settings are never changed.

This beta uses the normal `SimplyPartyQuestsDB` settings, just like 1.1.6. Earlier alpha settings stay in their separate `SimplyPartyQuestsAlphaDB` table and are not imported or overwritten. Install one version at a time in the `SimplyPartyQuests` folder.

[Compatibility audit](docs/QUESTIE-COMPATIBILITY.md) · [Live test observations](docs/QUESTIE-LIVE-TESTS.md) · [Beta release notes](docs/RELEASE-1.1.7-beta1.txt)

## Quest offers

Open **Share quests → Open shareable**. This uses the same checkbox list as Select quests, filtered to quests in your own log that the client marks shareable and at least one party member is not currently on. Hover a title to see which known members are missing it. Only recent complete addon logs prove absence; unavailable or stale logs do not. No completion-history or prerequisite lookup is used for this list.

Select the quests to offer, then **Share to chat** or **Copy Share link**. Both players need beta13 or newer and must remain in the same party. The recipient opens the offer list and clicks **[Request share]** on a quest. The owner rechecks the published selection, current party membership, ownership and native shareability, then attempts the normal party quest share. Normal acceptance requirements still apply, and native sharing may offer the quest to other eligible party members as well.

Combat defers sharing to an owner confirmation. If the automatic native call fails or records a blocked action, a **Share quest** confirmation appears on the owner; subsequent requests use confirmation for that session. The original quest-log selection is restored. If that confirmation is also rejected by the client, use the normal quest-log Share Quest button. Native attempts are reported as attempts, not proof of delivery or acceptance. The user's subsequent beta13 reports recorded two native share attempts on the owner and matching acceptance events/current quests on the recipient. This supports that tested automatic path; other restrictions still apply.

Offer links expire after 15 minutes, share the six-published-link limit with snapshots, and contain selected titles without objective/completion details. Old full-log, selected-log, Copy and Import behavior remains available. Offers use character chat; they do not add Battle.net request routing or Questie interoperability.

Beta14 adds requester eligibility feedback. Quests with known failed acceptance checks are grey and marked **Not eligible**; hover for the reason, or click to display it above the list. Clicking rechecks the current character before sending any request, so gaining a level or changing quest state does not leave a cached row permanently blocked. Checks include available level/race/class rules, prerequisite and completion/chain rules, active ownership and the client-reported quest-log capacity. Unknown custom quests, unavailable history, repeatable availability and unverified profession/reputation rules remain **Check requirements**, rather than being treated as proven failures. Normal game acceptance still decides those cases.

These checks run on the requester. They do not change the publisher's Open shareable list or require party-member completion history. Only the requester needs beta14 for the new notices; beta13 owners remain protocol-compatible. An offer is reusable by multiple current party members for up to 15 minutes from creation while the owner remains online. Reloading the owner or exceeding the six-published-link limit can invalidate it earlier; ownership, shareability and party membership are rechecked per request.

## Share-window appearance

Beta15 applies the approved parchment quest-dialog treatment to the sharing chooser, received logs/offers, Copy/Import and owner share confirmation. Dark brown quest text, green completion text, native quest icons and red eligibility reasons are readable against parchment. The selected Full log, Select quests or Open shareable mode is highlighted. Copy and Import retain a distinct bordered input field. Unavailable offer rows show the reason beneath the title as well as on hover/click. All share dialogs remain draggable and are clamped to the screen.

The theme uses client quest artwork and retains the existing native button/close-frame trim. It does not reskin Blizzard's actual NPC quest dialog, objective tracker, Settings or the general diagnostic report. Link lifetime, eligibility rules and sharing protocols are unchanged.

## Chat destinations and copied Battle.net links

Beta16 adds a parchment **Share to chat** destination popup. Choose **Current chat / whisper** to preserve the original conversation, including WIM or Battle.net. Alternatively choose Party, Guild, Say, Yell, or a joined numbered chat channel. The channel list reflects the character's current channels; unavailable group/guild/channel choices are disabled and membership/number/name are rechecked when clicked. The link opens in the chosen Blizzard chat entry; press Enter to send. Cancel returns to the chooser with its selections and draft intact.

Choosing a public destination starts a fresh public draft and never copies a private whisper's text. If the public chat entry already contains text, send or clear that draft first, or choose Current chat / whisper. Nothing is posted automatically.

Copied full/selected log markers in native Battle.net messages now become clickable and use the sender's Battle.net data route when their active WoW character matches the encoded original publisher. Forwarded copies retain the original character rather than requesting the forwarding friend's log. Importing a copy already observed through Battle.net preserves its route. Copied offers can be displayed in Battle.net text but still use same-party character communication and all existing eligibility guards.

## Install

The addon folder must be named **SimplyPartyQuests**. Put this repository's addon files directly inside `Interface/AddOns/SimplyPartyQuests/`, so `SimplyPartyQuests.toc` sits directly inside that folder. A GitHub source ZIP's repository-named wrapper must be renamed appropriately.

Stable and beta keep their existing settings. This alpha starts with independent settings. Replace files and `/reload`; a first installation may need a full client restart.

Open **Esc → Settings → AddOns → Party Quests Forever**, or right-click the minimap button. `/spq` remains supported.

Native party quests show **Ready** when the member's reported progress completes every known requirement, even without an explicit turn-in flag. Unknown or partial progress remains unmarked.

Progress queries and sidebar text update during combat. You can expand or collapse players, zones and quests, toggle the party pane, and reopen it during combat. These actions rebuild the addon panel from known data. Discovery, membership checks and native tracker repair wait until combat ends. Client restrictions still affect available data.

The party sidebar background follows the Objective Tracker opacity in Blizzard Edit Mode. It also follows the tracker's live fonts, size, outline, shadow, colors and scale. Appearance changes reflow rows outside combat.

When Blizzard's tracker is empty or hidden, the party pane uses a compact **Party Quests** header at the tracker position. Empty quest sections are omitted.

The party pane shrinks to its contents and expands up to the Objective Tracker height set in Blizzard Edit Mode. Longer lists scroll; there is no separate sidebar height setting.

Ready tags and turn-in text are bright green. Guarded Blizzard tracker refresh defaults on for new or unset preferences; explicit off settings are preserved. It requests redraws only for confirmed numeric mismatches outside combat, checks the result, and pauses after blank or unverifiable results. Settings can disable it.

## Quest-log links

Share now offers **Full log** or **Select quests**. Choose one or more quests, then use **Share to chat** or **Copy Share link** to share those entries and their objective progress. Cancel or Escape restores the original chat draft.

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
