# 1.0.0 release review

## Prepared

- Party Quests Forever display branding; original internal folder and saved variables preserved.
- 1.0.0-rc1 metadata and copy-ready CurseForge listing.
- Original 512 × 512 project icon plus a 256 × 256 TGA for the addon/minimap.
- GPLv3 text, full upstream QuestieDB notice/caveat and static-data build scripts retained.
- Automated Lua mock suite and archive/layout checks pass.
- User-confirmed WIM send/receive and a Battle.net transfer between 0.16.0 and 0.16.1.
- Stale documentation claiming that the Battle.net transfer is still stalled corrected in the public listing/readme.

## Before the final 1.0.0 upload

1. **Resolve the bundled data licensing position.** The pinned upstream notice allows copying under GPLv3 from the maintainers' perspective but explicitly does not promise every historic contributor's agreement. Retaining notices does not eliminate that caveat. Decide whether to retain this data with a documented redistribution basis, obtain clarification, or replace/remove it. The candidate preserves the existing data; it does not claim the caveat has been cleared.
2. Install this candidate and check the renamed AddOns/settings entry, original minimap icon, and saved preferences. Repeat one party snapshot and one chat snapshot test after the branding-only change.
3. Capture two current screenshots: party tracker with expanded progress, and the shared-log viewer. Existing screenshots in the conversation are historical and have not been copied into this package as current release screenshots.
4. Check name/slug availability, enable a feedback channel, and select Forever/1.60.1. No invented project ID or issue URL is included.
5. After review, prepare final 1.0.0 metadata/file as **Release**. CurseForge's guide says a project needs at least one Release file to sync to the app by default; an RC/Beta alone does not establish that.

## Verification limits

The automated suite uses mocked Lua APIs, not a live WoW client. The user confirmed normal WIM send/receive and Battle.net transport; this is not blanket verification of every WIM/UI version, client build, remote objective update, or cross-faction/realm pair. Those practical limitations are reflected in the public description.
