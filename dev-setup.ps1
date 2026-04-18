# DraftDream Dev Setup

$LogFile = "$PSScriptRoot\dev-setup.log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $line
    Write-Host $line
}

# Nouveau run : separateur dans le log
Add-Content -Path $LogFile -Value ""
Add-Content -Path $LogFile -Value ("=" * 60)
Write-Log "Demarrage du setup DraftDream"

# --- Assemblies ---
try {
    Add-Type -AssemblyName System.Windows.Forms
    Write-Log "System.Windows.Forms charge"
} catch {
    Write-Log "ERREUR chargement System.Windows.Forms : $_" "ERROR"
    exit 1
}

try {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class User32 {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
}
"@
    Write-Log "User32 charge"
} catch {
    Write-Log "ERREUR chargement User32 : $_" "ERROR"
    exit 1
}

# Coordonnees de l'ecran 1 (ecran principal)
try {
    $screen1 = [System.Windows.Forms.Screen]::PrimaryScreen
    $sx = $screen1.Bounds.X
    $sy = $screen1.Bounds.Y
    Write-Log "Ecran principal detecte : X=$sx Y=$sy W=$($screen1.Bounds.Width) H=$($screen1.Bounds.Height)"
} catch {
    Write-Log "ERREUR detection ecran : $_" "ERROR"
    exit 1
}

# --- Lancement de Windows Terminal ---
try {
    Write-Log "Lancement de Windows Terminal..."
    $wtArgs = @(
        '--maximized', '--pos', "${sx},${sy}",
        'new-tab', '--title', 'LazyGit',     '--profile', 'Debian', '--', 'wsl', '-e', 'bash', '-lic', 'cd /home/admin/DraftDream && lazygit && exec bash || exec bash',
        ';', 'new-tab', '--title', 'Claude',      '--profile', 'Debian', '--', 'wsl', '-e', 'bash', '-lic', 'cd /home/admin/DraftDream && claude --enable-auto-mode && exec bash || exec bash',
        ';', 'new-tab', '--title', 'api',         '--profile', 'Debian', '--', 'wsl', '-e', 'bash', '-lic', 'cd /home/admin/DraftDream/api && npx npm-check-updates --target minor -u && npm install && npm run start:dev && exec bash || exec bash',
        ';', 'new-tab', '--title', 'backoffice',  '--profile', 'Debian', '--', 'wsl', '-e', 'bash', '-lic', 'cd /home/admin/DraftDream/backoffice && npx npm-check-updates --target minor -u && npm install && npm run dev && exec bash || exec bash',
        ';', 'new-tab', '--title', 'frontoffice', '--profile', 'Debian', '--', 'wsl', '-e', 'bash', '-lic', 'cd /home/admin/DraftDream/frontoffice && npx npm-check-updates --target minor -u && npm install && npm run dev && exec bash || exec bash',
        ';', 'new-tab', '--title', 'showcase',    '--profile', 'Debian', '--', 'wsl', '-e', 'bash', '-lic', 'cd /home/admin/DraftDream/showcase && npx npm-check-updates --target minor -u && npm install && npm run dev && exec bash || exec bash',
        ';', 'new-tab', '--title', 'sandbox',     '--profile', 'Debian', '--', 'wsl', '-e', 'bash', '-lic', 'cd /home/admin/DraftDream && exec bash'
    )
    & wt @wtArgs
    Write-Log "Windows Terminal lance"
} catch {
    Write-Log "ERREUR lancement Windows Terminal : $_" "ERROR"
    exit 1
}

# --- Lancement de VS Code ---
try {
    $wslProject = "\\wsl.localhost\Debian\home\admin\DraftDream"
    Write-Log "Lancement VS Code sur $wslProject"
    Start-Process "code" -ArgumentList @($wslProject)
    Write-Log "VS Code lance"
} catch {
    Write-Log "ERREUR lancement VS Code : $_" "ERROR"
}

# --- Surveillance des serveurs ---
function Test-Port {
    param([int]$Port)
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $async = $tcp.BeginConnect("localhost", $Port, $null, $null)
        $ok = $async.AsyncWaitHandle.WaitOne(1000, $false)
        $tcp.Close()
        return $ok
    } catch {
        return $false
    }
}

