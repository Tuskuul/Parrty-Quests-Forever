import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "tools" / "auto_tag.py"


class AutoTagTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.origin = self.root / "origin.git"
        self.repo = self.root / "checkout"
        subprocess.run(["git", "init", "--bare", str(self.origin)], check=True, capture_output=True)
        subprocess.run(["git", "init", "-b", "beta", str(self.repo)], check=True, capture_output=True)
        self.git("config", "user.name", "Auto-tag test")
        self.git("config", "user.email", "test@example.invalid")
        self.git("remote", "add", "origin", str(self.origin))
        self.sha = self.commit("1.1.6-beta2")
        self.git("push", "origin", "HEAD:refs/heads/beta")

    def git(self, *args):
        return subprocess.run(["git", *args], cwd=self.repo, text=True, capture_output=True, check=True).stdout.strip()

    def commit(self, version, diagnostic=None):
        (self.repo / "SimplyPartyQuests.toc").write_text("## Version: " + version + "\n")
        (self.repo / "LiveProgress.lua").write_text('return "Party Quests Forever ' + (diagnostic or version) + '"\n')
        self.git("add", ".")
        self.git("commit", "--allow-empty", "-m", "test " + version)
        return self.git("rev-parse", "HEAD")

    def run_tag(self, branch="beta", sha=None, previous=""):
        env = dict(os.environ, GITHUB_STEP_SUMMARY=str(self.root / "summary"))
        return subprocess.run([sys.executable, str(SCRIPT), "--branch", branch,
                               "--commit", sha or self.sha, "--previous", previous],
                              cwd=self.repo, env=env, text=True, capture_output=True)

    def remote_tag(self, name):
        return self.git("ls-remote", "origin", "refs/tags/" + name)

    def test_beta_tag_and_repeat_do_not_move_existing_tag(self):
        result = self.run_tag()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.remote_tag("1.1.6-beta2").startswith(self.sha))
        newer = self.commit("1.1.6-beta2")
        self.git("push", "origin", "HEAD:refs/heads/beta")
        result = self.run_tag(sha=newer)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("already exists", result.stdout)
        self.assertTrue(self.remote_tag("1.1.6-beta2").startswith(self.sha))

    def test_alpha_tag_is_isolated_from_beta_and_main(self):
        sha = self.commit("1.1.7-alpha1")
        self.git("push", "origin", "HEAD:refs/heads/alpha")
        result = self.run_tag("alpha", sha)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.remote_tag("1.1.7-alpha1").startswith(sha))
        self.assertEqual(self.git("rev-parse", "origin/beta"), self.sha)
        self.assertNotEqual(self.run_tag("beta", sha).returncode, 0)
        self.assertNotEqual(self.run_tag("main", sha).returncode, 0)

    def test_stable_version_bump_tags_main(self):
        old = self.commit("1.1.5")
        newer = self.commit("1.1.6")
        self.git("push", "origin", "HEAD:refs/heads/main")
        result = self.run_tag("main", newer, old)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.remote_tag("1.1.6").startswith(newer))

    def test_workflow_install_does_not_republish_unchanged_stable(self):
        old = self.commit("1.1.5")
        newer = self.commit("1.1.5")
        self.git("push", "origin", "HEAD:refs/heads/main")
        result = self.run_tag("main", newer, old)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.remote_tag("1.1.5"), "")

    def test_branch_advance_skips_old_run(self):
        newer = self.commit("1.1.6-beta3")
        self.git("push", "origin", "HEAD:refs/heads/beta")
        self.git("checkout", self.sha)
        result = self.run_tag()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("advanced", result.stdout)
        self.assertEqual(self.remote_tag("1.1.6-beta2"), "")

    def test_stable_on_beta_and_beta_on_main_are_rejected(self):
        for branch, version in [("beta", "1.1.6"), ("main", "1.1.6-beta3")]:
            sha = self.commit(version)
            self.assertNotEqual(self.run_tag(branch, sha).returncode, 0)
            self.assertEqual(self.remote_tag(version), "")

    def test_mismatched_diagnostics_and_checkout_are_rejected(self):
        sha = self.commit("1.1.6-beta3", "1.1.6-beta2")
        self.assertNotEqual(self.run_tag(sha=sha).returncode, 0)
        self.assertNotEqual(self.run_tag(sha=self.sha).returncode, 0)
        self.assertEqual(self.remote_tag("1.1.6-beta3"), "")

    def test_unavailable_remote_fails_closed(self):
        self.git("remote", "set-url", "origin", str(self.root / "missing.git"))
        self.assertNotEqual(self.run_tag().returncode, 0)


if __name__ == "__main__":
    unittest.main()
