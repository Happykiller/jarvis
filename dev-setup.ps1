# DraftDream Dev Setup

[CmdletBinding()]
param(
    [ValidateSet("start", "debug")]
    [string]$Mode = "start",

    [int]$StartupTimeoutSeconds = 180,

    [int]$ChromeDebugPort = 9222,

    [string]$ChromeUserDataDir = "$env:LOCALAPPDATA\Google\Chrome\User Data",

    [string]$ChromeProfileDir = "Profile 10",

    [switch]$ShowConsole,

    [switch]$SkipTerminal,

    [switch]$SkipCode,

    [switch]$SkipChrome,

    [switch]$OpenDevTools
)

$ErrorActionPreference = "Stop"

$JarvisVersion = "1.5.0"
$LogFile = Join-Path $PSScriptRoot "dev-setup.log"
$ProjectRoot = "/home/admin/valtys"
$ProjectShare = "\\wsl.localhost\Debian\home\admin\valtys"
$ExtraUrls = @(
    "https://mail.google.com/",
    "https://bo.fitdesk.io/",
    "https://dreamteamfitdesk.atlassian.net/jira/software/projects/FC/boards/34",
    "http://localhost:1080/"
)

$UpdateAndStart = "git pull && npx npm-check-updates --target minor -u && npm install"

$DockerParallelServices = @(
    @{ Name = "punjabi";     Path = "/home/admin/punjabi";            Command = "make up";     Network = $null         },
    @{ Name = "alexstrasza"; Path = "/home/admin/valtys/alexstrasza"; Command = "make dev-up"; Network = "alexstrasza" },
    @{ Name = "afkah";       Path = "/home/admin/valtys/afkah";       Command = "make dev-up"; Network = "afkah"       }
)

$DockerSequentialServices = @(
    @{ Name = "eudora"; Path = "/home/admin/valtys/eudora"; Command = "docker compose up eudora-dev eudora-worker -d"; WaitHealthy = "alexstrasza"; HealthTimeoutSeconds = 60 }
)

$ServiceDefinitions = @(
    @{ Name = "api";        Path = "$ProjectRoot/onyxia";        Start = "$UpdateAndStart && npm run start:dev"; Port = 3000; Url = $null },
    @{ Name = "backoffice"; Path = "$ProjectRoot/sylvanas"; Start = "$UpdateAndStart && npm run dev";       Port = 5174; Url = "http://localhost:5174/" },
    @{ Name = "frontoffice";Path = "$ProjectRoot/tess";Start = "$UpdateAndStart && npm run dev";       Port = 5173; Url = "http://localhost:5173/" },
    @{ Name = "showcase";   Path = "$ProjectRoot/xyrella";   Start = "$UpdateAndStart && npm run dev";       Port = 5175; Url = "http://localhost:5175/" }
)

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR", "STEP", "DEBUG")]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $line

    if ($ShowConsole) {
        switch ($Level) {
            "ERROR" { Write-Host $line -ForegroundColor Red }
            "WARN"  { Write-Host $line -ForegroundColor Yellow }
            "STEP"  { Write-Host $line -ForegroundColor Cyan }
            "DEBUG" { Write-Host $line -ForegroundColor DarkGray }
            default { Write-Host $line }
        }
    } elseif ($Level -in @("WARN", "ERROR")) {
        Write-Host $line -ForegroundColor $(if ($Level -eq "ERROR") { "Red" } else { "Yellow" })
    }
}

function Initialize-Log {
    Add-Content -Path $LogFile -Value ""
    Add-Content -Path $LogFile -Value ("=" * 60)
    Write-Log "Jarvis v$JarvisVersion | mode=$Mode | screen=$($env:COMPUTERNAME)" "STEP"
    Write-Log "ChromeUserDataDir : $ChromeUserDataDir"
    Write-Log "ChromeProfileDir  : $(if ($ChromeProfileDir) { $ChromeProfileDir } else { '(default)' })"
    Write-Log "ProjectRoot       : $ProjectRoot"
}

function Enter-SetupMutex {
    $createdNew = $false
    $mutex = New-Object System.Threading.Mutex($true, "Local\JarvisDraftDreamSetup", [ref]$createdNew)

    if (-not $createdNew) {
        throw "Another setup instance is already running"
    }

    return $mutex
}

