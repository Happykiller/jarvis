<#
.SYNOPSIS
  Builds the Jarvis installers and publishes a GitHub Release to the dedicated
  releases repo (Happykiller/jarvis-releases).

.DESCRIPTION
  Mirrors the koa-releases process: the source repo builds the artifacts, then
  this script creates a `vX.Y.Z` GitHub Release on the separate public releases
  repo with the MSI + NSIS setup.exe attached and SHA256 fingerprints in the body.

  Requires: gh (authenticated), Node/npm, Rust on PATH, and a prior build unless
  the script runs one.

.PARAMETER SkipBuild
  Reuse the existing bundles under src-tauri/target/release/bundle instead of
  running `npm run tauri build`.

.PARAMETER NotesFile
  Path to a Markdown file with the human-written release notes. If omitted, a
  minimal template is used. The SHA256 verification section is always appended.

.PARAMETER Draft
  Create the release as a draft (for review) instead of publishing it.

.EXAMPLE
  ./scripts/publish-release.ps1 -NotesFile notes/2.3.3.md -Draft
#>
[CmdletBinding()]
param(
    [switch] $SkipBuild,
    [string] $NotesFile,
    [switch] $Draft
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Dedicated public releases repo (README + assets + GitHub Releases only).
$RELEASES_REPO = "Happykiller/jarvis-releases"

# Repo root = parent of this script's folder.
$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

function Write-Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Fail($msg) { Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }

# --- Preflight ---------------------------------------------------------------
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Fail "gh (GitHub CLI) not found on PATH. Install it and run 'gh auth login'."
}

# --- Version -----------------------------------------------------------------
$configPath = Join-Path $RepoRoot "jarvis.config.json"
if (-not (Test-Path $configPath)) { Fail "jarvis.config.json not found at $configPath" }
$version = (Get-Content $configPath -Raw | ConvertFrom-Json).version
if ([string]::IsNullOrWhiteSpace($version)) { Fail "Could not read 'version' from jarvis.config.json" }
$tag = "v$version"
Write-Step "Publishing Jarvis $version (tag $tag) to $RELEASES_REPO"

# Refuse to overwrite an existing release for this tag.
$existing = gh release view $tag --repo $RELEASES_REPO 2>$null
if ($LASTEXITCODE -eq 0) {
    Fail "Release $tag already exists on $RELEASES_REPO. Bump the version first."
}

# --- Build -------------------------------------------------------------------
if (-not $SkipBuild) {
    Write-Step "Stopping any running Jarvis instance"
    Get-Process jarvis -ErrorAction SilentlyContinue | Stop-Process -Force

    Write-Step "Building installers (npm run tauri build)"
    $cargoBin = Join-Path $env:USERPROFILE ".cargo\bin"
    if (Test-Path $cargoBin) { $env:PATH = "$cargoBin;$env:PATH" }
    npm run tauri build
    if ($LASTEXITCODE -ne 0) { Fail "tauri build failed (exit $LASTEXITCODE)" }
} else {
    Write-Step "Skipping build (-SkipBuild)"
}

# --- Locate bundles ----------------------------------------------------------
$bundleDir = Join-Path $RepoRoot "src-tauri\target\release\bundle"
$srcSetup  = Join-Path $bundleDir "nsis\Jarvis_${version}_x64-setup.exe"
$srcMsi    = Join-Path $bundleDir "msi\Jarvis_${version}_x64_en-US.msi"
foreach ($f in @($srcSetup, $srcMsi)) {
    if (-not (Test-Path $f)) { Fail "Expected bundle not found: $f (build first, or drop -SkipBuild)" }
}

# --- Stage renamed copies ----------------------------------------------------
$distDir = Join-Path $RepoRoot "dist-release"
New-Item -ItemType Directory -Force -Path $distDir | Out-Null
$outSetup = Join-Path $distDir "Jarvis-${version}-x64-setup.exe"
$outMsi   = Join-Path $distDir "Jarvis-${version}-x64.msi"
Copy-Item $srcSetup $outSetup -Force
Copy-Item $srcMsi   $outMsi   -Force

# --- Fingerprints ------------------------------------------------------------
$hashSetup = (Get-FileHash $outSetup -Algorithm SHA256).Hash.ToLower()
$hashMsi   = (Get-FileHash $outMsi   -Algorithm SHA256).Hash.ToLower()
Write-Step "SHA256 setup.exe : $hashSetup"
Write-Step "SHA256 msi       : $hashMsi"

# --- Release body ------------------------------------------------------------
if ($NotesFile) {
    if (-not (Test-Path $NotesFile)) { Fail "NotesFile not found: $NotesFile" }
    $notes = Get-Content $NotesFile -Raw
} else {
    $notes = "# Jarvis $version`n`n_Notes de version a completer._"
}

$nameSetup = Split-Path $outSetup -Leaf
$nameMsi   = Split-Path $outMsi   -Leaf

$verify = @"

---

## Verification des empreintes (SHA256)

| Fichier | SHA256 |
|---|---|
| ``$nameSetup`` | ``$hashSetup`` |
| ``$nameMsi`` | ``$hashMsi`` |

Le paquet n'est pas signe : Windows affichera "Windows a protege votre ordinateur".
Ce n'est pas une menace detectee, c'est l'absence de signature. Avant de lancer,
deux gestes dans PowerShell :

``````powershell
# 1. Verifier l'empreinte (doit correspondre au tableau ci-dessus)
Get-FileHash .\$nameSetup -Algorithm SHA256

# 2. Retirer le marquage "telecharge depuis Internet"
Unblock-File .\$nameSetup
``````
"@

$body = $notes + "`n" + $verify
$tmpNotes = Join-Path $env:TEMP "jarvis-release-$version.md"
Set-Content -Path $tmpNotes -Value $body -Encoding utf8

# --- Publish -----------------------------------------------------------------
Write-Step "Creating GitHub release $tag on $RELEASES_REPO"
$ghArgs = @(
    "release", "create", $tag,
    "--repo", $RELEASES_REPO,
    "--title", "Jarvis $version",
    "--notes-file", $tmpNotes,
    $outSetup, $outMsi
)
if ($Draft) { $ghArgs += "--draft" }

& gh @ghArgs
if ($LASTEXITCODE -ne 0) { Fail "gh release create failed (exit $LASTEXITCODE)" }

$url = gh release view $tag --repo $RELEASES_REPO --json url --jq ".url"
Write-Step "Done. Release: $url"
if ($Draft) { Write-Host "This is a DRAFT - review it, then publish from the GitHub UI or with 'gh release edit $tag --repo $RELEASES_REPO --draft=false'." -ForegroundColor Yellow }
