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
		$rootDse = $null
		$searchRoot = $null
		$searcher = $null
		$results = $null
		$CurrentLUsers = @()
		try {
			# Bind with the current Windows credentials to the default domain.
			$rootDse = [System.DirectoryServices.DirectoryEntry]::new('LDAP://RootDSE')
			$domainDn = [string]$rootDse.Properties['defaultNamingContext'][0]
			if ([string]::IsNullOrEmpty($domainDn)) {
				throw 'Unable to determine the Active Directory default naming context.'
			}
			$searchRoot = [System.DirectoryServices.DirectoryEntry]::new("LDAP://$domainDn")
			$searcher = [System.DirectoryServices.DirectorySearcher]::new($searchRoot)
			$searcher.SearchScope = [System.DirectoryServices.SearchScope]::Subtree
			$searcher.PageSize = 1000
			$searcher.Filter = '(&(objectCategory=person)(objectClass=user)(lockoutTime>=1))'
			$searcher.PropertiesToLoad.AddRange([string[]]@(
				'sAMAccountName', 'badPwdCount', 'badPasswordTime',
				'userAccountControl', 'msDS-User-Account-Control-Computed'
			))
			$results = $searcher.FindAll()
			$CurrentLUsers = @(@(foreach ($result in $results) {
				$properties = $result.Properties
				# A nonzero lockoutTime can remain after a lockout expires.
				# Use the computed UF_LOCKOUT bit to identify current lockouts.
				if (([int]$properties['msDS-User-Account-Control-Computed'][0] -band 0x10) -ne 0) {
					New-Object PSObject -Property @{
						username = [string]$properties['samaccountname'][0]
						badPwdCount = [int]$properties['badpwdcount'][0]
						badPasswordTime = [DateTime]::FromFileTime([long]$properties['badpasswordtime'][0])
						enabled = (([int]$properties['useraccountcontrol'][0] -band 0x2) -eq 0)
					}
				}
			}) | Sort-Object -Property badPasswordTime)
		}
		finally {
			if ($null -ne $results) { $results.Dispose() }
			if ($null -ne $searcher) { $searcher.Dispose() }
			if ($null -ne $searchRoot) { $searchRoot.Dispose() }
			if ($null -ne $rootDse) { $rootDse.Dispose() }
		}
		
		
	
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
	
	# Escape values used in LDAP filters (RFC 4515).
	static [string] EscapeLdapFilterValue([string] $value) {
		return $value.Replace('\', '\5c').Replace('*', '\2a').Replace('(', '\28').Replace(')', '\29').Replace([string][char]0, '\00')
	}

	[void] UnlockUser([string] $username) {
		if ([string]::IsNullOrWhiteSpace($username)) {
			throw 'A user name is required to unlock an account.'
		}
		$rootDse = $null
		$searchRoot = $null
		$searcher = $null
		$results = $null
		$userEntry = $null
		try {
			$rootDse = [System.DirectoryServices.DirectoryEntry]::new('LDAP://RootDSE')
			$domainDn = [string]$rootDse.Properties['defaultNamingContext'][0]
			if ([string]::IsNullOrEmpty($domainDn)) {
				throw 'Unable to determine the Active Directory default naming context.'
			}
			$searchRoot = [System.DirectoryServices.DirectoryEntry]::new("LDAP://$domainDn")
			$searcher = [System.DirectoryServices.DirectorySearcher]::new($searchRoot)
			$searcher.SearchScope = [System.DirectoryServices.SearchScope]::Subtree
			$escapedUsername = [UsersUnlocker]::EscapeLdapFilterValue($username)
			$searcher.Filter = "(&(objectCategory=person)(objectClass=user)(sAMAccountName=$escapedUsername))"
			$searcher.SizeLimit = 2
			[void]$searcher.PropertiesToLoad.Add('distinguishedName')
			$results = $searcher.FindAll()
			if ($results.Count -ne 1) {
				throw "Expected one AD user matching '$username'; found $($results.Count)."
			}
			$userEntry = $results[0].GetDirectoryEntry()
			$userEntry.Properties['lockoutTime'].Value = 0
			$userEntry.CommitChanges()
		}
		finally {
			if ($null -ne $userEntry) { $userEntry.Dispose() }
			if ($null -ne $results) { $results.Dispose() }
			if ($null -ne $searcher) { $searcher.Dispose() }
			if ($null -ne $searchRoot) { $searchRoot.Dispose() }
			if ($null -ne $rootDse) { $rootDse.Dispose() }
		}
	}

	#unlocking the locked users given as parameter function
	[System.Object] UnlockLUsers([System.Object[]] $UserData, [bool] $enabledonly) {
		Write-Verbose "in UnlockLUsers, UserUnlocker: $UserData"
		
		if (! $UserData) {
			return @{"message" = "No locked users to unlock.`r`nCheck again later."; "unlockednum" = 0}
		} #no data - no need to do anything else
		
		$message = ""
		$unlockednum = 0
		
		$UserData | % {
			#Enabled attribute is actually a String and needs to be converted
			if (-not ([bool]::Parse($_.Enabled)) -and $enabledonly) {
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
			Try {	
				$this.UnlockUser($username)
				"$username unlocked" | Tee-Object -variable msg | Write-Verbose
				$message += "$msg`r`n"
				$unlockednum += 1
			}
			Catch {
				"unlocking $username error: $($_.Exception.Message)" | Tee-Object -variable msg | Write-Verbose
				$message += "$msg`r`n"
				$msg = ""
			}
			
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

