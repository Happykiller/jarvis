# Jarvis tray icon

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:ScriptDir = $PSScriptRoot
$script:JarvisVersion = "1.1.0"

function Start-DevSetup {
    param(
        [ValidateSet("bootstrap", "start", "debug", "full")]
        [string]$Mode,

        [switch]$ShowConsole
    )

    $arguments = @(
        "-ExecutionPolicy", "Bypass",
        "-File", "`"$($script:ScriptDir)\dev-setup.ps1`"",
        "-Mode", $Mode
    )

    if ($Mode -eq "debug") {
        $arguments += "-OpenDevTools"
    }

    if ($ShowConsole) {
        $arguments += "-ShowConsole"
    }

    if ($ShowConsole) {
        Start-Process "powershell" -ArgumentList $arguments
    } else {
        Start-Process "powershell" -ArgumentList (@("-WindowStyle", "Hidden") + $arguments)
    }
}

$icon = New-Object System.Drawing.Icon("$script:ScriptDir\jarvis.ico")

$tray = New-Object System.Windows.Forms.NotifyIcon
$tray.Icon = $icon
$tray.Text = "Jarvis v$($script:JarvisVersion)"
$tray.Visible = $true

$menu = New-Object System.Windows.Forms.ContextMenuStrip

$itemVersion = New-Object System.Windows.Forms.ToolStripMenuItem("Jarvis v$($script:JarvisVersion)")
$itemVersion.Enabled = $false
$itemVersion.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$menu.Items.Add($itemVersion) | Out-Null

$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null

$itemStart = New-Object System.Windows.Forms.ToolStripMenuItem("Quick Start")
$itemStart.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$itemStart.Add_Click({
    Start-DevSetup -Mode "start"
})
$menu.Items.Add($itemStart) | Out-Null

$itemDebug = New-Object System.Windows.Forms.ToolStripMenuItem("Debug Start")
$itemDebug.Add_Click({
    Start-DevSetup -Mode "debug"
})
$menu.Items.Add($itemDebug) | Out-Null

$itemBootstrap = New-Object System.Windows.Forms.ToolStripMenuItem("Bootstrap Deps")
$itemBootstrap.Add_Click({
    Start-DevSetup -Mode "bootstrap" -ShowConsole
})
$menu.Items.Add($itemBootstrap) | Out-Null

$itemVisibleDebug = New-Object System.Windows.Forms.ToolStripMenuItem("Debug Start With Console")
$itemVisibleDebug.Add_Click({
    Start-DevSetup -Mode "debug" -ShowConsole
})
$menu.Items.Add($itemVisibleDebug) | Out-Null

$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null

$script:startupLnk = [IO.Path]::Combine([Environment]::GetFolderPath("Startup"), "Jarvis.lnk")
$itemStartup = New-Object System.Windows.Forms.ToolStripMenuItem
$itemStartup.Text = if (Test-Path $script:startupLnk) { "Remove From Windows Startup" } else { "Add To Windows Startup" }
$itemStartup.Add_Click({
    if (Test-Path $script:startupLnk) {
        Remove-Item $script:startupLnk -Force
        $itemStartup.Text = "Add To Windows Startup"
    } else {
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($script:startupLnk)
        $shortcut.TargetPath = "wscript.exe"
        $shortcut.Arguments = "`"$($script:ScriptDir)\jarvis-tray.vbs`""
        $shortcut.WorkingDirectory = $script:ScriptDir
        $shortcut.Save()
        $itemStartup.Text = "Remove From Windows Startup"
    }
})
$menu.Items.Add($itemStartup) | Out-Null

$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null

$itemExit = New-Object System.Windows.Forms.ToolStripMenuItem("Quit Jarvis")
$itemExit.Add_Click({
    $tray.Visible = $false
    $tray.Dispose()
    [System.Windows.Forms.Application]::Exit()
})
$menu.Items.Add($itemExit) | Out-Null

$tray.ContextMenuStrip = $menu

$tray.Add_DoubleClick({
    Start-DevSetup -Mode "start"
})

[System.Windows.Forms.Application]::Run()
