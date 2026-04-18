Dim dir : dir = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
CreateObject("WScript.Shell").Run "powershell -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & dir & "\jarvis-tray.ps1""", 0, False
