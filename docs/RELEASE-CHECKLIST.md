# Party Quests Forever 1.1.6-beta16 beta build record

Baseline: beta15, 297a953049cb601f216cab3df9c1d2dbbfdfef98.

Reported failure: Copy Share link pasted into Battle.net no longer worked.
The native Battle.net filter only recognized the original bare Log marker.
Copied markers include original publisher hex and were neither converted into
links nor bound to Battle.net transport by that filter.

Changes:
- Parse copied Log markers in the native Battle.net filter. Match the encoded
  publisher against the friend's available character/realm before selecting its
  game-account data route. Preserve publisher separately from transport identity.
- Forwarded markers stay with their original character. Conflicting token
  publishers/purposes are rejected. Old bare Log markers remain supported.
- Import/character re-observation of a Battle.net copy preserves its route.
- Copied Offer markers can render in Battle.net text while retaining character
  routing, same-party restrictions and purpose. No new external-party shares.
- Add a parchment destination popup for Current chat / whisper, Party, Guild,
  Say, Yell and native GetChannelList triples. Disabled/missing destinations
  cannot draft; channel number AND name are rechecked on selection.
- New public drafts use Blizzard's editor and clear whisper/channel targets.
  They never copy private captured text and refuse to overwrite existing text.
  Public-draft preflight occurs before snapshot creation to avoid evicting links
  on failed attempts. Current chat retains existing captured WIM/BNet behavior.
- Choosing a destination prepares a message for Enter; no automatic chat send.
  Cancel, reopen and commit preserve/finish original chooser state once.

Native reference: Gethe/wow-ui-source at
bebcb6bf309cf41b41bd74f8ca651e6a105b2676,
Blizzard_ChatFrameBase/Shared/ChatFrameUtil.lua:
OpenChat can redirect through CHAT_FOCUS_OVERRIDE, so public destinations instead
choose a Blizzard edit box, reject custom overrides, activate the editor and set
explicit chatType/stickyType/channelTarget while clearing tellTarget.

Validation target: 26 source files parse; 21 Lua regression suites; 7 auto-tag
tests. Added quest-chat-routing.lua covers copied BNet rendering/reassembly,
original markers, Import route preservation, forwarded/conflicting publishers,
offer-purpose preservation, channel membership/ID reuse, no auto-send, private
and occupied drafts, and destination popup cancel/reopen/commit. Existing sharing
UI test now chooses Current chat after opening the new popup.

No local executor is available for this change. GitHub Actions executes the
actual regression suites before automatic tagging; do not claim a pass until
the matching commit's run succeeds. Actual WoW/Battle.net behavior still needs
live validation.

Live checks:
1. Copy full/selected log to a Battle.net friend, click on receiver and inspect
   /spq report on both clients. Expect a BN data route and snapshot-complete.
2. Forward a copied link; its original publisher must not change.
3. Share to chat: verify Party/Guild enablement, Say/Yell and joined channels.
   Confirm channel header/number before pressing Enter; no send on selection.
4. Cancel returns to the prior scope/selection; Current chat preserves WIM/BNet.
5. Test an existing public draft and a private draft; neither may be overwritten
   or moved into a public channel.
6. Leave a numbered channel while the popup is open, then choose its old row:
   reject stale selection instead of targeting a reused channel number.

No raid support, stable promotion, eligibility or TTL changes. Keep main at 1.1.5.
