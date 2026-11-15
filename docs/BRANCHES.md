# Repository branches

- `main` contains the current stable release.
- `beta` contains active testing builds and their fixes.
- New beta versions and bug fixes go to `beta`; stable promotion updates the version metadata and changelog before integration into `main`.
- Both branches retain the `SimplyPartyQuests` install folder and `SimplyPartyQuestsDB` saved settings.
- Run `python3 run_checks.py` from the repository root before packaging or promotion.
- CurseForge uploads remain manual. These branches do not automatically publish files.

The branch split preserved all existing commits. A stable-source restoration commit on `main` is followed by a beta-source continuation commit on `beta`, so future beta work can merge forward from the stable baseline without losing the testing changes.
