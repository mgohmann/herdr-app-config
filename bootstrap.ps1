<#
.SYNOPSIS
    Interactive bootstrapper for dev-config (Herdr + optional GitHub Copilot CLI).
.DESCRIPTION
    Copies the estro layout and vetted mods into ~/.config/herdr-app/ without symlinks.
    Optionally configures GitHub Copilot CLI if the user opts in.
#>

[CmdletBinding()]
param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$RepoRoot = $PSScriptRoot
$HerdrConfigDir = Join-Path $env:USERPROFILE ".config\herdr-app"
$HerdrLayoutsDir = Join-Path $HerdrConfigDir "layouts"
$HerdrModsDir = Join-Path $HerdrConfigDir "mods"

Write-Host "=== dev-config Bootstrapper ===" -ForegroundColor Cyan

# 1. Ensure Herdr config directories exist
New-Item -ItemType Directory -Force -Path $HerdrLayoutsDir, $HerdrModsDir | Out-Null

# 2. Copy layouts
$SourceLayouts = Join-Path $RepoRoot "herdr\layouts"
if (Test-Path $SourceLayouts) {
    Get-ChildItem $SourceLayouts | ForEach-Object {
        $dest = Join-Path $HerdrLayoutsDir $_.Name
        # Remove any stale directory with the same base name (e.g. old layouts/estro/ folder)
        if (-not $_.PSIsContainer) {
            $staleDir = Join-Path $HerdrLayoutsDir $_.BaseName
            if (Test-Path $staleDir -PathType Container) {
                Remove-Item -Recurse -Force $staleDir
            }
        }
        if ((Test-Path $dest) -and -not $Force) {
            $ans = Read-Host "Layout '$($_.Name)' already exists. Overwrite? [y/N]"
            if ($ans -notin @('y', 'Y', 'yes')) {
                Write-Host "Skipped layout: $($_.Name)" -ForegroundColor Yellow
                return
            }
        }
        if (Test-Path $dest) {
            Remove-Item -Recurse -Force $dest
        }
        Copy-Item -Recurse -Force $_.FullName $dest
        Write-Host "Installed layout: $($_.Name)" -ForegroundColor Green
    }
}

# 3. Copy mods
$SourceMods = Join-Path $RepoRoot "herdr\mods"
if (Test-Path $SourceMods) {
    Get-ChildItem $SourceMods -Directory | ForEach-Object {
        $dest = Join-Path $HerdrModsDir $_.Name
        if ((Test-Path $dest) -and -not $Force) {
            $ans = Read-Host "Mod '$($_.Name)' already exists. Overwrite? [y/N]"
            if ($ans -notin @('y', 'Y', 'yes')) {
                Write-Host "Skipped mod: $($_.Name)" -ForegroundColor Yellow
                return
            }
        }
        # Built artifacts (e.g. branch-pr/bin/herdr-pr.exe) are not in the repo; keep them across the overwrite.
        $keepBin = $null
        $destBin = Join-Path $dest "bin"
        if (Test-Path $destBin) {
            $keepBin = Join-Path ([IO.Path]::GetTempPath()) ("herdr-bin-" + [guid]::NewGuid())
            Move-Item $destBin $keepBin
        }
        if (Test-Path $dest) {
            Remove-Item -Recurse -Force $dest
        }
        Copy-Item -Recurse -Force $_.FullName $dest
        if ($keepBin) { Move-Item $keepBin (Join-Path $dest "bin") }
        Write-Host "Installed mod: $($_.Name)" -ForegroundColor Green
    }
}

