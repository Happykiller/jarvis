<#
.SYNOPSIS
  Sets the Jarvis version across the 6 files that must stay in sync.

.DESCRIPTION
  Version lives in package.json, src-tauri/Cargo.toml, src-tauri/tauri.conf.json,
  jarvis.config.json, src-tauri/Cargo.lock (the jarvis package) and
  package-lock.json (two occurrences). Editing them by hand drifts (package-lock
  fell behind twice). This script does the targeted edits and verifies the result.

.PARAMETER Version
  Target semver, e.g. 2.3.4.

.EXAMPLE
  ./scripts/bump-version.ps1 2.3.4
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string] $Version
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if ($Version -notmatch '^\d+\.\d+\.\d+$') {
    Write-Host "ERROR: version '$Version' is not semver x.y.z" -ForegroundColor Red
    exit 1
}

$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

function Fail($msg) { Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }

# Replace at most $count matches of $pattern in the file at $path.
function Set-Version([string] $path, [string] $pattern, [string] $replacement, [int] $count) {
    $full = Join-Path $RepoRoot $path
    if (-not (Test-Path $full)) { Fail "file not found: $path" }
    $text = Get-Content $full -Raw
    $rx = [regex]$pattern
    if ($rx.Matches($text).Count -lt $count) { Fail "expected $count match(es) of /$pattern/ in $path" }
    $new = $rx.Replace($text, $replacement, $count)
    # Write UTF-8 WITHOUT BOM and without altering newlines/trailing bytes (PS 5.1
    # Set-Content -Encoding utf8 would prepend a BOM and corrupt Cargo.toml).
    [System.IO.File]::WriteAllText($full, $new, (New-Object System.Text.UTF8Encoding($false)))
}

# JSON files: first top-level "version": "..."
$jsonPattern = '"version"\s*:\s*"[^"]*"'
$jsonRepl    = '"version": "' + $Version + '"'
Set-Version "package.json"               $jsonPattern $jsonRepl 1
Set-Version "src-tauri/tauri.conf.json"  $jsonPattern $jsonRepl 1
Set-Version "jarvis.config.json"         $jsonPattern $jsonRepl 1

# package-lock.json: the first TWO occurrences (root + the "" package)
Set-Version "package-lock.json"          $jsonPattern $jsonRepl 2

# Cargo files: the version line right after `name = "jarvis"`
$cargoPattern = '(name = "jarvis"\r?\nversion = ")[^"]*(")'
$cargoRepl    = '${1}' + $Version + '${2}'
Set-Version "src-tauri/Cargo.toml"       $cargoPattern $cargoRepl 1
Set-Version "src-tauri/Cargo.lock"       $cargoPattern $cargoRepl 1

# --- Verify -----------------------------------------------------------------
# Regex-based (no ConvertFrom-Json: PS 5.1 chokes on package-lock's "" package key).
function Get-FirstMatch([string] $path, [string] $pattern, [int] $group) {
    $m = [regex]::Match((Get-Content (Join-Path $RepoRoot $path) -Raw), $pattern)
    if (-not $m.Success) { return "(introuvable)" }
    return $m.Groups[$group].Value
}

$jsonVer  = '"version"\s*:\s*"([^"]*)"'
$cargoVer = 'name = "jarvis"\r?\nversion = "([^"]*)"'
$results = [ordered]@{
    "package.json"              = Get-FirstMatch "package.json"              $jsonVer  1
    "src-tauri/tauri.conf.json" = Get-FirstMatch "src-tauri/tauri.conf.json" $jsonVer  1
    "jarvis.config.json"        = Get-FirstMatch "jarvis.config.json"        $jsonVer  1
    "package-lock.json"         = Get-FirstMatch "package-lock.json"         $jsonVer  1
    "src-tauri/Cargo.toml"      = Get-FirstMatch "src-tauri/Cargo.toml"      $cargoVer 1
    "src-tauri/Cargo.lock"      = Get-FirstMatch "src-tauri/Cargo.lock"      $cargoVer 1
}

Write-Host ""
Write-Host "Version -> $Version" -ForegroundColor Cyan
$bad = @()
foreach ($k in $results.Keys) {
    $v = $results[$k]
    $ok = ($v -eq $Version)
    if (-not $ok) { $bad += $k }
    $color = if ($ok) { "Green" } else { "Red" }
    Write-Host ("  {0,-28} {1}" -f $k, $v) -ForegroundColor $color
}

if ($bad.Count -gt 0) { Fail "these files did not reach ${Version}: $($bad -join ', ')" }
Write-Host ""
Write-Host "All 6 in sync at $Version. Rebuild (npm run tauri build) to ship it." -ForegroundColor Green