function Ensure-Assembly {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        Write-Log "Loaded System.Windows.Forms"
    } catch {
        Write-Log "Failed to load System.Windows.Forms: $_" "ERROR"
        exit 1
    }

    try {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class User32 {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@
        Write-Log "Loaded User32 interop"
    } catch {
        Write-Log "Failed to load User32 interop: $_" "ERROR"
        exit 1
    }
}

function Get-ScreenPosition {
    try {
        $screen = [System.Windows.Forms.Screen]::PrimaryScreen
        $position = @{
            X = $screen.Bounds.X
            Y = $screen.Bounds.Y
            Width = $screen.Bounds.Width
            Height = $screen.Bounds.Height
        }
        Write-Log "Primary screen detected: X=$($position.X) Y=$($position.Y) W=$($position.Width) H=$($position.Height)"
        return $position
    } catch {
        Write-Log "Failed to detect primary screen: $_" "ERROR"
        exit 1
    }
}

function New-WslCommand {
    param(
        [string]$WorkingDirectory,
        [string]$Command
    )

    return "cd $WorkingDirectory && $Command && exec bash || exec bash"
}

function Start-DockerServices {
    # Phase 1 - punjabi, alexstrasza, afkah en parall?le
    Write-Log "Docker Phase 1 (parallel): $($DockerParallelServices.Name -join ', ')" "STEP"

    $jobs = [ordered]@{}
    foreach ($svc in $DockerParallelServices) {
        $jobs[$svc.Name] = Start-Job -ArgumentList $svc.Path, $svc.Network, $svc.Command -ScriptBlock {
            param($path, $network, $cmd)
            if ($network) {
                wsl bash -c "docker network create '$network' 2>/dev/null; true"
            }
            wsl bash -c "cd '$path' && $cmd 2>&1"
        }
    }

    $jobs.Values | Wait-Job | Out-Null

    $failed = @()
    foreach ($name in $jobs.Keys) {
        $job = $jobs[$name]
        $out = (Receive-Job -Job $job | Out-String).Trim()
        $state = $job.State
        Remove-Job -Job $job
        Write-Log "Docker ${name}: $out"
        if ($state -eq "Failed") { $failed += $name }
    }
    if ($failed.Count -gt 0) {
        throw "Docker Phase 1 failed for: $($failed -join ', ')"
    }

    # Phase 2 - services s?quentiels avec d?pendances
    foreach ($svc in $DockerSequentialServices) {
        if ($svc.WaitHealthy) {
            Write-Log "Waiting for $($svc.WaitHealthy) healthcheck (timeout: $($svc.HealthTimeoutSeconds)s)..." "STEP"
            $deadline = (Get-Date).AddSeconds($svc.HealthTimeoutSeconds)
            $healthy = $false
            while ((Get-Date) -lt $deadline) {
                $health = (wsl bash -c "docker inspect $($svc.WaitHealthy) --format '{{.State.Health.Status}}' 2>/dev/null").Trim()
                Write-Log "$($svc.WaitHealthy) health: $health" "DEBUG"
                if ($health -eq "healthy") { $healthy = $true; break }
                Start-Sleep -Seconds 2
            }
            if (-not $healthy) {
                throw "Timeout: $($svc.WaitHealthy) did not become healthy within $($svc.HealthTimeoutSeconds)s"
            }
            Write-Log "$($svc.WaitHealthy): healthy"
        }

        Write-Log "Docker $($svc.Name): starting..." "STEP"
        $out = (wsl bash -c "cd '$($svc.Path)' && $($svc.Command) 2>&1" | Out-String).Trim()
        Write-Log "Docker $($svc.Name): $out"
    }

    # ?tat final
    Write-Log "Docker containers:" "STEP"
    $state = (wsl bash -c "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null" | Out-String).Trim()
    Write-Log $state
}

