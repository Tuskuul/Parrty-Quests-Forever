Party Quests Forever 1.1.10-beta2
For WoW Forever 1.60.1 (interface 16001)

Track party quests beside the active quest tracker or in a movable, resizable
window. Compare available progress, combine shared quests and group by zone.

INSTALL OR UPDATE
Place SimplyPartyQuests in Interface\AddOns. Keep the folder name:
Interface\AddOns\SimplyPartyQuests\SimplyPartyQuests.toc
Install one version at a time, then /reload. A new installation may need a full
client restart. Normal settings use SimplyPartyQuestsDB; old alpha settings
remain separate and are not imported or overwritten.

CONTROLS
Open Settings from /spq or minimap right-click. Minimap left-click toggles the
party pane; Shift-click refreshes. Drag the minimap button to reposition it.
Settings > Display chooses Beside the active quest tracker or Separate window.
Tracker layout chooses Side by Side or Tabbed.
Tabs apply to the default Blizzard tracker; Questie retains its sidebar. Combat
switches queue until combat ends. Side-by-side placement selects left/right and
width. Refresh rebuilds roster/discovery and requests full addon logs, with
Working/Queued labels and chat results. Settings > Quests controls shared
quest combining, zone grouping and double-click share requests.
Click player, zone and quest headings to expand them. Mouse wheel scrolls.
The separate window moves by its title and resizes from its bottom-right corner.
Its action row has Share and Refresh; preference controls are in Settings.
The pane normally hides while solo; open it manually with the minimap button.

QUESTIE DOCKING
With Questie's tracker enabled, sidebar mode docks our independent pane beside
it and follows position, size, scale and backdrop opacity, including fades.
The Party Quests heading and +/- control collapse our pane; right-click the
heading or use ... for Share, Refresh and Settings. Questie's own controls are
unchanged. Solo view starts compact, but + can open the empty-party view.
Our previous view returns after combat. Native Blizzard combat controls stay
paused while Questie is loaded. With Questie's tracker disabled, the Blizzard
sidebar is used. Hidden/unavailable Questie trackers fall back to our window.

PROGRESS AND COMBAT
Members with this addon exchange full logs and small progress updates. Without
it, discovery and progress depend on native tooltip/API information; unknown
counts stay unknown. Different zones and client restrictions can limit data.
Collapse during combat is enabled by default and restores your previous view.
The party pane can reopen during combat using prepared or independent controls;
new discovery, membership changes and native repairs may wait until combat ends.
Mode changes and Settings requests made during combat are queued afterward.
Refresh party quests queries party data; it does not force a Blizzard redraw.
Raid tracking and other WoW client flavors are not supported.

QUEST LOGS AND QUEST OFFERS
Open Share from the tracker, Questie ... menu, separate window or Settings >
Tools. There is no Party Quests button on the map.
Full log and Select quests choose the snapshot contents. Share to chat offers
Current chat/whisper, Party, Guild, Say, Yell and joined channels, preparing a
link for Enter to send. Existing chat drafts and recipient routing are preserved.
Copy Share link shows selectable text for Ctrl+C. Import accepts a copied string
with Ctrl+V and requests the snapshot from its original owner.
Snapshots include quest counts/completion and turn-in state, not live progress
or lifetime completion history. Links last 15 minutes. The owner must remain
online with the addon for a first fetch; reload clears published snapshots.
WIM and Battle.net routes are supported where the client exposes them. Some
cross-faction/realm/session combinations remain client-dependent.
Open shareable offers quests from your log that recent party logs show missing.
Both players need the addon and must stay in the same party. Recipients click a
quest to request its normal share; combat/client restrictions may require owner
confirmation. Known level, prerequisite and log-capacity failures show an
eligibility reason; uncertain rules leave the final decision to the client.

APPEARANCE AND TROUBLESHOOTING
Parchment brightness is under Settings > Quest windows and updates live.
Use Show troubleshooting > Open diagnostic report, or /spq report. Detailed
capture uses /spq diag on and /spq diag off. Reports may include player names
and quest IDs; review before sharing. Transfer diagnostics in the received-log
window can help troubleshoot sharing on both sides.
Blizzard stale-count repair is shown only when applicable, preserves your saved
preference, waits until outside combat and checks confirmed mismatches. It
pauses after blank/unverifiable results. It is separate from Refresh party quests.
The older /ppq alias remains supported. /spq inspect, demo and clear are available
for troubleshooting. See CHANGELOG.txt for development/release history.

CREDITS AND LICENSE
Created by Wolfie. Code is GPLv3. Static fallback data adapts QuestieDB snapshot
0f7d8adc92b28ac6594f4ad8745257f4d9784edf and historic Questie contributions.
Full upstream attribution, licensing statement and contributor caveat remain
in third_party. This project is not affiliated with Questie. The in-game icon is
included; full-resolution promotional artwork remains in the GitHub repository.
