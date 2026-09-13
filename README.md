# UnlockADUsers
Powershell compiled executable gui for  unlocking massive locked AD Users.

- Windows executable tool for unlocking any locked AD users.  
(this version is compiled with PS2EXE-GUI v0.5.0.34 by Ingo Karstein, reworked and GUI support by Markus Scholtes)
<!-- two spaces  for ordinary newline (after 'users') -->

- This is a bump version, removing RSAT dependencies, helped by ChatGpt Codex

- Run the source with Windows PowerShell 5.1: `powershell.exe -NoProfile -STA -File .\UnlockADUsersGuiStart.ps1`.

- For normal work, executing the exe or ps1 must be done by user with appropriate rights on AD.

- The PowerShell source uses .NET System.DirectoryServices for LDAP searches and account unlocking; RSAT and the ActiveDirectory PowerShell module are not required. Unlocking clears lockoutTime using the current Windows credentials and requires permission to update that attribute.

- The interface is intuitive
