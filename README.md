# UnlockADUsers
Powershell compiled executable gui for  unlocking massive locked AD Users.

- Windows executable tool for unlocking any locked AD users.  
(this version is compiled with PS2EXE-GUI v0.5.0.34 by Ingo Karstein, reworked and GUI support by Markus Scholtes)
<!-- two spaces  for ordinary newline (after 'users') -->

- The current PowerShell source uses .NET System.DirectoryServices directly and does not require RSAT or the ActiveDirectory PowerShell module. (assisted by ChantGPT Codex for this.)

- Unlocking writes zero to lockoutTime.

- Run the source with `powershell.exe -NoProfile -File .\UnlockADUsersGuiStart.ps1` or `powershell.exe -NoProfile -File .\UnlockADUsersAll.ps1` or just run the exe (better, see credentials).

-The exe is compiled from UnlockADUsersAll.ps1 file.

- For normal work, executing the exe or ps1 must be done by user with appropriate rights on AD.

- The interface is intuitive
