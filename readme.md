# dev-config

Reproducible, Windows-first **Herdr** developer environment configuration.

## What's Included

- **Layout:** `estro` ([munza/herdr-mods](https://github.com/munza/herdr-mods/tree/main/estro))
- **Baseline Mods:**
  - `better-changes`
  - `better-files`
  - `better-tabs`
  - `better-sidebar`

## Quick Start (Windows / PowerShell)

```powershell
.\bootstrap.ps1
```

The bootstrapper copies the layout and mods into `~/.config/herdr-app/` (no symlinks required) and prompts before overwriting existing configurations. It also includes an optional, opt-in step for **GitHub Copilot CLI**.

Pass `-Force` to overwrite existing layouts/mods without prompting:

```powershell
.\bootstrap.ps1 -Force
```

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

All variants also include [Revive](https://github.com/dmazlum/herdr-revive) (`ctrl-shift-r`, layout-scoped): it brings Claude Code sessions back after a reboot or core restart. `switch-layout.ps1` only copies the mod and the key. The hooks (`~/.claude/settings.json`) and PowerShell profile block are installed by an opt-in prompt in `bootstrap.ps1` (Claude Code only; pi, omp, Codex, Droid, Cursor, Copilot and Muse are skipped). Undo with `node ~/.config/herdr-app/mods/revive/revive.mjs uninstall`. Vendored upstream commit: `5f2a1f5` (v0.12.0, MIT, license in `herdr/vendor/`).

Variants live in `herdr/variants/<name>.json` (mods, layout-scoped keys, optional config). Backups of anything overwritten go to `~/.config/herdr-app/backups/dev-config/`. Vendored upstream commits: herdr-agent-ask `d6e2c3a`, coordinator `3850c8d` (licenses in `herdr/vendor/`). Cockpit is deferred (no Windows binary).
