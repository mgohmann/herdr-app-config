# dev-config

Reproducible, Windows-first **Herdr** developer environment configuration.

## What's Included

- **Layout:** `estro` ([munza/herdr-mods](https://github.com/munza/herdr-mods/tree/main/estro)), the only layout supported, with a **Rewrite** panel tab added.
- **Mods** (vendored in `herdr/mods/`): `better-sidebar`, `better-tabs`, `better-files`, `better-changes`, `better-icons`, `better-config`, `branch-pr`, `t3-inbox`, `window-controls`, `revive` and [`rewrite`](https://github.com/mgohmann/herdrmod-rewrite).
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

The bootstrapper copies the layouts and mods into `~/.config/herdr-app/` (no symlinks required) and prompts before overwriting existing ones. It then builds the `branch-pr` helper if Go is available, warns if PocketSpeak is missing, offers an opt-in **GitHub Copilot CLI** check, and finally runs `switch-layout.ps1 estro` to apply the estro layout (layout-scoped keys, Revive hooks, and switching to it).

Pass `-Force` to overwrite existing layouts/mods without prompting:

```powershell
.ootstrap.ps1 -Force
```

## Write commit message (AI commit drafts)

`better-changes` is patched here with a **Write commit message** button above Commit (`herdr/mods/better-changes/ai.js`; upstream has no such feature, so re-apply it if you update the vendored mod). It sends the staged diff, the changed-file stat, the branch and your last 8 commit messages to a coding-agent CLI run once, non-interactively, with tools off (or a read-only agent) in a neutral folder, then fills the message box. It never commits, and never replaces text you typed.

It uses the agent running in the current tab, else the first installed in this order. Defaults (override under `settings.ai` in the installed `mods/better-changes/mod.json`):

| Harness | Command | Model | Effort |
|---|---|---|---|
| Claude Code | `claude -p --tools ""` | `haiku` | low |
| Antigravity | `agy -p --mode plan` | `gemini-4-hydrogen-low` | low |
| Copilot | `copilot -p -s` | `gpt-6-luna` | low |
| OpenCode | `opencode run --agent plan` | `openrouter/openai/gpt-6-luna#low` | low |

The same row has a **Sync** button like VS Code's: it shows how far the branch is behind (↓) and ahead (↑) of its upstream as of the last fetch, and clicking it runs `git pull` then `git push`. A branch with no upstream shows **Publish** (`git push -u <remote> HEAD`). Pull uses `--ff-only` when nothing is ahead, otherwise your pull settings; any failure is shown in the panel.

Set `ai.harness` to `claude`, `antigravity`, `copilot` or `opencode` to pin one. The diff is capped at 20,000 characters (`ai.diff_limit`) to stay under Windows' command-line limit. The staged diff goes to whichever provider the chosen CLI uses.

## PocketSpeak speaking indicator (`better-sidebar`)

`better-sidebar` is patched here (`herdr/mods/better-sidebar/views/agents.js` and `icons/waveform.svg`) to read `shared("pocketspeak.speaking")` (`{ speaking: boolean, terminals: string[], queued: string[] }`) published by the PocketSpeak `herdr-app` mod (no indicator is shown if PocketSpeak is absent or disconnected):

- **Actively speaking (`#F5A191`):** highlights matching agent rows (including all agents in an Announcer Mode batch) and lead-terminal tab rows with a coral left accent bar, subtle row tint, and a pulsing waveform icon.
- **Queued to speak (`#BB9AE2`):** shows a lavender left accent bar, subtle row tint, and waveform icon until playback starts or is cleared.
- **Scope:** applies to `agentRow` and `tabRow` (lead terminal); collapsed `railRow` and `subRow` sub-agents do not display the indicator.

## Rewrite panel (`rewrite`)

Vendored from [mgohmann/herdrmod-rewrite](https://github.com/mgohmann/herdrmod-rewrite) (commit `f7fe405`, MIT; tests and plan omitted). It turns rough or dictated text into polished output via your local coding-agent CLI. `estro.json` adds a **Rewrite** tab button and a `rewrite` block in `panel-body`. Settings live under `settings` in the installed `mods/rewrite/mod.json`. To update, re-copy the upstream files and re-check the layout wiring.

## Layout (`estro`)

`herdr/variants/estro.json` is the manifest: the mods to install, plus layout-scoped keys. `bootstrap.ps1` installs only the `estro` layout and the mods listed there. Re-apply it alone with:

```powershell
.\switch-layout.ps1 estro            # install what changed, then switch
.\switch-layout.ps1 estro -DryRun
```

[Revive](https://github.com/dmazlum/herdr-revive) (`ctrl-shift-r`, layout-scoped) brings Claude Code sessions back after a reboot or core restart. `switch-layout.ps1` copies the mod and the key, and installs the hooks (`~/.claude/settings.json`) and the PowerShell profile block if `revive.mjs doctor` says they are missing. Only Claude Code is wired up; the other agents are skipped. Restart running Claude Code and PowerShell sessions after the first install. Undo with `node ~/.config/herdr-app/mods/revive/revive.mjs uninstall`. Vendored upstream commit: `5f2a1f5` (v0.12.0, MIT, license in `herdr/vendor/`).

Backups of anything overwritten go to `~/.config/herdr-app/backups/dev-config/`.
