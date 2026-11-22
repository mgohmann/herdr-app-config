# dev-config

Reproducible, Windows-first **Herdr** developer environment configuration.

## What's Included

- **Layouts:** `estro` ([munza/herdr-mods](https://github.com/munza/herdr-mods/tree/main/estro)), plus the `estro-asks` and `coordinator` variants (see below).
- **Mods** (vendored in `herdr/mods/`): `better-sidebar`, `better-tabs`, `better-files`, `better-changes`, `better-icons`, `better-config`, `file-icons`, `branch-pr`, `t3-inbox`, `window-controls`, `revive`, and the Asks/Coordinator mods used by the variants.
- **Theme:** `vesper` (`herdr/themes/`), copied by `bootstrap.ps1`. It is selected only if `settings.json` has no theme yet; an existing choice is left alone.
- **Not included:** global key bindings and other Herdr settings. Those stay local to each machine.

## Prerequisites

- The Herdr app, opened at least once (creates `~/.config/herdr-app/`).
- **PocketSpeak** mod, which every layout uses. It is installed by its own tool: `pocketspeak plugin install herdr-app`. `bootstrap.ps1` only warns if it is missing.
- **Node.js** for Revive's hooks.
- **Go 1.23+** and an authenticated **GitHub CLI** (`gh auth login`) for the PRs tab. `branch-pr` calls a small Go helper (`herdr-pr.exe`) that wraps `gh`. `bootstrap.ps1` builds it into `mods/branch-pr/bin/` when Go is installed. Without it the PRs tab can't load pull requests.

## Quick Start (Windows / PowerShell)

```powershell
.ootstrap.ps1
```

The bootstrapper copies the layouts and mods into `~/.config/herdr-app/` (no symlinks required) and prompts before overwriting existing ones. It then builds the `branch-pr` helper if Go is available, warns if PocketSpeak is missing, offers an opt-in **GitHub Copilot CLI** check, and finally runs `switch-layout.ps1 estro` to apply the estro variant (layout-scoped keys, Revive hooks, and switching to it).

Pass `-Force` to overwrite existing layouts/mods without prompting:

```powershell
.ootstrap.ps1 -Force
```

## Write message (AI commit drafts)

`better-changes` is patched here with a **Write message** button above Commit (`herdr/mods/better-changes/ai.js`; upstream has no such feature, so re-apply it if you update the vendored mod). It sends the staged diff, the changed-file stat, the branch and your last 8 commit messages to a coding-agent CLI run once, non-interactively, with tools off (or a read-only agent) in a neutral folder, then fills the message box. It never commits, and never replaces text you typed.

It uses the agent running in the current tab, else the first installed in this order. Defaults (override under `settings.ai` in the installed `mods/better-changes/mod.json`):

| Harness | Command | Model | Effort |
|---|---|---|---|
| Claude Code | `claude -p --tools ""` | `haiku` | low |
| Antigravity | `agy -p --mode plan` | `gemini-4-hydrogen-low` | low |
| Copilot | `copilot -p -s` | `gpt-6-luna` | low |
| OpenCode | `opencode run --agent plan` | `openrouter/openai/gpt-6-luna#low` | low |

Set `ai.harness` to `claude`, `antigravity`, `copilot` or `opencode` to pin one. The diff is capped at 20,000 characters (`ai.diff_limit`) to stay under Windows' command-line limit. The staged diff goes to whichever provider the chosen CLI uses.

## Layout variants (A/B testing)

```powershell
.\switch-layout.ps1 list              # variants; * = current
.\switch-layout.ps1 estro-asks        # install what it needs, then switch
.\switch-layout.ps1 next              # cycle
.\switch-layout.ps1 coordinator -DryRun
```

| Variant | What it is |
|---|---|
| `estro` | Baseline (current). |
| `estro-asks` | estro + [herdr-agent-ask](https://github.com/sachin-philip/herdr-agent-ask) panel. Asks tab button, `ctrl-shift-a` toggles (this layout only). Classifier is **off** (`herdr/config/asks.json`), so nothing is sent to Claude/Codex. |
| `coordinator` | [petekp/coordinator](https://github.com/petekp/coordinator) sidebar; panels use better-files/better-changes. Update check disabled. `cmd-k` opens the agent jumper. |

All variants also include [Revive](https://github.com/dmazlum/herdr-revive) (`ctrl-shift-r`, layout-scoped): it brings Claude Code sessions back after a reboot or core restart. `switch-layout.ps1` copies the mod and the key, and installs the hooks (`~/.claude/settings.json`) and the PowerShell profile block if `revive.mjs doctor` says they are missing. Only Claude Code is wired up; pi, omp, Codex, Droid, Cursor, Copilot and Muse are skipped. Restart running Claude Code and PowerShell sessions after the first install. Undo with `node ~/.config/herdr-app/mods/revive/revive.mjs uninstall`. Vendored upstream commit: `5f2a1f5` (v0.12.0, MIT, license in `herdr/vendor/`).

Variants live in `herdr/variants/<name>.json` (mods, layout-scoped keys, optional config). Backups of anything overwritten go to `~/.config/herdr-app/backups/dev-config/`. Vendored upstream commits: herdr-agent-ask `d6e2c3a`, coordinator `3850c8d` (licenses in `herdr/vendor/`). Cockpit is deferred (no Windows binary).
