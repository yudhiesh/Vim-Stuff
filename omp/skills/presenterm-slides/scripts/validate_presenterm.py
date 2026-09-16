#!/usr/bin/env python3
"""Small, dependency-free structural check for a presenterm Markdown deck."""

from __future__ import annotations

import argparse
import ast
import re
import sys
from pathlib import Path

END_SLIDE = "<!-- end_slide -->"
FENCE = re.compile(r"^\s*(`{3,}|~{3,})")
IMAGE = re.compile(
    r"(?<!\\)!\[[^\]]*\]\(\s*(?:<([^>]+)>|([^\s)]+))(?:\s+(?:\"[^\"]*\"|'[^']*'|\([^)]*\)))?\s*\)"
)
REFERENCE_IMAGE = re.compile(r"(?<!\\)!\[([^\]]*)\]\s*\[([^\]]*)\]")
SHORTCUT_IMAGE = re.compile(r"(?<!\\)!\[([^\]]+)\](?!\s*[\[(])")
REFERENCE_DEF = re.compile(
    r"^\s{0,3}\[([^\]]+)\]:\s*(?:<([^>]+)>|([^\s]+))(?:\s+(?:\"[^\"]*\"|'[^']*'|\([^)]*\)))?\s*$"
)
THEME_IMAGE = re.compile(
    r"^\s+image:\s*(?:<([^>]+)>|'([^']+)'|\"([^\"]+)\"|(\S+?))(?:\s+#.*)?\s*$"
)
INCLUDE = re.compile(r"^<!--\s*include:\s*(.*?)\s*-->$")
HTML_COMMENT = re.compile(r"<!--.*?-->")
INLINE_CODE = re.compile(r"`+[^`]*?`+")
LAYOUT = re.compile(r"<!--\s*column_layout:\s*(.*?)\s*-->")
COLUMN = re.compile(r"<!--\s*column:\s*(\d+)\s*-->")
RESET = re.compile(r"<!--\s*reset_layout\s*-->")


def normalize_reference_key(value: str) -> str:
    return " ".join(value.split()).casefold()


def mask_non_content(line: str) -> str:
    """Hide inline code and HTML comments before looking for Markdown images."""

    line = HTML_COMMENT.sub(lambda match: " " * len(match.group()), line)
    return INLINE_CODE.sub(lambda match: " " * len(match.group()), line)


def read_slides(lines: list[str]) -> tuple[list[list[tuple[int, str]]], list[str]]:
    slides: list[list[tuple[int, str]]] = []
    current: list[tuple[int, str]] = []
    errors: list[str] = []
    fence: tuple[str, int, int] | None = None

    for number, line in enumerate(lines, 1):
        stripped = line.strip()
        match = FENCE.match(line)
        if fence is None and match:
            marker = match.group(1)
            fence = (marker[0], len(marker), number)
        elif fence is not None:
            char, length, _ = fence
            if stripped and set(stripped) == {char} and len(stripped) >= length:
                fence = None

        if fence is None and stripped == END_SLIDE:
            slides.append(current)
            current = []
        else:
            current.append((number, line.rstrip("\n")))

    if fence is not None:
        errors.append(f"line {fence[2]}: unclosed {fence[0] * fence[1]} fence")
    if current:
        slides.append(current)
    return slides, errors


def collect_references(lines: list[str]) -> dict[str, str]:
    references: dict[str, str] = {}
    fence: tuple[str, int] | None = None
    html_comment = False
    for line in lines:
        stripped = line.strip()
        match = FENCE.match(line)
        if fence is None and match:
            marker = match.group(1)
            fence = (marker[0], len(marker))
            continue
        if fence is not None:
            char, length = fence
            if stripped and set(stripped) == {char} and len(stripped) >= length:
                fence = None
            continue
        if html_comment:
            if "-->" in line:
                html_comment = False
            continue
        if stripped.startswith("<!--"):
            if "-->" not in stripped:
                html_comment = True
            continue
        match = REFERENCE_DEF.match(line)
        if match:
            references[normalize_reference_key(match.group(1))] = (match.group(2) or match.group(3)).strip()
    return references


def collect_includes(lines: list[str]) -> list[tuple[int, str]]:
    includes: list[tuple[int, str]] = []
    fence: tuple[str, int] | None = None
    html_comment = False
    for number, line in enumerate(lines, 1):
        stripped = line.strip()
        match = FENCE.match(line)
        if fence is None and match:
            marker = match.group(1)
            fence = (marker[0], len(marker))
            continue
        if fence is not None:
            char, length = fence
            if stripped and set(stripped) == {char} and len(stripped) >= length:
                fence = None
            continue
        if html_comment:
            if "-->" in line:
                html_comment = False
            continue
        match = INCLUDE.fullmatch(stripped)
        if match:
            target = match.group(1).strip()
            if len(target) >= 2 and target[0] == target[-1] and target[0] in "'\"":
                target = target[1:-1]
            includes.append((number, target))
            continue
        if stripped.startswith("<!--") and "-->" not in stripped:
            html_comment = True
    return includes


