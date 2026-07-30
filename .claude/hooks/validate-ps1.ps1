#Requires -Version 5.1
# PostToolUse hook: after Claude edits a .ps1, validate its PowerShell syntax.
# PS 5.1 reads scripts as Windows-1252 without a BOM, so a stray non-ASCII char or
# a broken construct crashes the script silently at run time. Catching it here,
# right after the edit, means Claude fixes it before it ships.
#
# Reads the tool payload as JSON on stdin, looks at tool_input.file_path; if it is
# a .ps1, parses it. On parse errors, emits a decision:block so Claude corrects it.
# Any other case exits 0 silently - never block non-.ps1 work.

try {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }

    $payload = $raw | ConvertFrom-Json
    $path = $payload.tool_input.file_path
    if ([string]::IsNullOrWhiteSpace($path)) { exit 0 }
    if ($path -notmatch '\.ps1$') { exit 0 }
    if (-not (Test-Path $path)) { exit 0 }

    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$errors) | Out-Null
    if ($errors.Count -eq 0) { exit 0 }

    $lines = $errors | ForEach-Object { "Line $($_.Extent.StartLineNumber): $($_.Message)" }
    $reason = "PowerShell syntax errors in $path (fix before continuing):`n" + ($lines -join "`n") +
        "`nReminder: .ps1 files must be ASCII-only (no accents/em-dash) - see docs/KB/REGLES/normes.md."

    [ordered]@{
        decision = "block"
        reason   = $reason
    } | ConvertTo-Json -Compress
    exit 0
}
catch {
    # Never let a hook failure block legitimate work.
    exit 0
}
