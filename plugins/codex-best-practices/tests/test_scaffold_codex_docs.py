#!/usr/bin/env python3
"""Tests for the Codex best-practices scaffold helper."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path


SCRIPT_PATH = (
    Path(__file__).resolve().parents[1]
    / "skills"
    / "codex-best-practices"
    / "scripts"
    / "scaffold_codex_docs.py"
)

SPEC = importlib.util.spec_from_file_location("scaffold_codex_docs", SCRIPT_PATH)
assert SPEC is not None
scaffold_codex_docs = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(scaffold_codex_docs)


class MakeTargetsTest(unittest.TestCase):
    def test_variable_assignments_are_not_make_targets(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            (root / "Makefile").write_text(
                "\n".join(
                    [
                        "test := pytest",
                        "build = dist",
                        "lint += ruff",
                        "format ?= black",
                        "check != echo ok",
                        "install ::= ./install.sh",
                    ]
                ),
                encoding="utf-8",
            )

            targets = scaffold_codex_docs.make_targets(root)
            commands = scaffold_codex_docs.detect_commands(root)

        self.assertEqual(targets, set())
        self.assertNotIn("make test", commands["test"])
        self.assertNotIn("make build", commands["build"])

    def test_real_make_targets_are_still_detected(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            (root / "Makefile").write_text(
                "\n".join(
                    [
                        "test: unit",
                        "build::",
                    ]
                ),
                encoding="utf-8",
            )

            targets = scaffold_codex_docs.make_targets(root)
            commands = scaffold_codex_docs.detect_commands(root)

        self.assertEqual(targets, {"build", "test"})
        self.assertIn("make test", commands["test"])
        self.assertIn("make build", commands["build"])

    def test_target_specific_variable_assignments_are_not_make_targets(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            (root / "Makefile").write_text(
                "\n".join(
                    [
                        "test: CFLAGS += -g",
                        "build: private LDFLAGS = -lm",
                        "lint: override TOOL := ruff",
                        "typecheck:: CHECK_FLAGS += --strict",
                    ]
                ),
                encoding="utf-8",
            )

            targets = scaffold_codex_docs.make_targets(root)
            commands = scaffold_codex_docs.detect_commands(root)

        self.assertEqual(targets, set())
        self.assertNotIn("make test", commands["test"])
        self.assertNotIn("make build", commands["build"])
        self.assertNotIn("make typecheck", commands["typecheck"])

    def test_gnu_immediate_recursive_assignments_are_not_make_targets(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            (root / "Makefile").write_text(
                "\n".join(
                    [
                        "test :::= $(shell echo test)",
                        "build: VAR :::= $(shell echo build)",
                    ]
                ),
                encoding="utf-8",
            )

            targets = scaffold_codex_docs.make_targets(root)
            commands = scaffold_codex_docs.detect_commands(root)

        self.assertEqual(targets, set())
        self.assertNotIn("make test", commands["test"])
        self.assertNotIn("make build", commands["build"])

    def test_validation_make_targets_are_detected(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            (root / "Makefile").write_text(
                "\n".join(
                    [
                        "lint:",
                        "typecheck:",
                        "format:",
                    ]
                ),
                encoding="utf-8",
            )

            commands = scaffold_codex_docs.detect_commands(root)

        self.assertEqual(commands["lint"], ["make lint"])
        self.assertEqual(commands["typecheck"], ["make typecheck"])
        self.assertEqual(commands["format"], ["make format"])


class PackageRunnerTest(unittest.TestCase):
    def test_bun_lock_takes_precedence_over_legacy_lockfiles(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            (root / "package.json").write_text('{"scripts":{"test":"bun test"}}', encoding="utf-8")
            (root / "bun.lock").write_text("", encoding="utf-8")
            (root / "pnpm-lock.yaml").write_text("", encoding="utf-8")
            (root / "yarn.lock").write_text("", encoding="utf-8")

            commands = scaffold_codex_docs.detect_commands(root)

        self.assertEqual(commands["test"], ["bun run test"])


if __name__ == "__main__":
    unittest.main()
