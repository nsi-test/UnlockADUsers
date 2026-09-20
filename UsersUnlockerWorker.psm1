#using assembly System.DirectoryServices
using module ".\LockedADUCallerFinder.psm1" #tasks and lock caller info

class UsersUnlocker {

    # Use the current user's domain and credentials; no ActiveDirectory module is needed.
    [string[]] GetDirectoryDomainControllers() {
        $domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
        try {
            $controllers = $domain.DomainControllers
            try {
                return @($controllers | ForEach-Object { $_.Name })
            }
            finally {
                foreach ($controller in $controllers) { $controller.Dispose() }
            }
        }
        finally { $domain.Dispose() }
    }

    [System.DirectoryServices.DirectorySearcher] NewDirectoryUserSearcher() {
        $domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
        $controller = $null
        $rootDse = $null
        $root = $null
        try {
            # The PDC is writable and provides a consistent target for reads and unlocks.
            $controller = $domain.PdcRoleOwner
            $server = $controller.Name
            $rootDse = [System.DirectoryServices.DirectoryEntry]::new("LDAP://$server/RootDSE")
            $namingContext = [string]$rootDse.Properties['defaultNamingContext'][0]
            if (-not $namingContext) { throw 'The domain naming context could not be read.' }
            $root = [System.DirectoryServices.DirectoryEntry]::new("LDAP://$server/$namingContext")
            $searcher = [System.DirectoryServices.DirectorySearcher]::new($root)
            $searcher.PageSize = 1000
            $searcher.SearchScope = [System.DirectoryServices.SearchScope]::Subtree
            return $searcher # Caller owns both the searcher and its SearchRoot.
        }
        catch {
            if ($root) { $root.Dispose() }
            throw
        }
        finally {
            if ($rootDse) { $rootDse.Dispose() }
            if ($controller) { $controller.Dispose() }
            $domain.Dispose()
        }
    }

    [object[]] GetDirectoryLockedUsers() {
        $searcher = $this.NewDirectoryUserSearcher()
        $results = $null
        $users = [System.Collections.Generic.List[object]]::new()
        try {
            $searcher.Filter = '(&(objectCategory=person)(objectClass=user)(lockoutTime>=1))'
            foreach ($name in @('sAMAccountName', 'badPwdCount', 'badPasswordTime', 'userAccountControl', 'msDS-User-Account-Control-Computed')) {
                [void]$searcher.PropertiesToLoad.Add($name)
            }
            $results = $searcher.FindAll()
            foreach ($result in $results) {
                $properties = $result.Properties
                # A nonzero lockoutTime alone can outlive the lockout duration.
                if ($properties['msds-user-account-control-computed'].Count -eq 0) {
                    throw 'AD did not return the computed account lockout state.'
                }
                if (([int]$properties['msds-user-account-control-computed'][0] -band 16) -eq 0) { continue }
                $users.Add([PSCustomObject]@{
                    SamAccountName = [string]$properties['samaccountname'][0]
                    badPwdCount = [int]$properties['badpwdcount'][0]
                    badPasswordTime = [long]$properties['badpasswordtime'][0]
                    enabled = (([int]$properties['useraccountcontrol'][0] -band 2) -eq 0)
                })
            }
        }
        finally {
            if ($null -ne $results) { $results.Dispose() }
            $searcher.SearchRoot.Dispose()
            $searcher.Dispose()
        }
        return $users.ToArray()
    }

