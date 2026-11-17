#!/usr/bin/env python3
"""Publish a missing version tag after the workflow's regression checks pass."""
import argparse
import os
from pathlib import Path
import re
import subprocess
import sys

TOC = "SimplyPartyQuests.toc"


def git(*args, check=True):
    return subprocess.run(["git", *args], text=True, capture_output=True, check=check)


def version_from(text):
    versions = re.findall(r"^## Version:\s*(\S+)\s*$", text, re.MULTILINE)
    if len(versions) != 1:
        raise ValueError("The TOC must contain exactly one Version field.")
    return versions[0]


def report(message):
    print(message)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as out:
            out.write(message + "\n")


def remote_ref(ref):
    result = git("ls-remote", "--exit-code", "origin", ref, check=False)
    if result.returncode == 2:
        return None
    if result.returncode:
        raise ValueError("Cannot read remote refs; no tag was published.")
    lines = [line.split() for line in result.stdout.splitlines()]
    matches = [sha for sha, name in lines if name == ref]
    if len(matches) != 1:
        raise ValueError("Remote ref is ambiguous; no tag was published.")
    return matches[0]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--branch", required=True, choices=("main", "beta", "alpha"))
    parser.add_argument("--commit", required=True)
    parser.add_argument("--previous", default="")
    args = parser.parse_args()
    if not re.fullmatch(r"[0-9a-f]{40}", args.commit):
        raise ValueError("Expected a full commit SHA.")
    if git("rev-parse", "HEAD").stdout.strip() != args.commit:
        raise ValueError("Checkout differs from the checked commit.")
    version = version_from(Path(TOC).read_text(encoding="utf-8"))
    pattern = r"\d+\.\d+\.\d+" + ("" if args.branch == "main" else "-" + args.branch + r"[1-9]\d*")
    if not re.fullmatch(pattern, version):
        raise ValueError("Version must be X.Y.Z on main, X.Y.Z-betaN on beta or X.Y.Z-alphaN on alpha.")
    diagnostic = Path("LiveProgress.lua").read_text(encoding="utf-8")
    if '"Party Quests Forever ' + version + '"' not in diagnostic:
        raise ValueError("Diagnostic and TOC versions do not match.")
    tag_ref = "refs/tags/" + version
    if remote_ref(tag_ref):
        report(f"Tag {version} already exists; left unchanged.")
        return
    # Installing this workflow on an existing stable release must not upload
    # that same release again. Stable pushes publish only on a version change.
    if args.branch == "main" and args.previous:
        if not re.fullmatch(r"[0-9a-f]{40}", args.previous):
            raise ValueError("Expected a full previous commit SHA.")
        previous = version_from(git("show", args.previous + ":" + TOC).stdout)
        if previous == version:
            report(f"Stable version {version} is unchanged; no tag created.")
            return
    if remote_ref("refs/heads/" + args.branch) != args.commit:
        report("Branch advanced during checks; leaving tagging to the newer run.")
        return
    git("tag", "--no-sign", "--", version, args.commit)
    pushed = git("push", "origin", tag_ref + ":" + tag_ref, check=False)
    if pushed.returncode:
        # Another run can win the race. Never force or move an existing tag.
        if remote_ref(tag_ref):
            report(f"Tag {version} was created by another run; left unchanged.")
            return
        raise ValueError("Tag push failed; check repository Actions write permissions.")
    report(f"Published {version} from {args.branch} at {args.commit}.")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f"Auto-tag failed: {error}", file=sys.stderr)
        sys.exit(1)
