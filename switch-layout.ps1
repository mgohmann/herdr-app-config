<#
.SYNOPSIS
    Switch between dev-config Herdr layout variants (estro, estro-asks, coordinator).
.DESCRIPTION
    For the chosen variant: copies its layout + required mods into ~/.config/herdr-app
    (only when they differ), merges its layout-scoped keys, installs optional config files,
    runs `herdr-app check` on changed mods, then runs `layout.switch`.
    Variants are described in herdr/variants/<name>.json. Backups of anything overwritten go to
    ~/.config/herdr-app/backups/dev-config/<timestamp>/ (never inside layouts/ or mods/).
.EXAMPLE
    .\switch-layout.ps1 list
    .\switch-layout.ps1 estro-asks
    .\switch-layout.ps1 next
    .\switch-layout.ps1 coordinator -DryRun
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)][string]$Name = "list",
    [switch]$DryRun,
    [switch]$NoSwitch
)
$ErrorActionPreference = "Stop"

$Repo     = Join-Path $PSScriptRoot "herdr"
$Home_    = if ($env:HERDR_APP_HOME) { $env:HERDR_APP_HOME } else { Join-Path $env:USERPROFILE ".config\herdr-app" }
$Variants = @(Get-ChildItem (Join-Path $Repo "variants") -Filter *.json | ForEach-Object BaseName | Sort-Object)
$Backup   = Join-Path $Home_ ("backups\dev-config\" + (Get-Date -Format "yyyyMMdd-HHmmss"))

function Read-Json($p) { if (Test-Path $p) { Get-Content $p -Raw | ConvertFrom-Json -AsHashtable } else { @{} } }
function Get-Current { (Read-Json (Join-Path $Home_ "shared.json"))["layout"] }
function Get-DirHash($d) {
    # Herdr generates gpui-kit.d.ts / jsconfig.json in each mod folder; ignore them
    $files = Get-ChildItem $d -Recurse -File | Where-Object { $_.Name -notin 'gpui-kit.d.ts','jsconfig.json' } | Sort-Object FullName
    $s = ($files | ForEach-Object { $_.FullName.Substring($d.Length) + (Get-FileHash $_.FullName -Algorithm SHA1).Hash }) -join ""
    [BitConverter]::ToString([Security.Cryptography.SHA1]::HashData([Text.Encoding]::UTF8.GetBytes($s)))
}
function Save-Backup($path) {
    if (-not (Test-Path $path)) { return }
    $dest = Join-Path $Backup ($path.Substring($Home_.Length).TrimStart('\'))
    New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
    Copy-Item -Recurse -Force $path $dest
}
function Say($m, $c = "Gray") { Write-Host $m -ForegroundColor $c }

if (-not (Test-Path $Home_)) { throw "No Herdr app home at $Home_. Open the Herdr app once first." }
$current = Get-Current

if ($Name -eq "list") {
    foreach ($v in $Variants) {
        $d = (Read-Json (Join-Path $Repo "variants\$v.json"))["description"]
        $mark = if ($v -eq $current) { "*" } else { " " }
        Write-Host ("{0} {1,-14} {2}" -f $mark, $v, $d)
    }
    return
}
if ($Name -eq "next") {
    $i = [array]::IndexOf($Variants, $current)
    $Name = $Variants[($i + 1) % $Variants.Count]
}
if ($Name -notin $Variants) { throw "Unknown variant '$Name'. Available: $($Variants -join ', ')" }

$variant = Read-Json (Join-Path $Repo "variants\$Name.json")
Say "=== Variant: $Name ===" Cyan
if ($DryRun) { Say "(dry run: nothing will be written)" Yellow }

# 1. Mods (only when content differs)
$changedMods = @()
foreach ($m in $variant["mods"]) {
    $src = Join-Path $Repo "mods\$m"
    $dst = Join-Path $Home_ "mods\$m"
    if (-not (Test-Path $src)) {
        # Not vendored: either shipped by Herdr, or installed by another tool (e.g. pocketspeak)
        if (Test-Path $dst) { Say "  mod $m : external, present" DarkGray }
        elseif ($m -eq "pocketspeak") { Say "  mod $m : MISSING. Run: pocketspeak plugin install herdr-app" Red }
        else { Say "  mod $m : not in repo and not installed (Herdr-shipped mods are fine)" Yellow }
        continue
    }
    if ((Test-Path $dst) -and ((Get-DirHash $src) -eq (Get-DirHash $dst))) { Say "  mod $m : up to date" DarkGray; continue }
    Say "  mod $m : installing" Green
    $changedMods += $m
    if (-not $DryRun) {
        Save-Backup $dst
        if (Test-Path $dst) { Remove-Item -Recurse -Force $dst }
        Copy-Item -Recurse -Force $src $dst
    }
}

# 2. Layout
$lsrc = Join-Path $Repo "layouts\$Name.json"
$ldst = Join-Path $Home_ "layouts\$Name.json"
if (-not (Test-Path $ldst) -or ((Get-FileHash $lsrc).Hash -ne (Get-FileHash $ldst).Hash)) {
    Say "  layout $Name.json : installing" Green
    if (-not $DryRun) { Save-Backup $ldst; Copy-Item -Force $lsrc $ldst }
} else { Say "  layout $Name.json : up to date" DarkGray }

# 3. Keys: layout-scoped only, never global
$keysFile = Join-Path $Home_ "keys.json"
$keys = Read-Json $keysFile
$section = if ($keys.ContainsKey("layout:$Name")) { $keys["layout:$Name"] } else { @{} }
$dirty = $false
foreach ($k in $variant["keys"].Keys) {
    $want = $variant["keys"][$k]
    $existing = if ($keys.ContainsKey("global")) { $keys["global"][$k] } else { $null }
    if ($existing -and $existing -ne $want) { Say "  key $k : already global -> $existing (layout-scoped binding will override in $Name)" Yellow }
    if ($section[$k] -ne $want) { $section[$k] = $want; $dirty = $true; Say "  key $k -> $want (layout:$Name)" Green }
}
if ($dirty -and -not $DryRun) {
    Save-Backup $keysFile
    $keys["layout:$Name"] = $section
    $keys | ConvertTo-Json -Depth 20 | Set-Content $keysFile -Encoding utf8
}

# 4. Config files: created only if missing, never overwritten
if ($variant.ContainsKey("config")) {
    foreach ($f in $variant["config"].Keys) {
        $dst = Join-Path $Home_ $f
        if (Test-Path $dst) { Say "  config $f : exists, left alone (check it matches herdr\$($variant['config'][$f]))" Yellow }
        else { Say "  config $f : creating" Green; if (-not $DryRun) { Copy-Item (Join-Path $Repo $variant["config"][$f]) $dst } }
    }
}

# 4b. Revive: make sure its hooks (Claude Code + PowerShell profile) are installed
if ("revive" -in $variant["mods"]) {
    $engine = Join-Path $Home_ "mods\revive\revive.mjs"
    if ((Test-Path $engine) -and (Get-Command node -ErrorAction SilentlyContinue)) {
        $doc = (& node $engine doctor 2>&1 | Out-String | ConvertFrom-Json -AsHashtable)
        if ($doc["claude"] -and $doc["shell"]["pwsh"]) { Say "  revive hooks : installed" DarkGray }
        else {
            Say "  revive hooks : installing" Green
            if (-not $DryRun) { & node $engine install --pwsh --no-codex --no-pi --no-omp --no-droid --no-cursor --no-copilot --no-muse | Out-Null }
        }
    }
}

# 5. Check changed mods, then switch
if (-not $DryRun) {
    foreach ($m in $changedMods) {
        $out = (& herdr-app check (Join-Path $Home_ "mods\$m") 2>&1 | Out-String).Trim()
        if ($out -match '"errors":\s*\[\s*\]' -or $out -notmatch 'error') { Say "  check $m : ok" DarkGray }
        else { Say "  check $m :`n$out" Red }
    }
    if (-not $NoSwitch) {
        & herdr-app do layout.switch --name $Name | Out-Null
        Say "Switched to '$Name'. (previous: $current)" Cyan
        & herdr-app status 2>&1 | Out-String | Say
    }
}