# 2b. Themes: copy vendored themes, and select vesper if no theme is chosen yet
$HerdrThemesDir = Join-Path $HerdrConfigDir "themes"
$SourceThemes = Join-Path $RepoRoot "herdr	hemes"
if (Test-Path $SourceThemes) {
    New-Item -ItemType Directory -Force -Path $HerdrThemesDir | Out-Null
    Get-ChildItem $SourceThemes -Filter *.json | ForEach-Object {
        $dest = Join-Path $HerdrThemesDir $_.Name
        if ((Test-Path $dest) -and ((Get-FileHash $dest).Hash -ne (Get-FileHash $_.FullName).Hash) -and -not $Force) {
            $ans = Read-Host "Theme '$($_.Name)' already exists and differs. Overwrite? [y/N]"
            if ($ans -notin @('y', 'Y', 'yes')) { Write-Host "Skipped theme: $($_.Name)" -ForegroundColor Yellow; return }
        }
        Copy-Item -Force $_.FullName $dest
        Write-Host "Installed theme: $($_.Name)" -ForegroundColor Green
    }
    $SettingsFile = Join-Path $HerdrConfigDir "settings.json"
    $settings = if (Test-Path $SettingsFile) { Get-Content $SettingsFile -Raw | ConvertFrom-Json -AsHashtable } else { @{} }
    if (-not $settings.ContainsKey("theme")) {
        $settings["theme"] = "vesper"
        $settings | ConvertTo-Json -Depth 20 | Set-Content $SettingsFile -Encoding utf8
        Write-Host "Set theme: vesper" -ForegroundColor Green
    }
}

# 3b. Build branch-pr Go helper if Go is available
$BranchPrDir = Join-Path $HerdrModsDir "branch-pr"
$BranchPrHelper = Join-Path $BranchPrDir "helper"
if (Test-Path $BranchPrHelper) {
    if (Get-Command go -ErrorAction SilentlyContinue) {
        Write-Host "Building branch-pr Go helper (herdr-pr.exe)..." -ForegroundColor Cyan
        $BinDir = Join-Path $BranchPrDir "bin"
        New-Item -ItemType Directory -Force -Path $BinDir | Out-Null
        Push-Location $BranchPrHelper
        try {
            go build -o (Join-Path $BinDir "herdr-pr.exe") .
            Write-Host "Built herdr-pr.exe" -ForegroundColor Green
        } finally {
            Pop-Location
        }
    } else {
        Write-Host "Note: Go 1.23+ is required to build the branch-pr helper (herdr-pr.exe). Install Go from https://go.dev/dl/ and re-run bootstrap.ps1." -ForegroundColor Yellow
    }
}

# 3c. PocketSpeak: every variant's layout depends on it, but it is installed by its own tool
if (-not (Test-Path (Join-Path $HerdrModsDir "pocketspeak"))) {
    Write-Host "Warning: the pocketspeak mod is not installed. Run: pocketspeak plugin install herdr-app" -ForegroundColor Yellow
}

# 4. Optional: GitHub Copilot CLI (opt-in)
$copilotOptIn = Read-Host "`nWould you like to check/configure GitHub Copilot CLI? [y/N]"
if ($copilotOptIn -in @('y', 'Y', 'yes')) {
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        Write-Host "GitHub CLI (gh) found. Checking gh-copilot extension..." -ForegroundColor Cyan
        $exts = gh extension list 2>$null
        if ($exts -notmatch "github/gh-copilot") {
            Write-Host "Installing github/gh-copilot extension..." -ForegroundColor Cyan
            gh extension install github/gh-copilot
        } else {
            Write-Host "gh-copilot is already installed." -ForegroundColor Green
        }
    } else {
        Write-Host "GitHub CLI (gh) not found. Install it from https://cli.github.com/ first." -ForegroundColor Yellow
    }
}

# 5. Apply the estro variant: layout-scoped keys, Revive hooks, and switch to it.
# (Needs the Herdr app to have been opened once; otherwise run switch-layout.ps1 later.)
try {
    & (Join-Path $RepoRoot "switch-layout.ps1") estro
} catch {
    Write-Host "Could not apply the estro variant: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "Run later: .\switch-layout.ps1 estro" -ForegroundColor Yellow
}

Write-Host "`nDone! Restart or reload Herdr to apply changes." -ForegroundColor Cyan
