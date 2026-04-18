# Jarvis - Icone systray

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:ScriptDir = $PSScriptRoot

# --- Icone personnalisee ---
$icon = New-Object System.Drawing.Icon("$script:ScriptDir\jarvis.ico")

# --- NotifyIcon ---
$tray = New-Object System.Windows.Forms.NotifyIcon
$tray.Icon    = $icon
$tray.Text    = "Jarvis"
$tray.Visible = $true

# --- Menu contextuel ---
$menu = New-Object System.Windows.Forms.ContextMenuStrip

$itemLaunch = New-Object System.Windows.Forms.ToolStripMenuItem("Lancer Dev Setup")
$itemLaunch.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$itemLaunch.Add_Click({
    Start-Process "powershell" -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$($script:ScriptDir)\dev-setup.ps1`""
})
$menu.Items.Add($itemLaunch) | Out-Null

$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null

# Option demarrage Windows
$script:startupLnk = [IO.Path]::Combine([Environment]::GetFolderPath("Startup"), "Jarvis.lnk")
$itemStartup = New-Object System.Windows.Forms.ToolStripMenuItem
$itemStartup.Text = if (Test-Path $script:startupLnk) { "Retirer du demarrage Windows" } else { "Ajouter au demarrage Windows" }
$itemStartup.Add_Click({
    if (Test-Path $script:startupLnk) {
        Remove-Item $script:startupLnk -Force
        $itemStartup.Text = "Ajouter au demarrage Windows"
    } else {
        $shell = New-Object -ComObject WScript.Shell
        $sc = $shell.CreateShortcut($script:startupLnk)
        $sc.TargetPath = "wscript.exe"
        $sc.Arguments  = "`"$($script:ScriptDir)\jarvis-tray.vbs`""
        $sc.WorkingDirectory = $script:ScriptDir
        $sc.Save()
        $itemStartup.Text = "Retirer du demarrage Windows"
    }
})
$menu.Items.Add($itemStartup) | Out-Null

$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null

$itemExit = New-Object System.Windows.Forms.ToolStripMenuItem("Quitter Jarvis")
$itemExit.Add_Click({
    $tray.Visible = $false
    $tray.Dispose()
    [System.Windows.Forms.Application]::Exit()
})
$menu.Items.Add($itemExit) | Out-Null

$tray.ContextMenuStrip = $menu

# Double-clic = lancer le setup
$tray.Add_DoubleClick({
    Start-Process "powershell" -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$($script:ScriptDir)\dev-setup.ps1`""
})

# Boucle evenements Windows
[System.Windows.Forms.Application]::Run()
