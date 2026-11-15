# Automatic version tags

Pushes to `beta` and `main` run Lua syntax/regression checks and the automatic
tagging tests. Successful runs read `SimplyPartyQuests.toc` and create the missing
version tag at the exact checked commit. The built-in GitHub Actions token supplies
repository access; no extra token or CurseForge secret belongs in this workflow.

- `beta` requires `X.Y.Z-betaN`; `main` requires `X.Y.Z`.
- Existing tags are never moved or overwritten. Bump the version for another build.
- Diagnostics must report the same version as the TOC.
- Stable pushes publish only when the version changes, so installing this workflow
  does not republish the existing stable release. A manual Actions run may tag a
  missing version without that change check.
- Stale runs skip tagging if their branch has advanced during checks.
- The workflow listens to branch pushes, not tag pushes, so tagging does not loop.
- A new tag is intended to trigger the configured external CurseForge webhook.
  Check the first automatic tag's delivery and the CurseForge Files page to verify
  the complete route. Tag creation itself does not confirm CurseForge approval.

The Actions tab also offers Run workflow for an explicit retry on either branch.
Workflow failures appear there. If tag writes are denied, check repository Actions
permissions and tag rules; this workflow does not bypass protected tags.