function Start-TerminalTabs {
    param([hashtable]$Screen)

    if ($SkipTerminal) {
        Write-Log "Skipping Windows Terminal launch"
        return
    }

    $tabs = @(
        @{ Title = "codex";    Command = New-WslCommand -WorkingDirectory $ProjectRoot -Command "codex" },
        @{ Title = "Claude";   Command = New-WslCommand -WorkingDirectory $ProjectRoot -Command "claude" },
        @{ Title = "agy";      Command = New-WslCommand -WorkingDirectory $ProjectRoot -Command "agy" }
    )
    $tabs += foreach ($service in $ServiceDefinitions) {
        @{ Title = $service.Name; Command = New-WslCommand -WorkingDirectory $service.Path -Command $service.Start }
    }
    $tabs += @{ Title = "sandbox"; Command = New-WslCommand -WorkingDirectory $ProjectRoot -Command "true" }

    Write-Log "Terminal tabs=$($tabs.Count)" "STEP"
    foreach ($tab in $tabs) {
        Write-Log ("  [" + $tab.Title + "] " + $tab.Command) "DEBUG"
    }

    $wtArgs = @("--maximized", "--pos", "$($Screen.X),$($Screen.Y)")
    $isFirstTab = $true

    foreach ($tab in $tabs) {
        if (-not $isFirstTab) {
            $wtArgs += ";"
        }

        $wtArgs += @(
            "new-tab",
            "--title", $tab.Title,
            "--profile", "Debian",
            "--",
            "bash", "-lic", $tab.Command
        )

        $isFirstTab = $false
    }

    try {
        Write-Log "Launching Windows Terminal" "STEP"
        & wt @wtArgs
        Write-Log "Windows Terminal launched"
    } catch {
        Write-Log "Failed to launch Windows Terminal: $_" "ERROR"
        exit 1
    }
}

function Start-CodeEditor {
    if ($SkipCode) {
        Write-Log "Skipping VS Code launch"
        return
    }

    try {
        Write-Log "Launching VS Code on $ProjectShare"
        Start-Process "code" -ArgumentList @($ProjectShare)
        Write-Log "VS Code launched"
    } catch {
        Write-Log "Failed to launch VS Code: $_" "WARN"
    }
}

function Start-MongoDBCompass {
    $compassPath = "C:\Users\fabri\AppData\Local\MongoDBCompass\MongoDBCompass.exe"
    if (-not (Test-Path $compassPath)) {
        Write-Log "MongoDB Compass not found at $compassPath" "WARN"
        return
    }

    try {
        Write-Log "Launching MongoDB Compass"
        Start-Process -FilePath $compassPath
        Write-Log "MongoDB Compass launched"
    } catch {
        Write-Log "Failed to launch MongoDB Compass: $_" "WARN"
    }
}

function Test-Port {
    param([int]$Port)

    $tcp = $null
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $async = $tcp.BeginConnect("127.0.0.1", $Port, $null, $null)
        return $async.AsyncWaitHandle.WaitOne(1000, $false)
    } catch {
        return $false
    } finally {
        if ($null -ne $tcp) {
            $tcp.Close()
        }
    }
}

function Wait-ForPorts {
    param(
        [int[]]$Ports,
        [int]$TimeoutSeconds,
        [hashtable]$Screen
    )

    Write-Log "Waiting for ports: $($Ports -join ', ') with timeout ${TimeoutSeconds}s" "STEP"

    $portNames = @{}
    foreach ($svc in $ServiceDefinitions) {
        $portNames[$svc.Port] = $svc.Name
    }

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Jarvis - Demarrage des services"
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedToolWindow
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
    $form.TopMost = $true
    $form.ShowInTaskbar = $false
    $form.Width = 360
    $form.Height = 50 + ($Ports.Count * 28) + 16

    $formX = $Screen.X + $Screen.Width - $form.Width - 16
    $formY = $Screen.Y + $Screen.Height - $form.Height - 48
    $form.Location = New-Object System.Drawing.Point($formX, $formY)

    $labels = @{}
    $yPos = 8
    foreach ($port in $Ports) {
        $svcName = if ($portNames.ContainsKey($port)) { $portNames[$port] } else { "port $port" }
        $lbl = New-Object System.Windows.Forms.Label
        $lbl.AutoSize = $false
        $lbl.Width = 330
        $lbl.Height = 22
        $lbl.Location = New-Object System.Drawing.Point(12, $yPos)
        $lbl.Text = "$svcName  :$port  -  en attente..."
        $lbl.ForeColor = [System.Drawing.Color]::DimGray
        $form.Controls.Add($lbl)
        $labels[$port] = $lbl
        $yPos += 26
    }

    $startTime = Get-Date
    $deadline = $startTime.AddSeconds($TimeoutSeconds)

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 1000

    $tickHandler = {
        $pending = @()
        foreach ($port in $Ports) {
            $lbl = $labels[$port]
            $svcName = if ($portNames.ContainsKey($port)) { $portNames[$port] } else { "port $port" }
            if (Test-Port -Port $port) {
                $lbl.Text = "$svcName  :$port  -  pret"
                $lbl.ForeColor = [System.Drawing.Color]::Green
            } else {
                $elapsed   = [int]((Get-Date) - $startTime).TotalSeconds
                $remaining = [Math]::Max(0, [int]($deadline - (Get-Date)).TotalSeconds)
                $lbl.Text  = "$svcName  :$port  -  ${elapsed}s  (reste ${remaining}s)"
                $lbl.ForeColor = [System.Drawing.Color]::DimGray
                $pending += $port
            }
        }

        if ($pending.Count -eq 0) {
            $timer.Stop()
            Write-Log "All expected ports are ready"
            Start-Sleep -Milliseconds 700
            $form.Close()
            return
        }

        if ((Get-Date) -gt $deadline) {
            $timer.Stop()
            foreach ($port in $pending) {
                $lbl = $labels[$port]
                $svcName = if ($portNames.ContainsKey($port)) { $portNames[$port] } else { "port $port" }
                $lbl.Text = "$svcName  :$port  -  TIMEOUT"
                $lbl.ForeColor = [System.Drawing.Color]::Red
                Write-Log "Timeout: $svcName (:$port) did not respond" "ERROR"
            }
        }
    }.GetNewClosure()

    $timer.Add_Tick($tickHandler)
    $form.Add_Shown({ $timer.Start() }.GetNewClosure())
    $form.ShowDialog() | Out-Null
    $timer.Dispose()
    $form.Dispose()

    $stillPending = @($Ports | Where-Object { -not (Test-Port -Port $_) })
    if ($stillPending.Count -gt 0) {
        $names = $stillPending | ForEach-Object {
            if ($portNames.ContainsKey($_)) { "$($portNames[$_]) (:$_)" } else { "port $_" }
        }
        throw "Startup timeout: $($names -join ', ') did not respond"
    }
}

