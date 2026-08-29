# oh-my-pi

Mirrors the live `~/.omp` state:

- `config.yml`, `models.yml`, `mcp.json`, `marketplaces.json` — agent settings
- `themes/` — UI themes
- `skills/` — installed skills (herdr skill is tracked without its vendored
  `vendor/` deps and nested duplicate `herdr/` tree; recover those from upstream)

Restore by copying back into `~/.omp/agent/`.
