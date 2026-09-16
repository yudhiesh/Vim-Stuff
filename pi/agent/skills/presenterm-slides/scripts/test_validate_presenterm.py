#!/usr/bin/env python3
"""Regression tests for validate_presenterm.py."""

from __future__ import annotations

import contextlib
import io
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import validate_presenterm  # noqa: E402


class ValidatePresentermTests(unittest.TestCase):
    def run_validator(self, deck: Path) -> tuple[int, str]:
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            status = validate_presenterm.validate(deck)
        return status, output.getvalue()

    def write_deck(self, root: Path, content: str) -> Path:
        deck = root / "deck.md"
        deck.write_text(content)
        return deck

    def test_ignores_escaped_inline_and_comment_images(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            deck = self.write_deck(
                Path(directory),
                r"\![escaped](missing.png) `![inline](missing.png)` <!-- ![comment](missing.png) -->",
            )
            status, output = self.run_validator(deck)
            self.assertEqual(status, 0, output)

    def test_checks_frontmatter_images_with_yaml_comments(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            deck = self.write_deck(
                Path(directory),
                textwrap.dedent(
                    """---
                    theme:
                      override:
                        footer:
                          left:
                            image: missing.png # checked
                    ---
                    Content
                    """
                ),
            )
            status, output = self.run_validator(deck)
            self.assertEqual(status, 1)
            self.assertIn("missing image missing.png", output)

    def test_reports_unclosed_frontmatter(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            deck = self.write_deck(Path(directory), "---\ntitle: Broken\n\nContent\n")
            status, output = self.run_validator(deck)
            self.assertEqual(status, 1)
            self.assertIn("unclosed front matter delimiter", output)

    def test_normalizes_reference_labels(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "diagram.png").touch()
            deck = self.write_deck(root, "![diagram][  hero   image ]\n\n[hero image]: diagram.png\n")
            status, output = self.run_validator(deck)
            self.assertEqual(status, 0, output)

    def test_validates_included_decks_and_detects_cycles(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "diagram.png").touch()
            child = root / "child.md"
            child.write_text("![diagram](diagram.png)\n")
            deck = self.write_deck(root, "<!-- include: child.md -->\n")
            status, output = self.run_validator(deck)
            self.assertEqual(status, 0, output)

            child.write_text("<!-- include: deck.md -->\n")
            status, output = self.run_validator(deck)
            self.assertEqual(status, 1)
            self.assertIn("include cycle detected", output)

    def test_reports_missing_includes(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            deck = self.write_deck(Path(directory), "<!-- include: missing.md -->\n")
            status, output = self.run_validator(deck)
            self.assertEqual(status, 1)
            self.assertIn("No such file", output)


if __name__ == "__main__":
    unittest.main()
