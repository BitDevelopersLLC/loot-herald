"""Tests for tools/check_game_version.py.  Run:  python -m unittest discover tests"""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "tools"))
import check_game_version as w  # noqa: E402

SAMPLE = """Region!STRING:0|BuildConfig!HEX:16|CDNConfig!HEX:16|KeyRing!HEX:16|BuildId!DEC:4|VersionsName!String:0|ProductConfig!HEX:16
## seqn = 4135569
us|3627b099|3363ac65||70938|1.60.1.70938|0d21f2f2
eu|3627b099|3363ac65||70938|1.60.1.70938|0d21f2f2
"""

TOC = "## Interface: 16001\n## Title: Loot Herald\n"


class WatcherTests(unittest.TestCase):
    def test_parse(self):
        self.assertEqual(w.parse_versions(SAMPLE), {"build": 70938, "version": "1.60.1.70938"})
        self.assertIsNone(w.parse_versions(SAMPLE, region="kr"))
        self.assertIsNone(w.parse_versions(""))

    def test_interface(self):
        self.assertEqual(w.interface_for("1.60.1.70938"), 16001)
        self.assertEqual(w.interface_for("1.15.9.70576"), 11509)
        self.assertEqual(w.interface_for("12.1.5.1"), 120105)

    def test_toc(self):
        self.assertEqual(w.toc_interfaces(TOC), [16001])
        self.assertEqual(w.toc_interfaces("## Interface: 16100, 16001\n"), [16100, 16001])
        bumped = w.bump_toc(TOC, 16100)
        self.assertIn("## Interface: 16100, 16001", bumped)
        self.assertIn("## Title: Loot Herald", bumped)
        self.assertEqual(w.bump_toc(TOC, 16001), TOC)
        self.assertIn("## Interface: 16200, 16100\n", w.bump_toc("## Interface: 16100, 16001\n", 16200))

    def test_decide(self):
        live = {"build": 70938, "version": "1.60.1.70938"}
        self.assertIsNone(w.decide(live, dict(live), [16001]))
        self.assertEqual(w.decide(live, {"build": 70790, "version": "1.60.1.70790"}, [16001]), "build")
        self.assertEqual(w.decide(live, None, [16001]), "build")
        self.assertEqual(w.decide({"build": 71000, "version": "1.61.0.71000"}, live, [16001]), "patch")

    def test_issue_body(self):
        body = w.patch_issue_body("WoW Forever (live)", {"build": 1, "version": "1.61.0.71000"}, 16100)
        self.assertIn("16100", body)
        self.assertIn("ns.DATA_REVIEWED_FOR", body)
        self.assertIn("`1.61.0`", body)


if __name__ == "__main__":
    unittest.main()
