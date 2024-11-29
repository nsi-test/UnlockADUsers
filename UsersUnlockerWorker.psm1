class UsersUnlocker {
	
	[System.Object] $liface #this is the interface object member which is given in the constructor, it can be gui, cmdline, or whatever
	
	[Bool] $LUsersAreChanged #property signifying that results has been changed since the last operation
	
	[System.Object[]] $PreviousLUsers # an array with the previous state of the locked users data
	
	#constructor
	UsersUnlocker([System.Object] $liface) { #the exact type is not known here
	
		#the PSCustomObject containing the functions which are to be given to the interface
		$unlocker_funs = [PSCustomObject]@{
				'GetLUsers'=$this.GetLUsers
				'UnlockLUsers'=$this.UnlockLUsers
				'GetLUsersAreChanged'=$this.GetLUsersAreChanged
				}	

		#this.liface accepts the fubctions object... (the two liface are the same in fact...)
		$this.liface = $liface	
		#that function belongs to the interface, it accepts this object's functions for being used. The function's name should be formally known because the outer interfaces will use it
		$this.liface.GetOuterFnObject($unlocker_funs) 
		
		$this.LUsersAreChanged = $false #at first - no differences

		$this.PreviousLUsers = @() #the data object transferred is array
		
	} #constructor

	#getting and returning the locked users function
	[System.Object[]] GetLUsers() {
		Write-Verbose "`r`nStart of GetLUsers() - worker"
		$CurrentLUsers = @($(Get-ADUser -Filter * -Properties SamAccountname, badPwdCount, badPasswordTime, lockedout, enabled | Where-Object {$_.lockedout -eq "True"} | % {
			New-Object PSObject -Property @{
			username = $_.SamAccountname
			badPwdCount = $_.badPwdCount
			badPasswordTime = [DateTime]::FromFileTime($_.badPasswordTime)
			enabled = $_.enabled
			}
		} | Sort-Object -Property badPasswordTime)) #an array
		
		
	
		#comparing to previousLUsers part
		If (!$CurrentLUsers -and !$this.PreviousLUsers) {
			Write-Verbose "$(date) Cu: $($CurrentLUsers) # Pr: $($this.PreviousLUsers) (GETLUSERS)"
			$this.LUsersAreChanged = $false
			Write-Verbose "$(date) before returning currentLU: the two - empty (GETLUSERS)"
			return $CurrentLUsers
		} #the two arrays are empty - no change (the case is simple)
		
		If (!$CurrentLUsers -or !$this.PreviousLUsers) {
			Write-Verbose "$(date) Cu: $($CurrentLUsers) # Pr: $($this.PreviousLUsers) (GETLUSERS)"
			$this.LUsersAreChanged = $true
			$this.PreviousLUsers = $CurrentLUsers
			Write-Verbose "$(date) before returning currentLU: one empty, the other not (GETLUSERS)"
			return $CurrentLUsers
		} #one of them is empty but other is not, the two empty is the previous If - it is a change
		
		#from now on arrays have count member (powershell specialities...)
		If ($CurrentLUsers.Count -ne $this.PreviousLUsers.Count) {
			Write-Verbose "$(date) Cu: $($CurrentLUsers) # Pr: $($this.PreviousLUsers) (GETLUSERS)"
			$this.LUsersAreChanged = $true
			$this.PreviousLUsers = $CurrentLUsers
			Write-Verbose "$(date) before returning currentLU: different count of the two $($CurrentLUsers.Count) / $($this.PreviousLUsers.Count) (GETLUSERS)"
			return $CurrentLUsers
		} #the count of the two is different - a change (the other cases where count doesn't exist are above)

		#from now on the count is the same
		
		#comparing PSObject arrays...
		If ($($CurrentLUsers | ConvertTo-Json -Compress) -ne $($this.PreviousLUsers | ConvertTo-Json -Compress)) {
			Write-Verbose "$(date) Cu: $($CurrentLUsers) # Pr: $($this.PreviousLUsers) (GETLUSERS)"
			$this.LUsersAreChanged = $true
			$this.PreviousLUsers = $CurrentLUsers
			Write-Verbose "$(date) before returning currentLU: equal count - but difference (GETLUSERS)"
			return $CurrentLUsers
		} #equal count of rows, but there is something different between them - a change
		
		#here everything is equal, but they have rows
		Write-Verbose "$(date) Cu: $($CurrentLUsers) # Pr: $($this.PreviousLUsers) (GETLUSERS)"
		$this.LUsersAreChanged = $false
		Write-Verbose "$(date) before returning currentLU: everything is equal, but they have rows (GETLUSERS)"
		return $CurrentLUsers
		#everything is the same - finally no change
		
		Write-Verbose "End of GetLUsers() - worker"
	} #GetUsers function
	
	#unlocking the locked users given as parameter function
	[System.Object] UnlockLUsers([System.Object[]] $UserData, [bool] $enabledonly) {
		Write-Verbose "in UnlockLUsers, UserUnlocker: $UserData"
		Write-Verbose "$($UserData.gettype())"
		
		if (! $UserData) {
			return @{"message" = "No locked users to unlock.`r`nCheck again later."; "unlockednum" = 0}
		} #no data - no need to do anything else
		
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
        
			$message += "$(if (!$_.Enabled) {"(disabled) "})" #the two double quotes work here
			$msg = ""
		
			$username = $_.username
			$global:error.clear() #error variable is global
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
			
		} # %
		
		return @{"message" = $message; "unlockednum" = $unlockednum}
	} #UnlockLUsers function


	#getter for LUsersAreChanged property
	[Bool] GetLUsersAreChanged() {return $this.LUsersAreChanged}


	#function that "runs" the interface, which uses worker's functions. The interface must have a Show() method which is specific for every of them
	[void] Run() {
		$this.liface.Show()
	}

} #class UnlockUsers

