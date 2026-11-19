# Party Quests Forever 1.1.7-beta1 build record

Promoted the alpha6 Questie compatibility source to beta after 1.1.6 stable promotion. Tracker/gameplay logic is unchanged from alpha6; settings initialization now uses the established SimplyPartyQuestsDB instead of the isolated alpha table. The TOC retains both saved-variable declarations so prior alpha settings survive beta logout. Beta does not import or alter the alpha table. Questie remains optional.

User-reported alpha6 live evidence: client 1.60.1 build 70959, Questie 12.11.0 maps-only, party of four; three combat exits; no recorded blocked actions, cleanup errors or progress-processing errors. User reports counters working properly. Questie tracker-enabled mode and wider addon/class/zone combinations still need beta coverage; full compatibility is not claimed.

Validation: all Lua syntax/regressions and automatic-tag tests, including normal beta settings retention with an existing alpha table. Existing map-marker clipboard taint is not claimed fixed. Native combat controls remain paused with Questie loaded. Guarded native-call handling does not repair an already-tainted session; reload after installation.
