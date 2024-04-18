using module ".\UnlockUsers_assemblies.psm1" #gui assemblies

using module ".\LockedGuiInterface.psm1" #gui interface class

using module ".\UnlockUsers_classes.psm1" #classes

#$VerbosePreference = "Continue" #uncomment for verbose (in fact works only outside)

Set-Variable -Name ULVersion -Value "1.3.0" -Option ReadOnly -Force -Scope global

Write-Verbose "UL Version is: $global:ULVersion"

#main

#btr idea:

$lgui = [LockedGui]::new() #no params

$usersunl_worker = [UsersUnlocker]::new($lgui) #accepts the gui object (can be other)

$usersunl_worker.Run()

Remove-Variable -Name ULVersion -Force -Scope global

Write-Verbose "(after worker.Run()) UL Version variable removed"
