#Requires -Version 5.1
# Stop hook: asks Claude to update CLAUDE.md with session learnings.
# Flag file breaks the loop: first stop = prompt Claude; second stop = allow exit.
$flag = 'C:\DATA\projects\jarvis\.claude\stop-hook-ran.flag'

if (Test-Path $flag) {
    Remove-Item $flag -Force
    Write-Output '{"continue": true}'
} else {
    $null = New-Item -Path $flag -ItemType File -Force
    $reason = 'Before ending the session, review what was discovered. If any new rules, pitfalls, Windows/PowerShell quirks, or Jarvis architecture facts came up, add them to CLAUDE.md at C:\DATA\projects\jarvis\CLAUDE.md. Keep additions short and actionable. If nothing new, just stop.'
    [ordered]@{
        continue          = $false
        stopReason        = $reason
        hookSpecificOutput = [ordered]@{
            hookEventName    = 'Stop'
            additionalContext = $reason
        }
    } | ConvertTo-Json -Compress
}
