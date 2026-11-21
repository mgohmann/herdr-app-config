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
        if (Test-Path $dest) {
            Remove-Item -Recurse -Force $dest
        }
        Copy-Item -Recurse -Force $_.FullName $dest
        Write-Host "Installed mod: $($_.Name)" -ForegroundColor Green
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

Write-Host "`nDone! Restart or reload Herdr to apply changes." -ForegroundColor Cyan
