# pi

`agent/settings.json` and `agent/skills/` contain portable Pi configuration
managed from `~/.pi/agent` by the root `mise.toml`. Under `agent/extensions/`,
only `subagent/config.json` is tracked.

Do not commit per-device identifiers, extension credentials (including
`agent/extensions/linear/credentials.json`), auth state, sessions, history,
caches, or generated integration output. Re-authenticate extensions on each
machine.
