# DraftDream Dev Setup

[CmdletBinding()]
param(
    [ValidateSet("start", "debug")]
    [string]$Mode = "start",

    [int]$StartupTimeoutSeconds = 180,

    [int]$ChromeDebugPort = 9222,

    [string]$ChromeUserDataDir = "$env:LOCALAPPDATA\Google\Chrome\User Data",

    [string]$ChromeProfileDir = "",

    [switch]$ShowConsole,

    [switch]$SkipTerminal,

    [switch]$SkipCode,

    [switch]$SkipChrome,

    [switch]$OpenDevTools
)

$ErrorActionPreference = "Stop"

$JarvisVersion = "1.2.0"
$LogFile = Join-Path $PSScriptRoot "dev-setup.log"
$ProjectRoot = "/home/admin/DraftDream"
$ProjectShare = "\\wsl.localhost\Debian\home\admin\DraftDream"
$ExtraUrls = @("https://dreamteamfitdesk.atlassian.net/jira/software/projects/FC/boards/34")

$UpdateAndStart = "npx npm-check-updates --target minor -u && npm install"

$ServiceDefinitions = @(
    @{ Name = "api";        Path = "$ProjectRoot/api";        Start = "$UpdateAndStart && npm run start:dev"; Port = 3000; Url = $null },
    @{ Name = "backoffice"; Path = "$ProjectRoot/backoffice"; Start = "$UpdateAndStart && npm run dev";       Port = 5174; Url = "http://localhost:5174/" },
    @{ Name = "frontoffice";Path = "$ProjectRoot/frontoffice";Start = "$UpdateAndStart && npm run dev";       Port = 5173; Url = "http://localhost:5173/" },
    @{ Name = "showcase";   Path = "$ProjectRoot/showcase";   Start = "$UpdateAndStart && npm run dev";       Port = 5175; Url = "http://localhost:5175/" }
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

function Start-TerminalTabs {
    param([hashtable]$Screen)

    if ($SkipTerminal) {
        Write-Log "Skipping Windows Terminal launch"
        return
    }

    $tabs = @(
        @{ Title = "LazyGit";  Command = New-WslCommand -WorkingDirectory $ProjectRoot -Command "lazygit" },
        @{ Title = "Claude";   Command = New-WslCommand -WorkingDirectory $ProjectRoot -Command "claude" }
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
        [int]$TimeoutSeconds
    )

    Write-Log "Waiting for ports: $($Ports -join ', ') with timeout ${TimeoutSeconds}s"

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)

    while ((Get-Date) -lt $deadline) {
        $pendingPorts = @($Ports | Where-Object { -not (Test-Port -Port $_) })
        if ($pendingPorts.Count -eq 0) {
            Write-Log "All expected ports are ready"
            return
        }

        if ($ShowConsole) {
            Write-Host ("Pending ports: " + ($pendingPorts -join ", "))
        }

        Start-Sleep -Seconds 2
    }

    $stillPending = @($Ports | Where-Object { -not (Test-Port -Port $_) })
    Write-Log "Timeout reached while waiting for ports: $($stillPending -join ', ')" "ERROR"
    throw "Startup timeout reached"
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
            Write-Log "=== PHASE: Terminal ===" "STEP"
            Start-TerminalTabs -Screen $screen
            Write-Log "=== PHASE: Editor ===" "STEP"
            Start-CodeEditor
            Write-Log "=== PHASE: Port wait ===" "STEP"
            Wait-ForPorts -Ports @($ServiceDefinitions.Port) -TimeoutSeconds $StartupTimeoutSeconds
            Write-Log "=== PHASE: Chrome ===" "STEP"
            Start-ChromeForServices -Screen $screen -EnableDevTools:$OpenDevTools
            Write-Log "Start mode completed" "STEP"
        }

        "debug" {
            Write-Log "=== PHASE: Terminal ===" "STEP"
            Start-TerminalTabs -Screen $screen
            Write-Log "=== PHASE: Editor ===" "STEP"
            Start-CodeEditor
            Write-Log "=== PHASE: Port wait ===" "STEP"
            Wait-ForPorts -Ports @($ServiceDefinitions.Port) -TimeoutSeconds $StartupTimeoutSeconds
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
