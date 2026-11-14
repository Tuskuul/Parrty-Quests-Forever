Party Quests Forever 1.1.2
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
The tracker sidebar background follows Blizzard Edit Mode's Objective Tracker
opacity setting and its live fonts, text size, outlines, shadows, colors and
scale. Appearance changes apply outside combat without needing a reload.
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
counts and Ready text; sidebar layout changes and new rows wait until combat
ends. Discovery, membership checks and native tracker repair also wait. Client
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
Share opens a popup: choose Full log or Select quests. Select quests lets you
check one or more active quests, then Share selected drafts a link containing
only those quests. Cancel or Escape returns to your original chat draft.
Click Share in the Party Quests tracker header, between its title and Refresh.
Click Share Quest Log in the main Map & Quest Log title bar, left of fullscreen.
It captures your active quests, objective counts/completion and turn-in status,
then inserts a marker at your current chat cursor. Your draft/channel/recipient
are preserved. You choose when to send. Settings also contains the share action.
Recipients with a compatible addon click to view a timestamped, collapsible log.
It is a fixed snapshot, not a live view or lifetime completed-quest history.
The owner must stay online with the addon for a first fetch. Links last fifteen
minutes; the six newest local snapshots are retained. Reload clears published
snapshots. Already received copies remain cached for thirty minutes.

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