$ports = @(5173, 5174, 5175)
Write-Log "Surveillance des ports : $($ports -join ', ')"

while ($true) {
    $statuses = $ports | ForEach-Object {
        $ok = Test-Port $_
        if ($ok) { "[$($_): OK]" } else { "[$($_): ...]" }
    }
    Write-Host ("`r" + ($statuses -join "  ")) -NoNewline
    if (-not ($ports | Where-Object { -not (Test-Port $_) })) { break }
    Start-Sleep -Seconds 2
}

Write-Log "Tous les serveurs sont prets"

# --- Lancement de Chrome ---
try {
    $chromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
    if (-not (Test-Path $chromePath)) {
        $chromePath = "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
        if (-not (Test-Path $chromePath)) {
            Write-Log "Chrome introuvable" "ERROR"
            exit 1
        }
    }
    Write-Log "Chrome trouve : $chromePath"

    $chromeArgs = "--remote-debugging-port=9222 --user-data-dir=`"C:\Users\fabri\AppData\Local\Google\Chrome\User Data`" --profile-directory=`"Profile 9`" --window-position=${sx},${sy} --start-maximized --new-window http://localhost:5173/ http://localhost:5174/ http://localhost:5175/"
    Write-Log "Lancement Chrome avec args : $chromeArgs"
    Start-Process $chromePath -ArgumentList $chromeArgs
    Write-Log "Chrome lance"
} catch {
    Write-Log "ERREUR lancement Chrome : $_" "ERROR"
    exit 1
}

# --- Recherche fenetre Chrome ---
$mainHandle = [IntPtr]::Zero
$deadline = [DateTime]::Now.AddSeconds(15)
Write-Log "Recherche fenetre Chrome..."

while ([DateTime]::Now -lt $deadline -and $mainHandle -eq [IntPtr]::Zero) {
    $win = Get-Process -Name chrome -ErrorAction SilentlyContinue |
           Where-Object { $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle -ne "" } |
           Select-Object -First 1
    if ($win) {
        $mainHandle = $win.MainWindowHandle
        Write-Log "Fenetre Chrome trouvee : '$($win.MainWindowTitle)' (handle: $mainHandle)"
    }
    Start-Sleep -Milliseconds 500
}

# --- Attente des 3 onglets via CDP ---
$pageTabs = @()
$deadline = [DateTime]::Now.AddSeconds(20)
Write-Log "Attente des onglets Chrome via CDP (port 9222)..."

while ([DateTime]::Now -lt $deadline) {
    try {
        $tabs = Invoke-RestMethod "http://localhost:9222/json/list" -ErrorAction Stop
        $pageTabs = @($tabs | Where-Object { $_.type -eq "page" })
        if ($pageTabs.Count -ge 3) {
            Write-Log "$($pageTabs.Count) onglets detectes via CDP"
            break
        }
    } catch { }
    Start-Sleep -Milliseconds 500
}

# --- Ouverture des DevTools via CDP + F12 ---
if ($pageTabs.Count -ge 3 -and $mainHandle -ne [IntPtr]::Zero) {
    foreach ($tab in $pageTabs) {
        Write-Log "Ouverture DevTools : $($tab.url)"
        # Activer l'onglet via CDP (evite le Ctrl+N qui rate apres ouverture DevTools)
        try { Invoke-RestMethod "http://localhost:9222/json/activate/$($tab.id)" | Out-Null } catch { }
        Start-Sleep -Milliseconds 600
        [User32]::ShowWindow($mainHandle, 9) | Out-Null
        [User32]::SetForegroundWindow($mainHandle) | Out-Null
        Start-Sleep -Milliseconds 600
        [System.Windows.Forms.SendKeys]::SendWait("{F12}")
        Start-Sleep -Milliseconds 1500
    }
    Write-Log "DevTools ouverts sur les 3 onglets"
} else {
    Write-Log "Impossible d'ouvrir les DevTools (onglets: $($pageTabs.Count), handle: $mainHandle)" "WARN"
}

Write-Log "Setup termine"