function Get-ChromePath {
    $candidates = @(
        "C:\Program Files\Google\Chrome\Application\chrome.exe",
        "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
    )

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    return $null
}

function Get-ChromeUserDataArgs {
    $result = @("--user-data-dir=`"$ChromeUserDataDir`"")
    if ($ChromeProfileDir) {
        $result += "--profile-directory=`"$ChromeProfileDir`""
    }
    return $result
}

function Wait-ForChromeTargets {
    param(
        [int]$Port,
        [int]$ExpectedCount,
        [int]$TimeoutSeconds
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)

    while ((Get-Date) -lt $deadline) {
        try {
            $targets = Invoke-RestMethod "http://127.0.0.1:$Port/json/list" -ErrorAction Stop
            $pages = @($targets | Where-Object { $_.type -eq "page" })
            if ($pages.Count -ge $ExpectedCount) {
                Write-Log "Chrome CDP is ready with $($pages.Count) page targets on port $Port"
                return $pages
            }
        } catch {
        }

        Start-Sleep -Milliseconds 500
    }

    return @()
}

function Get-ChromeMainWindow {
    param([int]$ProcessId)

    $deadline = (Get-Date).AddSeconds(15)

    while ((Get-Date) -lt $deadline) {
        try {
            $process = Get-Process -Id $ProcessId -ErrorAction Stop
            if ($process.MainWindowHandle -ne 0) {
                Write-Log "Chrome window detected: '$($process.MainWindowTitle)' (PID: $ProcessId, handle: $($process.MainWindowHandle))"
                return $process.MainWindowHandle
            }
        } catch {
        }

        Start-Sleep -Milliseconds 500
    }

    return [IntPtr]::Zero
}

function Open-ChromeDevTools {
    param(
        [int]$Port,
        [System.IntPtr]$WindowHandle,
        [object[]]$Tabs
    )

    if ($WindowHandle -eq [IntPtr]::Zero) {
        Write-Log "Skipping DevTools automation because no Chrome window handle was found" "WARN"
        return
    }

    foreach ($tab in $Tabs) {
        Write-Log "Opening DevTools for $($tab.url)"
        try {
            Invoke-RestMethod "http://127.0.0.1:$Port/json/activate/$($tab.id)" -ErrorAction Stop | Out-Null
            Start-Sleep -Milliseconds 600
            [User32]::ShowWindow($WindowHandle, 9) | Out-Null
            [User32]::SetForegroundWindow($WindowHandle) | Out-Null
            Start-Sleep -Milliseconds 600
            [System.Windows.Forms.SendKeys]::SendWait("{F12}")
            Start-Sleep -Milliseconds 1200
        } catch {
            Write-Log "Failed to open DevTools for $($tab.url): $_" "WARN"
        }
    }

    Write-Log "DevTools opened for the requested tabs"
}

