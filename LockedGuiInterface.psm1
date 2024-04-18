class LockedGui {
	
	[System.Windows.Forms.Form] $LockedForm
	
	[System.Windows.Forms.Label] $UnlockLabel
	
	[System.Windows.Forms.Button] $RefreshButton
	
	[System.Windows.Forms.Button] $UnlockEnabledButton
	
	[System.Windows.Forms.Button] $UnlockAllButton
	
	[System.Windows.Forms.DataGridView] $DataGridView
	
	[System.Windows.Forms.StatusStrip] $StatusStrip
	
	[System.Windows.Forms.ToolStripLabel] $Operation
	
	[System.Windows.Forms.ContextMenuStrip] $DgrContextMenuStrip
	
	[System.Windows.Forms.FlowLayoutPanel] $LFlowPanel
	
	#functions given
	[System.Management.Automation.PSMethod] $getlusers_fun
	
	[System.Management.Automation.PSMethod] $unlocklusers_fun
	
	#constructor
	LockedGui() {
		[System.Windows.Forms.Application]::EnableVisualStyles()
		
		$thisGui = $this #for distinguishing gui $this from button $this(!)
		
		#form 
		$this.LockedForm = [System.Windows.Forms.Form]::new()
		
		#icon
		$this.LockedForm.Icon = $this.LoadIcon({GetIconB64})
		#/icon
		
		$this.LockedForm.StartPosition = 'CenterScreen'
		$this.LockedForm.Text = "Unlocking users v$global:ULVersion" #version set in _start.ps1
		$this.LockedForm.Text += " (running as: $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name))"
		$this.LockedForm.ClientSize = [System.Drawing.Size]::new(500,650)
		$this.LockedForm.DataBindings.DefaultDataSourceUpdateMode = 'OnValidation' #0 ?
		$this.LockedForm.AutoSizeMode = 'GrowAndShrink'
		#/form
	
		#flowlayoutpanel
		$this.LFlowPanel = [System.Windows.Forms.FlowLayoutPanel]::new()
		$this.LFlowPanel.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight #default but here explicitly
		$this.LFlowPanel.Location = [System.Drawing.Point]::new(30,15)
		$this.LFlowPanel.Size = [System.Drawing.Size]::new(455,580) #sic
		$this.LockedForm.Controls.Add($this.LFlowPanel)

	
		#label
		$this.UnlockLabel = [System.Windows.Forms.Label]::new()
		$this.UnlockLabel.Text = "Locked users:"
		$this.UnlockLabel.Text += "`r`nUnlock specific user with double click on the row."
		$this.UnlockLabel.Text += "`r`nUnlock marked users with right click and context menu click."

		$this.UnlockLabel.Size = [System.Drawing.Size]::new(450,40) #40 (!)
		#$this.UnlockLabel.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left #for howto

		$this.LFlowPanel.Controls.Add($this.UnlockLabel)
		#/label
		
	
		#refresh button
		$this.RefreshButton = [System.Windows.Forms.Button]::new()
		$this.RefreshButton.Text = "Refresh"
		$this.RefreshButton.Size = [System.Drawing.Size]::new(60,30)
		$this.RefreshButton.Add_Click({$thisGui.RefreshGrid()}.GetNewClosure()) #(!)
		#$this.LFlowPanel.SetFlowBreak($this.RefreshButton, $true) #not for here, for howto
		$this.LFlowPanel.Controls.Add($this.RefreshButton)
		Write-Verbose "refresh button added"
		#/refresh button
		
				
		#unlock enabled button
		$this.UnlockEnabledButton = [System.Windows.Forms.Button]::new()
		$this.UnlockEnabledButton.Text = "Unlock Enabled"
		$this.UnlockEnabledButton.Size = [System.Drawing.Size]::new(100,30)
		#add_click
		$this.UnlockEnabledButton.Add_Click({$thisGui.UnlockUsers($true, $false)}.GetNewClosure()) #(!) enabledonly, not selection
		$this.LFlowPanel.Controls.Add($this.UnlockEnabledButton)
		Write-Verbose "unlock enabled button added"
		#/unlock enabled button
		
			
		#unlock all Button
		$this.UnlockAllButton = [System.Windows.Forms.Button]::new()
		$this.UnlockAllButton.Text = "Unlock All"
		$this.UnlockAllButton.Size = [System.Drawing.Size]::new(100,30)
		#add_click
		$this.UnlockAllButton.Add_Click({$thisGui.UnlockUsers($false, $false)}.GetNewClosure()) #(!) enabled all (not only), not selection
		$this.LFlowPanel.Controls.Add($this.UnlockAllButton)
		Write-Verbose "unlockall button added"
		#/unlock all Button	

		
		#datagridview
		$this.DataGridView = [System.Windows.Forms.DataGridView]::new()
		$this.DataGridView.AutoSizeColumnsMode = 'AllCells'
		$this.DataGridView.Size = [System.Drawing.Size]::new(450,500)
		$this.DataGridView.Location = [System.Drawing.Point]::new(30,90)
		$this.DataGridView.SelectionMode = 'FullRowSelect'
		$this.DataGridView.MultiSelect = $true
		$this.DataGridView.ReadOnly = $true
		$this.DataGridView.DataBindings.DefaultDataSourceUpdateMode = 'OnValidation' #?
		
		#context menu
		$this.DgrContextMenuStrip = [System.Windows.Forms.ContextMenuStrip]::new()
		$this.DgrContextMenuStrip.Items.Add("Unlock selected users...").add_Click({$thisGui.UnlockUsers($false, $true)}.GetNewClosure()) #(!) enabled all (not only), selection
		$this.DataGridView.ContextMenuStrip = $this.DgrContextMenuStrip
		#/context menu
	
		#double click
		$this.DataGridView.Add_DoubleClick({$thisGui.UnlockUsers($false, $true)}.GetNewClosure()) #(!) enabled all (not only), selection
		#/doubleclick

		$this.LFlowPanel.Controls.Add($this.DataGridView)
		#/datagridview
	
		#status strip
		$this.StatusStrip = [System.Windows.Forms.StatusStrip]::new()
		$this.StatusStrip.Name = 'StatusStrip'
		$this.StatusStrip.AutoSize = $true
		$this.StatusStrip.Left = 0
		$this.StatusStrip.Visible = $true
		$this.StatusStrip.Enabled = $true
		$this.StatusStrip.Dock = [System.Windows.Forms.DockStyle]::Bottom
		$this.StatusStrip.LayoutStyle = [System.Windows.Forms.ToolStripLayoutStyle]::Table
		
		#striplabel
		$this.Operation = [System.Windows.Forms.ToolStripLabel]::new()
		$this.Operation.Name = 'Operation'
		$this.Operation.Text = $null
		$this.Operation.Width = 50
		$this.Operation.Visible = $true
		#/striplabel
		
		$this.StatusStrip.Items.AddRange([System.Windows.Forms.ToolStripItem[]]@($this.Operation))
		
		$this.LockedForm.Controls.Add($this.StatusStrip)
		
		$this.StatusStrip.Items[0].Text = "status" #not really used
		#/status strip
		
		$this.LockedForm.Add_Shown({$thisGui.RefreshGrid()}.GetNewClosure()) #on load
	
		$this.getlusers_fun = $null #at first
		
		$this.unlocklusers_fun = $null # at first
		
	} #constructor
	
	[System.Drawing.Icon] LoadIcon($GetB64) {
		Write-Verbose "load icon func"
		#Write-Verbose $(&$GetB64)
		return [System.Drawing.Icon][IO.MemoryStream][Convert]::FromBase64String($(&$GetB64))
		}
	
	[void] GetOuterFnObject([PSCustomObject] $users_ulocker_funs) {
		$this.getlusers_fun = $users_ulocker_funs.GetLUsers
		$this.unlocklusers_fun = $users_ulocker_funs.UnlockLUsers
	}
	
	[void] RefreshGrid() {
		Write-Verbose "Start of refreshgrid..."
	    $this.Operation.Text = "refreshing..."
	    $this.LockedForm.Refresh()
		$lusers_list = @($this.getlusers_fun.Invoke())
		if ($lusers_list) {Write-Verbose "type of lusers list is: $($lusers_list.gettype())";}
		if ($lusers_list) {
	        Write-Verbose "lusers_list count: $($lusers_list.count)"
	        $this.Operation.Text = "locked users count: $($lusers_list.count)"
	    }
		else {
			Write-Verbose "empty list"
			$this.Operation.Text = "no locked users"
	    }
		$this.Operation.Text += "$(' '*60)last refreshed: $([DateTime]::Now.ToString())" #65 is the margin for one char locked, here - 5 left
		#this kind of control doesn't support non printing chars (tab)	
		$this.LockedForm.Refresh()
		$GridData = [System.Collections.ArrayList]::new()
	    $GridData.AddRange(@($lusers_list))
	    $this.DataGridView.DataSource = $GridData
		$this.LockedForm.Refresh()

		Write-Verbose "After refresh in refreshgrid"
	} #RefreshGrid fn
	
	[System.Windows.Forms.Form] CreateMsgForm([string] $message, [int] $unlnum){
		#
		Write-Verbose "messsage in the message fn: $message"
		Write-Verbose "unlocked nuber in the message fn: $unlnum"
	    $MsgForm = [System.Windows.Forms.Form]::new()
		$MsgForm.Owner = $this.LockedForm #(!)
		#icon
		$MsgForm.Icon = $this.LoadIcon({GetIconB64})
		#/icon
		$MsgForm.StartPosition = 'CenterParent'
	    $MsgForm.Text = "Unlocking result: $unlnum ulocked users"
	    $MsgForm.ClientSize = [System.Drawing.Size]::new(450,400)
	    #$MsgForm.AutoSize = $true
	    $MsgForm.MinimumSize = [System.Drawing.Size]::new(450,400)
		$MsgForm.MaximumSize = $MsgForm.MinimumSize
	    $MsgForm.AutoSizeMode = 'GrowAndShrink'
		$MsgText = [System.Windows.Forms.TextBox]::new()
		$MsgText.ReadOnly = $true
		$MsgText.TabStop = $false
		$MsgText. Multiline = $true
		$MsgText.ScrollBars = "Vertical"
	    #$MsgText.AutoSize = $true
		$MsgText.Size = [System.Drawing.Size]::new(425,300) # -25 for scroll bar
	    $MsgText.Text = $message
	    $MsgForm.controls.Add($MsgText)
	    #Write-Verbose "LABEL: $MsgText"
	    $OKButton = [System.Windows.Forms.Button]::new()
	    $OKButton.Text = "OK"
	    $OKButton.Size = [System.Drawing.Size]::new(60,30)
	    $OKButton.Location = [System.Drawing.Point]::new(30,320) #thus
	    $OKButton.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
	    $OKButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
	    $MsgForm.controls.Add($OKButton)
	    return $MsgForm	
	} #CreateMsgForm fn
	
	[void] UnlockUsers([bool] $enabledonly, [bool] $selection) {
		#
		Write-Verbose "start of UnlockUsers fn"
		Write-Verbose "enabled only has value $enabledonly"
		Write-Verbose "selection has value $selection"
		$this.DataGridView.SelectedRows | % {Write-Verbose "Index of selected: $($_.Index)"}
		Write-Verbose "$($this.DataGridView.SelectedRows)"
	    #Write-Verbose $DataGridView.DataSource
		
		
		$UserData = @()
		
	    If ($selection) {
	        Write-Verbose "selection option case chosen"
	        $this.DataGridView.SelectedRows | % {$UserData += $this.DataGridView.DataSource[$_.Index];}
	    }
	    else {
	        $UserData = $this.DataGridView.DataSource
	    }
		
	    Write-Verbose "userdata is: $($UserData)"
		
		$unlock_result = $this.unlocklusers_fun.Invoke($UserData, $enabledonly) #$enabledonly is the parameter
		
		Write-Verbose "after unlock (enabledonly is $enabledonly) pressed"
		$this.RefreshGrid()
		Write-Verbose "after refreshing in unlock (enabledonly is $enabledonly) block"
		
		Write-Verbose "Unlocking result: $($unlock_result["unlockednum"]) unlocked users"
		Write-Verbose "message to sent to msLFlowPanel: $($unlock_result["message"])"
		#[System.Windows.Forms.MessageBox]::Show($message) #just to remember how messagebox is called
		
		$msLFlowPanel = $this.CreateMsgForm($unlock_result["message"], $unlock_result["unlockednum"])
		$msLFlowPanel.ShowDialog()
		
	} #UnlockUsers fn
	
		
	[void] Show() {
			[void]$this.LockedForm.ShowDialog()
	} #RefreshGrid fn
	
	
	
	
} #class LockedGui

