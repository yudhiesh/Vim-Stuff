---
name: obsidian-cli
description: Interact with Obsidian vaults using the Obsidian CLI to read, create, search, and manage notes, tasks, properties, and more. Also supports plugin and theme development with commands to reload plugins, run JavaScript, capture errors, take screenshots, and inspect the DOM. Use when the user asks to interact with their Obsidian vault, manage notes, search vault content, perform vault operations from the command line, or develop and debug Obsidian plugins and themes.
---

# Obsidian CLI

Use the `obsidian` CLI to interact with a running Obsidian instance. Keep Obsidian open while running commands.

## Command reference

Run `obsidian help` to list available commands. This stays current.
Full docs: https://help.obsidian.md/cli

## Syntax

Parameters take values with `=`. Quote values with spaces:

```bash
obsidian create name="My Note" content="Hello world"
```

Flags are boolean switches with no value:

```bash
obsidian create name="My Note" silent overwrite
```

For multiline content, use `\n` for newline and `\t` for tab.

## File targeting

Many commands accept `file` or `path`. Without either, commands target the active file.

- `file=<name>` resolves like a wikilink (name only, no path or extension)
- `path=<path>` targets an exact path from vault root, for example `folder/note.md`

## Vault targeting

Commands target the most recently focused vault by default. Use `vault=<name>` as the first parameter to target a specific vault:

```bash
obsidian vault="My Vault" search query="test"
```

## OneCredit work notes location

For work notes, use:

- Vault: `My Vault`
- Folder: `Work/OneCredit/OneCredit Daily Notes`
- Date format: `DD-MM-YYYY - Notes.md`

Examples:

```bash
obsidian vault="My Vault" read path="Work/OneCredit/OneCredit Daily Notes/13-05-2026 - Notes.md"
obsidian vault="My Vault" append path="Work/OneCredit/OneCredit Daily Notes/13-05-2026 - Notes.md" content="- [ ] Follow up on X"
```

If needed, list notes in that folder first:

```bash
obsidian vault="My Vault" files path="Work/OneCredit/OneCredit Daily Notes"
```

## Common patterns

```bash
obsidian read file="My Note"
obsidian create name="New Note" content="# Hello" template="Template" silent
obsidian append file="My Note" content="New line"
obsidian search query="search term" limit=10
obsidian daily:read
obsidian daily:append content="- [ ] New task"
obsidian property:set name="status" value="done" file="My Note"
obsidian tasks daily todo
obsidian tags sort=count counts
obsidian backlinks file="My Note"
```

Use `--copy` on any command to copy output to clipboard. Use `silent` to prevent files from opening. Use `total` on list commands to include counts.

## Plugin development

### Develop/test cycle

After plugin or theme code changes, run this loop:

1. Reload the plugin:
   ```bash
   obsidian plugin:reload id=my-plugin
   ```
2. Check runtime errors. If errors appear, fix and repeat from step 1:
   ```bash
   obsidian dev:errors
   ```
3. Verify visually with screenshot or DOM inspection:
   ```bash
   obsidian dev:screenshot path=screenshot.png
   obsidian dev:dom selector=".workspace-leaf" text
   ```
4. Review console errors/warnings:
   ```bash
   obsidian dev:console level=error
   ```

### Additional developer commands

Run JavaScript in the app context:

```bash
obsidian eval code="app.vault.getFiles().length"
```

Inspect CSS values:

```bash
obsidian dev:css selector=".workspace-leaf" prop=background-color
```

Toggle mobile emulation:

```bash
obsidian dev:mobile on
```

Run `obsidian help` for additional developer commands, including CDP and debugger controls.
