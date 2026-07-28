#!/usr/bin/env python3
"""Tests for the Call Notes provider integration."""

from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "plugins" / "call-notes" / "scripts" / "call_notes.py"
SPEC = importlib.util.spec_from_file_location("call_notes_under_test", SCRIPT)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"Could not load {SCRIPT}")
call_notes = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = call_notes
SPEC.loader.exec_module(call_notes)


class CallNotesProviderTest(unittest.TestCase):
    def test_uses_current_quo_api_base(self) -> None:
        self.assertEqual("https://api.quo.com/v1", call_notes.QUO_API_BASE)

    def test_provider_requests_use_current_quo_host_and_v1_paths(self) -> None:
        person = call_notes.Person(
            name="Jane Smith",
            company="Acme",
            role="Buyer",
            phone="+13035550100",
            email="jane@example.com",
            notes="",
        )

        with mock.patch.object(call_notes, "api_get_json", return_value={"data": []}) as api_get:
            call_notes.list_phone_numbers("secret")
            call_notes.list_calls_for_person("secret", "PN123", person, None, None, 20)
            call_notes.get_call("secret", "AC123")
            call_notes.get_recordings("secret", "AC123")

        urls = [call.args[0] for call in api_get.call_args_list]
        self.assertEqual(
            [
                "https://api.quo.com/v1/phone-numbers",
                "https://api.quo.com/v1/calls",
                "https://api.quo.com/v1/calls/AC123",
                "https://api.quo.com/v1/call-recordings/AC123",
            ],
            urls,
        )
        self.assertFalse(any("/v0" in url or "api.openphone.com" in url for url in urls))


if __name__ == "__main__":
    unittest.main()
