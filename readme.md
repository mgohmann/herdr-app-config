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
