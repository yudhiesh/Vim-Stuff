---
name: presenterm-slides
description: Create polished terminal slide decks as presenterm Markdown, using themes, columns, images, code, pauses, speaker notes, and export validation. Use when asked to generate or revise presenterm slides, terminal presentations, .md decks, or presentation artifacts in a presenterm repository.
---

# Presenterm Slides

## Quick start

1. Read [REFERENCE.md](REFERENCE.md).
2. If working in the presenterm repository, read `examples/README.md` and the examples relevant to the requested treatment (`demo.md`, `code.md`, `columns.md`, `footer.md`, `speaker-notes.md`, or `custom-intro-slides.md`).
3. Establish the brief before writing: audience, outcome, duration, source material, assets, and whether terminal, HTML, or PDF is the delivery format. If unspecified, use a short 8–12-slide deck with a dark, high-contrast theme.
4. Create one Markdown deck and keep its assets beside it. Prefer an inline front matter theme override over a new global config.
5. Before any `presenterm` command, classify the deck as trusted or untrusted. Inspect the active config and recursively included Markdown for `+auto_exec`, `+exec`, `+exec_replace`, `+image`, `+render`, and `+validate`. For untrusted decks, use a config that disables both execution modes, never pass `-x`, `-X`, or `--validate-snippets`, and sandbox or remove `+render` blocks.
6. Validate with `scripts/validate_presenterm.py path/to/deck.md`, then check `presenterm --version` and render/export only after the trust gate.

## Workflow

### 1. Shape the story

- Write the promise in one sentence.
- Sequence: title → context/problem → insight → evidence/demo → implications → next step.
- Give each slide one job; cut slides that do not advance the argument.
- Use speaker notes for talk track, caveats, and demo cues—not visible paragraphs.

### 2. Design the visual system

- Pick one background, one primary text color, one accent, and one muted color.
- Use a consistent title treatment, spacing rhythm, and footer.
- Prefer hierarchy, whitespace, short lines, and direct labels over decoration.
- Vary composition deliberately: title, statement, comparison columns, code, image, quote, and recap.
- Keep terminal readability primary: strong contrast, short lines, and no tiny text.

### 3. Author the deck

- Use `title`/`sub_title`/`author` front matter when a generated introduction slide is wanted; front matter is also valid for deck configuration such as theme overrides.
- Separate slides with the exact `<!-- end_slide -->` command.
- Use `column_layout`/`column` for comparisons and text-plus-image compositions; reset it with `reset_layout`.
- Use `pause` and `incremental_lists: true` sparingly for live reveals.
- Use code fences and presenterm options only when they clarify the point. `+exec` requires snippet execution to be enabled; `+auto_exec` also runs automatically. Use executable attributes only for trusted, deterministic snippets.
- Use local images with meaningful alt text and adjacent text for essential information; check that every Markdown-referenced asset exists.

### 4. Verify and deliver

- Run the validator and fix every error, including errors from recursively included decks. When changing the validator, run `python3 scripts/test_validate_presenterm.py` too.
- For a trusted deck with executable snippets, run `presenterm --validate-snippets path/to/deck.md`; this executes `+exec`, `+exec_replace`, and `+validate` snippets, so never run it on untrusted input.
- Capture the target terminal/config dimensions. Run `presenterm --validate-overflows path/to/deck.md` when available, then use `presenterm path/to/deck.md` for live hot-reload iteration and `presenterm --present path/to/deck.md` for the final talk. If no TTY is available, use explicit `export.dimensions` and report overflow validation as unverified.
- Prefer `presenterm --export-html path/to/deck.md --output path/to/deck.html`; HTML export itself needs no WeasyPrint, but `+render` blocks may require Mermaid, Typst, D2, LaTeX, or related tools.
- Use `presenterm --export-pdf ...` only when PDF delivery is required; PDF export requires WeasyPrint, which may need system dependencies.
- Re-read the final deck for narrative flow, overflow risk, contrast, asset paths, and accidental placeholder text.

## Non-negotiables

- Do not invent unsupported presenterm syntax.
- Do not put essential meaning only in animation, color, or speaker notes.
- Treat rendering/export as code execution when snippet execution is enabled in config or the deck uses `+exec`, `+auto_exec`, `+exec_replace`, `+image`, or `+render`; never enable it for an untrusted deck.
- Do not use executable snippets on untrusted input or code that depends on network, time, or machine state.
- Do not add a dependency, global theme, or custom renderer unless the requested deck genuinely needs it.

For syntax, templates, visual guidance, and authoritative links, see [REFERENCE.md](REFERENCE.md).