    [string] ConvertToDirectoryFilterValue([string] $Value) {
        return $Value.Replace('\', '\5c').Replace('*', '\2a').Replace('(', '\28').Replace(')', '\29').Replace([string][char]0, '\00')
    }


	[System.Object] $liface #this is the interface object member which is given in the constructor, it can be gui, cmdline, or whatever

	[Bool] $LUsersAreChanged #property signifying that results has been changed since the last operation

	[System.Object[]] $PreviousLUsers # an array with the previous state of the locked users data

	[LockedADUCallerFinder] $CallerFinder #object to find the caller

	[Bool] $ShowLCaller #property signifying that the caller computer should be searched and shown

	#constructor
	UsersUnlocker([System.Object] $liface) { #the exact type is not known here

		#the PSCustomObject containing the functions which are to be given to the interface
		$unlocker_funs = [PSCustomObject]@{
				'GetLUsers'=$this.GetLUsers
				'UnlockLUsers'=$this.UnlockLUsers
				'GetLUsersAreChanged'=$this.GetLUsersAreChanged
				'SetShowLCaller'=$this.SetShowLCaller
				}

		#this.liface accepts the fubctions object... (the two liface are the same in fact...)
		$this.liface = $liface
		#that function belongs to the interface, it accepts this object's functions for being used. The function's name should be formally known because the outer interfaces will use it
		$this.liface.GetOuterFnObject($unlocker_funs)

		$this.LUsersAreChanged = $false #at first - no differences

		$this.PreviousLUsers = @() #the data object transferred is array

		#the lock CallerFinder object
		$this.CallerFinder = [LockedADUCallerFinder]::new()

		$this.ShowLCaller = $true #at first

	} #constructor

	#getting and returning the locked users function
	[System.Object[]] GetLUsers() {
		Write-Verbose "`r`n$(date) Start of GetLUsers() - worker"
		try {
            $DCs = $this.GetDirectoryDomainControllers()
        }
        catch {
            $DCs = @()
        }
		Write-Verbose "$(date) in GetLUsers - DCs gotten are: $($DCs)"
        $this.CallerFinder.SetDCs($DCs)
		Write-Verbose "$(date) in getlusers DCs were set to CallerFinder"

		$CurrentLUsers = @($($this.GetDirectoryLockedUsers() | % {
			$CallerFinderResult = $null
			if ($this.ShowLCaller) {$CallerFinderResult = $this.CallerFinder.SearchUsers($_.SamAccountname, [DateTime]::FromFileTime($_.badPasswordTime))} #if it is set by GUI
			[PSCustomObject] @{
			    username = $_.SamAccountname
			    badPwdCount = $_.badPwdCount
			    badPasswordTime = [DateTime]::FromFileTime($_.badPasswordTime)
			    enabled = $_.enabled
				callerComputer = if ($CallerFinderResult) {$CallerFinderResult[0]} else {''}
			    logSource = if ($CallerFinderResult) {$CallerFinderResult[1]} else {''}
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
				$message += "$username unlocked`r`n"
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

	[void] UnlockUser([string] $UserName) {
		if ([string]::IsNullOrWhiteSpace($UserName)) { throw 'A user name is required.' }
		$searcher = $this.NewDirectoryUserSearcher()
		$entry = $null
		$stage = 'finding the user'
		try {
			$escapedName = $this.ConvertToDirectoryFilterValue($UserName)
			$searcher.Filter = "(&(objectCategory=person)(objectClass=user)(sAMAccountName=$escapedName))"
			$result = $searcher.FindOne()
			if ($null -eq $result) { throw "User '$UserName' was not found in the current domain." }
			$entry = $result.GetDirectoryEntry()
			$stage = 'setting lockoutTime'
			# Match .NET AccountManagement.UnlockAccount: ADSI accepts Int32 zero
			# for this reset, even though lockoutTime is an Integer8 AD attribute.
			$entry.Properties['lockoutTime'].Value = [int]0
			$stage = 'committing lockoutTime to AD'
			$entry.CommitChanges()
		}
		catch {
			$failure = $_.Exception
			while ($failure.InnerException) { $failure = $failure.InnerException }
			$details = '{0} (HRESULT 0x{1:X8})' -f $failure.Message, $failure.HResult
			if ($failure -is [System.DirectoryServices.DirectoryServicesCOMException]) {
				$details += ' AD error {0}: {1}' -f $failure.ExtendedError, $failure.ExtendedErrorMessage
			}
			throw [System.InvalidOperationException]::new("Failed while ${stage} for '$UserName': $details", $_.Exception)
		}
		finally {
			if ($entry) { $entry.Dispose() }
			$searcher.SearchRoot.Dispose()
			$searcher.Dispose()
		}
	}#UlockUser method


	#getter for LUsersAreChanged property
	[Bool] GetLUsersAreChanged() {return $this.LUsersAreChanged}

	#setter of ShowLCaller property
	[void] SetShowLCaller($ShowLockCaller) {
		$this.ShowLCaller = $ShowLockCaller
	}


	#function that "runs" the interface, which uses worker's functions. The interface must have a Show() method which is specific for every of them
	[void] Run() {
		$this.liface.Show()
	}

} #class UsersUnlocker
