# oh-my-pi

Mirrors the live `~/.omp` state so a new machine can be rebuilt from it.

## Tracked

| Repo path                                       | Live path                  | Contents                                                                          |
| ----------------------------------------------- | -------------------------- | --------------------------------------------------------------------------------- |
| `config.yml`, `models.yml`, `mcp.json`          | `~/.omp/agent/`            | settings, custom models, MCP servers                                              |
| `marketplaces.json`                             | `~/.omp/`                  | marketplace registry (add before reinstalling plugins)                            |
| `plugins/*.json`                                | `~/.omp/plugins/`          | installed plugins, pinned versions, enable state                                  |
| `skills/`                                       | `~/.omp/agent/skills/`     | installed skills (herdr tracked without `vendor/` and its nested upstream copy)    |
| `themes/`                                       | `~/.omp/agent/themes/`     | `catppuccin-mocha`, `catppuccin-latte`                                             |
| `extensions/`                                   | `~/.omp/agent/extensions/` | `herdr-omp-agent-state.ts` (herdr-managed; herdr regenerates it on reinstall)      |

Not tracked, machine-local or secret: auth (`agent.db`), sessions, history, memories,
`plugins/cache/`, `plugins/node_modules/`.

## Restore on a fresh machine

```sh
cd Vim-Stuff
mkdir -p ~/.omp/agent/extensions
cp omp/config.yml omp/models.yml omp/mcp.json ~/.omp/agent/
rsync -a omp/skills/ ~/.omp/agent/skills/
rsync -a omp/themes/ ~/.omp/agent/themes/
cp omp/extensions/*.ts ~/.omp/agent/extensions/
cp omp/marketplaces.json ~/.omp/
```

Then reinstall the plugins — cached plugin content is machine-local and omp re-fetches it:

```sh
omp plugin install modern-go-guidelines@goland-claude-marketplace
omp plugin install linear-cli@linear-cli
omp plugin install polars@polars
```

Verify:

```sh
omp config get theme.dark   # catppuccin-mocha
omp plugin list             # the three plugins above
```

Do not copy `plugins/*.json` into `~/.omp/plugins/` on a fresh machine before that: omp
then reports the plugins as installed while their cache is missing. `omp plugin install`
needs `--force` only if the metadata is already there.

Auth is not in this repo: sign in again, or set the provider API keys (`OPENROUTER_API_KEY`, …).

## Re-syncing from the live machine

```sh
cd Vim-Stuff
cp ~/.omp/agent/{config.yml,models.yml,mcp.json} omp/
cp ~/.omp/marketplaces.json omp/
cp ~/.omp/plugins/{installed_plugins.json,omp-plugins.lock.json,package.json} omp/plugins/
rsync -a --delete --exclude .DS_Store --exclude /herdr/vendor/ --exclude /herdr/herdr/ ~/.omp/agent/skills/ omp/skills/
rsync -a --delete --exclude .DS_Store ~/.omp/agent/themes/ omp/themes/
cp ~/.omp/agent/extensions/*.ts omp/extensions/
```
