#!/usr/bin/env python3
"""Tests for the local plugin installer."""

from __future__ import annotations

import os
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "install-agent-plugins.sh"


class InstallAgentPluginsTest(unittest.TestCase):
    def test_prompt_builder_rename_removes_legacy_config_and_cache(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            sandbox = Path(tmpdir)
            codex_home = sandbox / "codex-home"
            config_path = codex_home / "config.toml"
            legacy_cache = codex_home / "plugins/cache/wgj/goal-prompt-builder/0.1.0"
            fake_bin = sandbox / "bin"
            fake_bin.mkdir()
            legacy_cache.mkdir(parents=True)
            config_path.parent.mkdir(parents=True, exist_ok=True)
            config_path.write_text(
                textwrap.dedent(
                    """
                    [features]
                    plugins = true

                    [plugins."goal-prompt-builder@wgj"]
                    enabled = true

                    [plugins."contacts@wgj"]
                    enabled = false
                    """
                ).lstrip(),
                encoding="utf-8",
            )
            (fake_bin / "codex").write_text(
                textwrap.dedent(
                    """\
                    #!/usr/bin/env bash
                    set -euo pipefail
                    if [ "$1 $2 $3" = "plugin marketplace add" ]; then
                      printf 'Marketplace root: %s\\n' "$4"
                      exit 0
                    fi
                    printf 'unexpected codex invocation: %s\\n' "$*" >&2
                    exit 1
                    """
                ),
                encoding="utf-8",
            )
            (fake_bin / "codex").chmod(0o755)

            env = {
                **os.environ,
                "PATH": f"{fake_bin}{os.pathsep}{os.environ['PATH']}",
                "CODEX_BIN": str(fake_bin / "codex"),
                "CODEX_HOME": str(codex_home),
                "AGENT_PLUGINS_MARKETPLACE_SOURCE": str(ROOT),
                "AGENT_PLUGINS_MARKETPLACE_REF": "",
            }
            subprocess.run(
                [str(SCRIPT)],
                cwd=ROOT,
                env=env,
                check=True,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )

            config = config_path.read_text(encoding="utf-8")
            legacy_cache_exists = (codex_home / "plugins/cache/wgj/goal-prompt-builder").exists()

            self.assertNotIn("goal-prompt-builder@wgj", config)
            self.assertFalse(legacy_cache_exists)
            self.assertIn('[plugins."prompt-builder@wgj"]', config)
            self.assertIn('[plugins."contacts@wgj"]', config)

    def test_reports_missing_codex_executable(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            missing_codex = Path(tmpdir) / "missing-codex"
            result = subprocess.run(
                [str(SCRIPT)],
                cwd=ROOT,
                env={**os.environ, "CODEX_BIN": str(missing_codex)},
                check=False,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )

            self.assertEqual(1, result.returncode)
            self.assertIn("Codex executable is not available", result.stderr)


if __name__ == "__main__":
    unittest.main()
