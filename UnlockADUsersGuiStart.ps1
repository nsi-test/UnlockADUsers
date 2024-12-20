using module ".\UnlockADUsersAssemblies.psm1" #gui assemblies

using module ".\LockedIconB64.psm1"
#Write-Verbose $(GetIconB64) #an old check

using module ".\LockedGuiInterface.psm1" #gui interface class

using module ".\UsersUnlockerWorker.psm1" #worker class

#$VerbosePreference = "Continue" #uncomment for verbose (in fact works only outside)

Set-Variable -Name ULVersion -Value "1.5.0" -Option ReadOnly -Force -Scope global

Write-Verbose "UL Version is: $global:ULVersion"

#main

$lgui = [LockedGui]::new()

$usersunl_worker = [UsersUnlocker]::new($lgui) #accepts the gui as an interface object (can be other)

$usersunl_worker.Run() #this function calls the Show() method of the interface

Remove-Variable -Name ULVersion -Force -Scope global

Write-Verbose "(after worker.Run()) UL Version variable removed"