function Start-ChromeForServices {
    param(
        [hashtable]$Screen,
        [switch]$EnableDevTools
    )

    if ($SkipChrome) {
        Write-Log "Skipping Chrome launch"
        return
    }

    $chromePath = Get-ChromePath
    if (-not $chromePath) {
        Write-Log "Chrome executable not found" "ERROR"
        throw "Chrome not found"
    }

    $urls = $ExtraUrls + @($ServiceDefinitions | Where-Object { $null -ne $_.Url } | ForEach-Object { $_.Url })

    $chromeArgs = @(
        "--new-window",
        "--window-position=$($Screen.X),$($Screen.Y)",
        "--start-maximized"
    ) + (Get-ChromeUserDataArgs)

    if ($EnableDevTools) {
        $chromeArgs += "--remote-debugging-port=$ChromeDebugPort"
    }

    $chromeArgs += $urls

    Write-Log "Launching Chrome from $chromePath"
    Write-Log "Chrome user data: $ChromeUserDataDir$(if ($ChromeProfileDir) { " / $ChromeProfileDir" })"
    Write-Log "Chrome arguments: $($chromeArgs -join ' ')"

    $chromeProcess = Start-Process -FilePath $chromePath -ArgumentList $chromeArgs -PassThru
    Write-Log "Chrome launched with PID $($chromeProcess.Id)"

    if (-not $EnableDevTools) {
        return
    }

    $tabs = Wait-ForChromeTargets -Port $ChromeDebugPort -ExpectedCount $urls.Count -TimeoutSeconds 20
    if ($tabs.Count -lt $urls.Count) {
        Write-Log "Chrome CDP did not expose the expected tabs on port $ChromeDebugPort" "WARN"
        return
    }

    $chromeWindow = Get-ChromeMainWindow -ProcessId $chromeProcess.Id
    Open-ChromeDevTools -Port $ChromeDebugPort -WindowHandle $chromeWindow -Tabs $tabs[0..($urls.Count - 1)]
}

$setupMutex = $null

try {
    $setupMutex = Enter-SetupMutex
    Initialize-Log
    Ensure-Assembly
    $screen = Get-ScreenPosition

    switch ($Mode) {
        "start" {
            Write-Log "=== PHASE: Docker ===" "STEP"
            Start-DockerServices
            Write-Log "=== PHASE: Terminal ===" "STEP"
            Start-TerminalTabs -Screen $screen
            Write-Log "=== PHASE: Editor ===" "STEP"
            Start-CodeEditor
            Start-MongoDBCompass
            Write-Log "=== PHASE: Port wait ===" "STEP"
            Wait-ForPorts -Ports @($ServiceDefinitions.Port) -TimeoutSeconds $StartupTimeoutSeconds -Screen $screen
            Write-Log "=== PHASE: Chrome ===" "STEP"
            Start-ChromeForServices -Screen $screen -EnableDevTools:$OpenDevTools
            Write-Log "Start mode completed" "STEP"
        }

        "debug" {
            Write-Log "=== PHASE: Docker ===" "STEP"
            Start-DockerServices
            Write-Log "=== PHASE: Terminal ===" "STEP"
            Start-TerminalTabs -Screen $screen
            Write-Log "=== PHASE: Editor ===" "STEP"
            Start-CodeEditor
            Start-MongoDBCompass
            Write-Log "=== PHASE: Port wait ===" "STEP"
            Wait-ForPorts -Ports @($ServiceDefinitions.Port) -TimeoutSeconds $StartupTimeoutSeconds -Screen $screen
            Write-Log "=== PHASE: Chrome (DevTools) ===" "STEP"
            Start-ChromeForServices -Screen $screen -EnableDevTools:$true
            Write-Log "Debug mode completed" "STEP"
        }

        "full" {
            Write-Log "=== PHASE: Bootstrap ===" "STEP"
            Start-TerminalTabs -TerminalMode "bootstrap" -Screen $screen
            Write-Log "Bootstrap tabs launched. Run start or debug after deps are installed." "STEP"
        }
    }
} catch {
    Write-Log "Setup failed: $_" "ERROR"
    exit 1
} finally {
    if ($null -ne $setupMutex) {
        $setupMutex.ReleaseMutex() | Out-Null
        $setupMutex.Dispose()
        Write-Log "Setup mutex released"
    }
}
