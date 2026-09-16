# Presenterm reference

## Minimal deck

```markdown
---
title: "A clear **promise**"
sub_title: "Optional subtitle"
author: "Name"
---

# One idea

A short statement with **one** visual emphasis.

<!-- end_slide -->

# Another idea
```

A presentation is one Markdown file. Use `<!-- end_slide -->` as the explicit slide boundary. Standard Markdown is supported, including headings, lists, quotes, tables, inline code, links, and fenced code. `title`, `sub_title`, and `author` front matter create the generated introduction slide; front matter is also used for deck configuration such as theme overrides.

## Layout commands

Commands are HTML comments and must be outside fenced code blocks.

| Command | Use |
| --- | --- |
| `<!-- pause -->` | Reveal the next block on a keypress. |
| `<!-- incremental_lists: true -->` | Reveal list items incrementally. |
| `<!-- column_layout: [7, 3] -->` | Start weighted columns. |
| `<!-- column: 0 -->` | Put following content in a column. |
| `<!-- reset_layout -->` | Return to the normal full-width layout. |
| `<!-- alignment: center -->` | Align the following content. |
| `<!-- newlines: 3 -->` | Add controlled vertical spacing. |
| `<!-- jump_to_middle -->` | Move following content toward the middle. |
| `<!-- font_size: 2 -->` | Request a larger terminal font where supported. |
| `<!-- speaker_note: ... -->` | Add a note to the current slide. |

Use a small number of layout changes per slide. Column weights should add up to a useful, intentional composition; keep code and images out of columns too narrow to read.

## Code and media

```rust +line_numbers
fn main() {
    println!("Readable code wins");
}
```

Useful options demonstrated by the project examples include `+line_numbers`, `+no_background`, and `+exec`. Dynamic highlighting uses a suffix such as `{1-4|6-10|all}`. `+exec` runs only when snippet execution is enabled (for example, `presenterm --enable-snippet-execution deck.md`); `+auto_exec` also runs automatically, while `+exec_replace` and `+image` can replace output without an interactive step. Never enable snippet execution for an untrusted deck; keep trusted snippets deterministic.

Images use ordinary Markdown:

```markdown
![A concise description](assets/diagram.png)
```

Prefer local assets with paths relative to the deck. Alt text is good authoring hygiene, but terminal and HTML rendering may not expose it; put essential meaning in nearby text, a table, or a caption. Images and animated GIFs depend on terminal image support; the HTML export is the safer sharing artifact. `<!-- include: path/to/other.md -->` imports local Markdown, so inspect included files as part of the deck.

## Inline theme overrides

Keep deck-specific styling in front matter:

```yaml
---
theme:
  override:
    code:
      alignment: left
      background: false
    footer:
      style: template
      left: "Project name"
      center: ""
      right: "{current_slide} / {total_slides}"
      height: 2
    palette:
      classes:
        accent:
          foreground: red
---
```

Use `<span class="accent">...</span>` for repeated semantic emphasis, or a `style` attribute for a one-off foreground/background color. Presenterm supports `span` styling, not arbitrary HTML layout.

## Speaker notes

Inline notes remain out of the main presentation and can be published/listened to from separate presenterm instances:

```markdown
<!-- speaker_note: Pause here and ask for questions. -->
```

Run two instances when presenting notes:

```bash
presenterm --publish-speaker-notes deck.md
presenterm --listen-speaker-notes deck.md
```

Use multiline YAML when necessary:

```markdown
<!--
speaker_note: |
  Explain the diagram.
  Call out the trade-off.
-->
```

## Validation and export

Before any `presenterm` command, classify the deck as trusted or untrusted. Inspect the active config and recursively included Markdown for `+auto_exec`, `+exec`, `+exec_replace`, `+image`, `+render`, and `+validate`.

For an existing or untrusted deck, do not inherit a config that enables execution:

```yaml
# /tmp/presenterm-safe.yaml
snippet:
  exec:
    enable: false
  exec_replace:
    enable: false
```

Run untrusted render/export with `--config-file /tmp/presenterm-safe.yaml`; never pass `-x`, `-X`, or `--validate-snippets`. This only disables the two snippet execution modes, so inspect/remove `+render` blocks or sandbox the process when third-party renderers are present.

```bash
python3 /path/to/presenterm-slides/scripts/validate_presenterm.py deck.md
presenterm --version
presenterm --validate-overflows deck.md
presenterm deck.md
presenterm --present deck.md
presenterm --validate-snippets deck.md  # trusted deterministic snippets only
presenterm --export-html deck.md --output deck.html
presenterm --export-pdf deck.md --output deck.pdf
```

Capture the target terminal/config dimensions. If no TTY is available, use explicit `export.dimensions` for export and report overflow validation as unverified. HTML export itself needs no WeasyPrint, but `+render` blocks may require Mermaid, Typst, D2, LaTeX, or related tools. PDF export requires WeasyPrint and may need system dependencies. When presenterm is unavailable, run the validator and report that rendering remains unverified instead of installing packages automatically.

## Beauty checklist

- One promise and one focal point per slide.
- No wall of prose; keep visible copy scannable.
- Use one accent consistently and reserve it for meaning.
- Contrast and readability survive monochrome or color-blind viewing.
- Columns compare or pair things; they are not a dumping ground.
- Code is cropped to the essential lines and uses a readable option set.
- Every image has a reason, a valid path, and meaningful alt text; add adjacent prose or a table when an image carries essential information.
- Pauses support the spoken story rather than hiding missing structure.
- Final slide has a concrete takeaway or next action.

## Sources

- https://mfontanini.github.io/presenterm/
- https://mfontanini.github.io/presenterm/features/introduction.html
- https://mfontanini.github.io/presenterm/features/layout.html
- https://mfontanini.github.io/presenterm/features/speaker-notes.html
- https://mfontanini.github.io/presenterm/features/exports.html
- https://mfontanini.github.io/presenterm/features/themes/introduction.html
- https://mfontanini.github.io/presenterm/features/themes/definition.html
- https://mfontanini.github.io/presenterm/configuration/settings.html
- Local canonical examples: `examples/README.md`, `examples/demo.md`, `examples/code.md`, `examples/columns.md`, `examples/footer.md`, `examples/speaker-notes.md`, `examples/custom-intro-slides.md`.

The validator checks source structure, recursively included decks, Markdown image paths, image references, and simple front-matter `image:` fields; render/export is still required for actual terminal overflow and any unsupported configuration shape.
