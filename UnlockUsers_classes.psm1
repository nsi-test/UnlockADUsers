#[Void][reflection.assembly]::loadwithpartialname('System.Windows.Forms')
#[Void][reflection.assembly]::loadwithpartialname('System.Drawing')
#cannot be used like this

using module ".\IconB64.psm1"

Write-Verbose "IconB64 imported"
#Write-Verbose $(GetIconB64)

class UsersUnlocker {
	
	[System.Object] $lgui
	
	#constructor
	UsersUnlocker([System.Object] $lgui) { #he doesn't know the exact type
	
		$unlocker_funs = [PSCustomObject]@{
				'GetLUsers'=$this.GetLUsers
				'UnlockLUsers'=$this.UnlockLUsers
				}	

		$this.lgui = $lgui
		#this.lgui accepts the fn object... (the two lgui are the same in fact...)
		$this.lgui.GetOuterFnObject($unlocker_funs) #the function's name should be formally known...
		
	} #constructor

	[System.Object[]] GetLUsers() {
		return $(Get-ADUser -Filter * -Properties SamAccountname, badPwdCount, badPasswordTime, lockedout, enabled | Where-Object {$_.lockedout -eq "True"} | % {
		New-Object PSObject -Property @{
        username = $_.SamAccountname
        badPwdCount = $_.badPwdCount
        badPasswordTime = [DateTime]::FromFileTime($_.badPasswordTime)
        enabled = $_.enabled
      }
    } | Sort-Object -Property badPasswordTime)
	} #GetUsers fn
	
	[System.Object] UnlockLUsers([System.Object[]] $UserData, [bool] $enabledonly) {
		Write-Verbose "in UnlockLUsers, UserUnlocker: $UserData"
		Write-Verbose "$($UserData.gettype())"
		
		if (! $UserData) {$UserData = @()} #(!)
		$message = ""
		$unlockednum = 0
		
		$UserData | % {
			if (! $_.enabled -and $enabledonly) {
				"$($_.username) is disabled - remains locked" | Tee-Object -variable msg | Write-Verbose
				Write-Verbose "in if enabled, user: $($_.username)"

				$message += "$msg`r`n"
				$msg = ""
				return
				#return instead of continue
			} #if enabled
        
			$message += "$(if (!$_.Enabled) {"(disabled) "})" #maj stava i s dvete "
			$msg = ""
		
			$username = $_.username
			$global:error.clear()
			Try {	
				Unlock-ADAccount -Identity $_.username
			}
			Catch {
				"unlockling $username error: $($global:error.Exception.Message)" | Tee-Object -variable msg | Write-Verbose
				$message += "$msg`r`n"
				$msg = ""
			}
			Finally {
				If (! $global:error) {
					"$($_.username) unlocked" | Tee-Object -variable msg | Write-Verbose
					$message += "$msg`r`n"
					$msg = ""
					$unlockednum += 1
				} #if error
			} #finally	
			
		} #%
		
		return @{"message" = $message; "unlockednum" = $unlockednum}
	} #UnlockLUsers fn

	[void] Run() {
		$this.lgui.Show()
	}

} #class UnlockUsers