def frontmatter_lines(lines: list[str]) -> set[int]:
    if not lines or lines[0].strip() != "---":
        return set()
    for index, line in enumerate(lines[1:], 2):
        if line.strip() == "---":
            return set(range(1, index + 1))
    return set()


def validate(path: Path, include_stack: tuple[Path, ...] = ()) -> int:
    display_path = path
    resolved_path = path.resolve()
    if resolved_path in include_stack:
        print(f"ERROR {display_path}: include cycle detected")
        return 1

    errors: list[str] = []
    try:
        lines = path.read_text().splitlines(keepends=True)
    except OSError as exc:
        print(f"ERROR {display_path}: {exc}")
        return 1

    slides, parse_errors = read_slides(lines)
    errors.extend(parse_errors)
    references = collect_references(lines)
    frontmatter = frontmatter_lines(lines)
    if lines and lines[0].strip() == "---" and not frontmatter:
        errors.append("unclosed front matter delimiter")

    def check_image(line_number: int, target: str) -> None:
        target = target.strip()
        if target.startswith(("http://", "https://", "data:", "#")):
            errors.append(f"line {line_number}: image must be a local path, not {target[:80]}")
            return
        target_path = (path.parent / target).resolve()
        if not target_path.is_file():
            errors.append(f"line {line_number}: missing image {target}")

    if not slides:
        errors.append("deck has no slides")

    for _, slide in enumerate(slides, 1):
        weights: list[int] | None = None
        current_column: int | None = None
        needs_column = False
        fence: tuple[str, int] | None = None
        html_comment = False
        for line_number, line in slide:
            stripped = line.strip()
            match = FENCE.match(line)
            if fence is None and match:
                marker = match.group(1)
                fence = (marker[0], len(marker))
                continue
            if fence is not None:
                char, length = fence
                if stripped and set(stripped) == {char} and len(stripped) >= length:
                    fence = None
                continue
            if html_comment:
                if "-->" in line:
                    html_comment = False
                continue
            starts_comment = stripped.startswith("<!--")
            if starts_comment and "-->" not in stripped:
                html_comment = True

            layout = LAYOUT.search(line)
            if layout:
                try:
                    parsed = ast.literal_eval(layout.group(1))
                    if not isinstance(parsed, list) or not parsed or any(
                        type(value) is not int or not 1 <= value <= 255 for value in parsed
                    ):
                        raise ValueError
                    weights = parsed
                    current_column = None
                    needs_column = True
                except (ValueError, SyntaxError):
                    errors.append(f"line {line_number}: invalid column_layout")
                continue

            column = COLUMN.search(line)
            if column:
                index = int(column.group(1))
                if weights is None:
                    errors.append(f"line {line_number}: column used before column_layout")
                elif index >= len(weights):
                    errors.append(f"line {line_number}: column {index} is outside layout")
                elif current_column == index:
                    errors.append(f"line {line_number}: column {index} is already active")
                else:
                    current_column = index
                    needs_column = False
                continue

            if RESET.search(line):
                weights = None
                current_column = None
                needs_column = False
                continue

            if weights is not None and needs_column and stripped and not starts_comment:
                errors.append(f"line {line_number}: content appears before entering a column")
                needs_column = False

            if starts_comment:
                continue

            source_line = mask_non_content(line)
            for image in IMAGE.finditer(source_line):
                check_image(line_number, image.group(1) or image.group(2))
            for image in REFERENCE_IMAGE.finditer(source_line):
                key = normalize_reference_key(image.group(2) or image.group(1))
                target = references.get(key)
                if target is None:
                    errors.append(f"line {line_number}: unresolved image reference [{key}]")
                else:
                    check_image(line_number, target)
            for image in SHORTCUT_IMAGE.finditer(source_line):
                key = normalize_reference_key(image.group(1))
                target = references.get(key)
                if target is None:
                    errors.append(f"line {line_number}: unresolved image reference [{key}]")
                else:
                    check_image(line_number, target)
            theme_image = THEME_IMAGE.match(line) if line_number in frontmatter else None
            if theme_image:
                check_image(line_number, next(value for value in theme_image.groups() if value is not None))

    included_failures = 0
    for line_number, target in collect_includes(lines):
        if not target:
            errors.append(f"line {line_number}: include path is empty")
            continue
        if target.startswith(("http://", "https://", "data:")):
            errors.append(f"line {line_number}: include must be a local path, not {target[:80]}")
            continue
        included_failures += validate(path.parent / target, include_stack + (resolved_path,))

    last_content = next((line.strip() for line in reversed(lines) if line.strip()), "")
    if last_content == END_SLIDE:
        errors.append(f"deck must not end with {END_SLIDE}; omit the trailing marker")

    for message in errors:
        print(f"ERROR {display_path}: {message}")
    status = "failed" if errors or included_failures else "ok"
    print(f"{display_path}: {len(slides)} source slide(s), {status}")
    return int(bool(errors or included_failures))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("deck", type=Path)
    args = parser.parse_args()
    return validate(args.deck)


if __name__ == "__main__":
    sys.exit(main())
