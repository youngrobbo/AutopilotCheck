command = "powershell.exe -executionpolicy bypass -nologo -file " & chr(34) & "C:\Program Files\SAP-IT\AutoPilot\Start-AutoPilotCheck.ps1" & chr(34)
set shell = CreateObject("WScript.Shell")
shell.Run command,0