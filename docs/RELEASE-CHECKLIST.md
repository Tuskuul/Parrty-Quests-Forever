# Party Quests Forever 1.1.6-beta15 beta build record

Baseline: beta14, 76e403788c53928efc0cb36c4bd64e0311e56fa1.

User approved a parchment mockup and explicitly requested the same visual
language for all share windows: chooser, received logs/offers, Copy/Import and
owner confirmation. Implement with native client artwork and font objects,
without inheriting native quest-acceptance scripts or changing Blizzard frames.

Changes:
- Add QuestDialogStyle.lua before all sharing UI files in the TOC. Common paper
  fill, dark ink palette, gold titles and screen clamping apply once per dialog.
- Use QuestBG-Parchment when the atlas exists. Otherwise crop the native classic
  QuestGreeting text area. A warm opaque base avoids transparent background gaps.
- Hide the template's decorative Inset/InsetBg fills, preserving native trim.
- Highlight the current Full log / Select quests / Open shareable mode.
- Use dark green completion markers and dark brown quest/body text. Keep native
  red button controls and a contrasting, bordered Copy/Import field.
- Offer rows have native quest icons/dividers; known eligibility failures show a
  muted title with red reason text below. Row height includes wrapped reason text.
- Reused rows clear icons, dividers, reason text and hover handlers when moving
  between offers and normal log objectives; eligibility recheck behavior remains.
- Preserve drag/copy/paste/chat draft/cancel/import/request behavior. Full-log
  chooser gets 12 additional pixels of vertical room for its introductory text.

Native source references, pinned to Gethe/wow-ui-source
bebcb6bf309cf41b41bd74f8ca651e6a105b2676:
- Blizzard_UIPanels_Game/Mainline/QuestFrameTemplates.xml: QuestBG-Parchment.
- Blizzard_UIPanels_Game/Vanilla/QuestFrameTemplates.xml: greeting artwork,
  available quest list fonts and UI-QuestTitleHighlight.
- Blizzard_UIPanelTemplates/Mainline/UIPanelTemplates.xml: BasicFrameTemplate
  background sublevels and BasicFrameTemplateWithInset's InsetBg/inner borders.

Validation: 25 source files parse; 20 existing Lua regression suites pass;
7 auto-tag tests pass. Sharing test harnesses now load the production theme.
The existing recipient eligibility test also checks visible inline reason text
and its removal after a level change, preventing stale pooled-row failure text.
No new test suite for purely cosmetic color/texture constants.

Live visual checks after installing beta15:
1. Open Full log, Select quests and Open shareable. Check paper, selected mode,
   list scrolling, checkbox hit areas, wrapped titles and footer clearance.
2. Open a received full/selected log, then an offer. Check expanded objectives,
   green completion text, native icons, grey unavailable title and red reason.
3. Reuse the received viewer for a normal log: no stale offer icons/reasons.
4. Copy and Import: verify visible field, placeholder, Ctrl+C/Ctrl+V, focus,
   cancel/return, committed import and preserved chat draft/selection.
5. Trigger owner confirmation, including combat deferral. Check contrast and
   normal Share/Dismiss controls. Check native asset rendering and UI scaling.

Appearance was not rendered in an actual WoW client here; the approved generated
mockup is a style target, not proof of exact live pixel layout. No protocol,
eligibility, TTL, raid support or native tracker changes. Keep main at 1.1.5.
