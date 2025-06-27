#cgpt, thank you for all those classes
class PSAsyncTask {
    [PowerShell] $Pipe
    [IAsyncResult] $Handle
    [bool] $HasResult = $false
    [bool] $IsCancelled = $false
    [System.Threading.ManualResetEvent] $CompletedEvent
    [System.Management.Automation.Runspaces.RunspacePool] $Pool
    [object[]] $Result

    PSAsyncTask([scriptblock] $Script, [System.Management.Automation.Runspaces.RunspacePool] $Pool, [object[]] $Arguments) {
        $this.Pool = $Pool
        $this.Pipe = [PowerShell]::Create()
        $this.Pipe.RunspacePool = $Pool
        $this.Pipe.AddScript($Script)
        foreach ($arg in $Arguments) { $this.Pipe.AddArgument($arg) }

        $this.Handle = $this.Pipe.BeginInvoke()
        $this.CompletedEvent = $this.Handle.AsyncWaitHandle
    }

    [void] Cancel() {
        if (-not $this.IsCancelled) {
            $this.Pipe.Stop()
            Write-Verbose "stopping ended at $(date)"
            $this.IsCancelled = $true
        }
    }

    [void] AsyncCancel() {
        Write-Verbose "$(date) PSAsyncTask: starting async stop for stale pipe"
        $this.Pipe.BeginStop($null, $null)
    }

    [bool] TryComplete() {
        if ($this.Handle.IsCompleted) {
            try {
                $this.Result = $this.Pipe.EndInvoke($this.Handle)
                if ($this.Result) {
                    $this.HasResult = $true
                }
            }
            catch {
                # Ignore failures
            }
            finally {
                $this.Pipe.Dispose()
            }
            return $true
        }
        return $false
    }
} #class PSAsyncTask

class LockedADUCallerFinder {
    [string[]] $DCs
    [object[]] $Result
    [scriptblock] $SBl
    [System.Management.Automation.Runspaces.RunspacePool] $RSPool #the runspace pool is a class member

    LockedADUCallerFinder() {

        $this.DCs = @() #should be set by setter
        $this.Result = @()
        $this.SBl = {
            Param([string]$dc, [string]$usr , [datetime]$st)
            Get-WinEvent -ComputerName $dc -FilterHashtable @{
                LogName   = 'Security'
                ID        = 4740
                StartTime = $st
                EndTime   = $st.AddSeconds(1)
            } -ErrorAction SilentlyContinue | ForEach-Object {
                $xml = [xml]$_.ToXml()
                $eventUser = $xml.Event.EventData.Data |
                    Where-Object { $_.Name -eq 'TargetUserName' } |
                    Select-Object -ExpandProperty '#text'
                if ($eventUser -ieq $usr) {
                    $callerComputer = $xml.Event.EventData.Data | Where-Object { $_.Name -eq 'TargetDomainName' } | Select-Object -ExpandProperty '#text'
                    return @($callerComputer, $dc)
                }
            }
        }

        $this.RSPool = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool(1, 10) #the runspace pool is a class member
        $this.RSPool.Open() #we open it here - once
        #the pool is not closed, disposed  - too long time duration - we count on PS
    } #constructor

    [System.Object[]] SearchUsers([string] $User, [datetime] $LockTime) {
        $this.Result = @()

        if (! $this.DCs) {return $this.Result}

        $tasks = @()
        foreach ($dc in $this.DCs) {
            $argms = @($dc, $User, $LockTime)
            $task = [PSAsyncTask]::new($this.SBl, $this.RSPool, $argms) #6
            $tasks += $task
            Write-Verbose "$(date) in LockedADUCallerFinder (search) - task added to task array: $($task)"
        }

        Write-Verbose "`n$(date) in LockedADUCallerFinder (search) - starting smart WaitAny result search ..."

        $remainingTasks = $tasks.Clone() #shallow clone, the two are different though
        $winner = $null

        while ($remainingTasks.Count -gt 0) {
            $handles = $remainingTasks | ForEach-Object { $_.CompletedEvent }
            $idx = [System.Threading.WaitHandle]::WaitAny($handles)

            if ($idx -ge 0 -and $idx -lt $remainingTasks.Count) {
                $candidate = $remainingTasks[$idx]
                Write-Verbose "$(date) in LockedADUCallerFinder (search) - we have a candidate with index $($idx)"
                if ($candidate.TryComplete() -and $candidate.HasResult) {
                    $this.Result = $candidate.Result
                    $winner = $candidate
                    Write-Verbose "$(date) in LockedADUCallerFinder (search) - found valid result: $($candidate.Result) for index $($idx)"
                    $remainingTasks = $remainingTasks | Where-Object { $_ -ne $candidate } #2ti
                    break
                } else {
                    # Remove the completed but resultless task from future checks
                    $remainingTasks = $remainingTasks | Where-Object { $_ -ne $candidate }
                    Write-Verbose "$(date) in LockedADUCallerFinder (search) - resultless candidate with index $($idx) removed"
                }
            } #if ($idx)
        } #while

        if (-not $winner) {
            Write-Verbose "$(date) in LockedADUCallerFinder (search) - no valid result found in any task at."
            $this.Result = @('<no info>', '<no info>')
        }

        Write-Verbose "$(date) in LockedADUCallerFinder (search) - remaining tasks are: $($remainingTasks)"

        #smart variant
        foreach ($task in $remainingTasks) {
            $task.AsyncCancel()
            Write-Verbose "$(date) in LockedADUCallerFinder (search) - AsyncCancel started for task $(@($remainingTasks).indexof($task))"
            $task.CompletedEvent.Close()
            Write-Verbose "$(date) in LockedADUCallerFinder (search) - completedevent closed for $(@($remainingTasks).indexof($task))"
            #try { $task.Pipe.Dispose() } catch {} #disposing working tasks is time greedy #safe or not
        }

        <#
        #it was here in the first version
        $pool.Close()
        $pool.Dispose()
        #>

        if ($this.Result) {
            $rpattern = '(\..+)+$' #we remove the long part
            $this.Result[1] = [regex]::Replace($this.Result[1], $rpattern, '')
        }

        Write-Verbose "`n$(date) in LockedADUCallerFinder (search) --- RESULTS  ---"
        Write-Verbose "$(date) in LockedADUCallerFinder (search) - $($this.Result | Out-String)"

        return $this.Result
    } #SearchUsers

    [void] SetDCs($DCs) {
        $this.DCs = $DCs
        Write-Verbose "$(date) in SetDCs DCs were set"
    }

    #never used, just to exist
    [void] PoolCleanUp() {
        $this.RSPool.Close()
        $this.RSPool.Dispose()
    }
} #class LockedADUCallerFinder
