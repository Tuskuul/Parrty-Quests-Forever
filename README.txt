Party Quests Forever 1.1.6-beta8
BETA: Share to chat, Copy Share link and Import for in-game quest snapshots.
For WoW Forever 1.60.1 (interface 16001)

Track party quests beside Blizzard's objective tracker or in a movable,
resizable window. Combine shared quests, inspect each player's available
progress, and organize entries by collapsible players, zones and quest sections.

INSTALL OR UPDATE
Extract SimplyPartyQuests into Interface\AddOns. The final path is:
Interface\AddOns\SimplyPartyQuests\SimplyPartyQuests.toc
Keep that folder name. Existing Simply Party Quests users retain their settings;
this release changes the displayed name, not the saved-variable or addon folder.
Replace files and /reload for an existing installation. A new installation may
need a full client restart before the addon appears in the AddOns list.
Disable the older PoofPartyQuests addon if it is still installed.

QUICK START
Display > Collapse tracker during combat defaults ON, keeps the compact header
visible and restores your prior expanded/collapsed view afterward. Turn it off
to leave the tracker expanded during combat. Changes during combat
apply after combat ends. Focused quest highlighting is retained.
The tracker sidebar background follows Blizzard Edit Mode's Objective Tracker
opacity setting and its live fonts, text size, outlines, shadows, colors and
scale. Appearance changes apply outside combat without needing a reload.
Joined columns use one background. Blizzard's main collapse button controls
both columns; Party Quests toggles the party panel while expanded. Expanding
the compact docked tracker during combat uses a prepared secure click handler.
Click the main +/- or Party Quests button to reopen it. Native layout rebuilds
still wait until combat ends. Player/zone/quest expanders
remain available. An empty native tracker uses one compact party-only control.
Open Esc > Settings > AddOns > Party Quests Forever, or right-click the minimap
button. /spq remains available; /ppq remains an older shortcut.
Choose a left/right tracker sidebar or the separate window. Settings contain
display, grouping, resizing, visibility, refresh and diagnostic controls.
Click player, zone and quest headings to expand/collapse them. Mouse wheel
scrolls long lists. The separate window moves by its title bar and resizes from
its bottom-right corner. The party pane automatically hides when solo; use the
minimap button to open it manually. Left-click toggles, right-click opens settings,
and Shift-click refreshes. Drag the minimap button to reposition it.

QUEST INFORMATION
Progress queries continue during combat. Existing sidebar rows update their
counts and Ready text. Player, zone and quest sections can expand during combat
using known data while the party pane is open, creating rows when needed.
Reopening the automatically collapsed docked tracker works from its buttons.
If a secure click handler is unavailable, expansion queues until combat ends.
Automatic party updates also reflow changed rows during combat. Discovery and
membership checks and native repair still wait. Client
restrictions can still limit the information available during combat.
Ready tags use explicit completion flags or, for native party observations,
complete reported progress matching every known requirement. Unknown or partial
progress is not treated as ready. Your own counts never fill another player's.
Other party members do not need the addon for native discovery. Information is
limited to what Forever exposes; proximity, quest type and client restrictions
can affect completeness and update timing. Cached or unknown progress can occur
when players are distant/offline. Native discovery does not promise every quest
or instant progress. Numeric progress is never guessed from kills or loot chat.
Members with the addon can exchange fuller quest-log snapshots automatically.
Combine shared quests for a single pane with available per-player progress.
Double-click a quest you do not have to check known requirements and request
that its owner share it. A single click expands it. Unknown eligibility sends
nothing; actual quest acceptance and manual sharing remain server/player decisions.

SHARE A QUEST LOG
Choose Full log or Select quests, then choose an action:
- Share to chat prepares the existing short link in your original chat draft.
- Copy Share link shows a string to select and copy with Ctrl+C. Paste it into
  WoW character chat; receivers with this beta or newer can click it. The link
  carries its original owner when forwarded by another character.
- Import opens a box for Ctrl+V. Paste a complete copied string, then Import
  opens the shared-log viewer and requests data from the original owner.
These actions do not send ordinary chat messages automatically. Cancel/Escape
restores your draft and recipient. The Copy screen does not change that draft.
Sharing is available in the party header, map/quest-log header and Settings.
The snapshot includes selected active quests, objective counts/completion and
turn-in status. It is a fixed snapshot, not a live view or lifetime history.
The owner must remain online with the addon for a first fetch. Links last
fifteen minutes, the six newest local snapshots are retained, and reload clears
published snapshots. Received copies remain cached for thirty minutes.
Copied links use character routing and remain subject to the client's whisper
restrictions. Use Share to chat for existing Battle.net snapshot sharing.

WIM character sending/receiving and Battle.net transfer were confirmed in user
testing. Battle.net uses its own addon-data route for cross-faction/realm use;
both players must be online in the same WoW client flavor with this addon.
Cross-faction/cross-realm combinations and every third-party UI build have not
all been verified. Multiple active WoW sessions can select the wrong session;
post a fresh link from the active Forever client if a snapshot is unavailable.
Blizzard-based chat replacements and advertised chat-focus overrides use their
existing editor paths. Independent unsupported chat windows may need adapters.

TROUBLESHOOTING
Use Settings > Open diagnostic report. For stuck snapshot transfers, use
Transfer diagnostics in the shared-log viewer on both sender and recipient.
Basic transfer counters work without enabling broader diagnostic capture.
Reports may contain names, quest IDs and routing IDs; review before sharing.
Include addon/client versions, the affected quest and the other player's addon
version. Detailed capture is optional, bounded, off by default, and kept in memory.
Guarded Blizzard tracker refresh defaults on for new or unset preferences;
explicit off settings remain saved. It requests redraws only for confirmed
numeric mismatches outside combat, verifies the result, and pauses after blank
or unverifiable results. Settings can disable it. /spq report includes details.
Retail, other Classic clients, and raid tracking are not supported.

CREDITS AND LICENSE
Created by Wolfie. Approved project artwork is included; tools/build_icon.py prepares its icon sizes.
Code is distributed under GPLv3. Static fallback data adapts QuestieDB snapshot
0f7d8adc92b28ac6594f4ad8745257f4d9784edf and historic Questie contributions.
Full upstream attribution, licensing statement and historical caveat remain in
third_party. This project is not affiliated with Questie.

BETA8 UPDATES
Compact quest changes are sent between full-log snapshots. Older addon versions
continue receiving full snapshots. Native polling reacts sooner to party quest
events and tooltip cache resolution. Blizzard data availability still varies.
Combat setup no longer adds protected children to native module layout frames.
The selected-quest highlight stays inset from the adjacent tracker pane.
