class LockedGui {
	
	[System.Windows.Forms.Form] $LockedForm #the main form
	
	[System.Windows.Forms.Label] $UnlockLabel
	
	#FlowLayoutPanel for buttons to be in a row
	[System.Windows.Forms.FlowLayoutPanel] $LButtonsPanel
	
	[System.Windows.Forms.Button] $RefreshButton
	
	[System.Windows.Forms.Button] $UnlockEnabledButton
	
	[System.Windows.Forms.Button] $UnlockAllButton
	
	[System.Windows.Forms.CheckBox] $AutoRefreshChBox #for allow/disable the autorefresh timer
	
	[System.Windows.Forms.Label] $AutoRSecondsLabel #describing the period textbox
	
	[System.Windows.Forms.TextBox] $SecondsText #textbox for changing refresh period	
	#/FlowLayoutPanel
	
	[System.Windows.Forms.DataGridView] $DataGridView
	
	[System.Windows.Forms.StatusStrip] $StatusStrip
	
	[System.Windows.Forms.ToolStripLabel] $Operation
	
	[System.Windows.Forms.ContextMenuStrip] $DgrContextMenuStrip
	
	#TableLayoutPanel for all controls (including $LButtonsPanel) to be in a grid for resize
	[System.Windows.Forms.TableLayoutPanel] $LTablePanel
	
	[System.Windows.Forms.Timer] $LTimer #the timer for autorefresh (not a graphical object)
	
	[System.Windows.Forms.ToolTip] $LToolTip #tooltip for precising information about autorefresh period
	
	
	#custom values (values specific for the LockedGui class)
	[System.ComponentModel.ListSortDirection] $SortDirection
	
	[Int32] $LastSortedColumnIndex #for checking if the clicked column to sort is the same
	
	[System.Drawing.Size] $FormPreviousSize #for comparing new size with the previous one and calculating coefficients
	
	[String] $DefaultLTimerPeriod #string, bacause it is for the textbox
	
	#functions given from the worker
	[System.Management.Automation.PSMethod] $getlusers_fun #function to get locked users
	
	[System.Management.Automation.PSMethod] $unlocklusers_fun #function to ulock users
	
	[System.Management.Automation.PSMethod] $getlusersarechanged_fun #function that shows that the state of locked users has been changed
	
	#constructor
	LockedGui() {
		[System.Windows.Forms.Application]::EnableVisualStyles()
		
		$thisGui = $this #for distinguishing gui $this from button $this(!)
		
		#main form 
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
	
		#TableFlowLayoutPanel (contains all other controls)
		$this.LTablePanel = [System.Windows.Forms.TableLayoutPanel]::new()
		#GrowStyle is AddRows by default (we need this value)
		$this.LTablePanel.Location = [System.Drawing.Point]::new(30,15)
		$this.LTablePanel.Size = [System.Drawing.Size]::new(455,595) #afterwards docked fill
		#$this.LTablePanel.BorderStyle = 'FixedSingle' #useful when we want to see the panel size and borders 
		$this.LTablePanel.Dock = [System.Windows.Forms.DockStyle]::Fill
		$this.LockedForm.Controls.Add($this.LTablePanel)
		#continuing with inner controls
	
		#main label
		$this.UnlockLabel = [System.Windows.Forms.Label]::new()
		$this.UnlockLabel.Text = "Locked users:"
		$this.UnlockLabel.Text += "`r`nUnlock specific user with double click on the row."
		$this.UnlockLabel.Text += "`r`nUnlock marked users with right click and context menu click."

		$this.UnlockLabel.Size = [System.Drawing.Size]::new(450,40) #40 (!)
		#$this.UnlockLabel.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left #left for howto

		$this.LTablePanel.Controls.Add($this.UnlockLabel)
		#/main label
		
		#LButtonsPanel (contains the buttons in a row, autorefresh controls also)
		$this.LButtonsPanel = [System.Windows.Forms.FlowLayoutPanel]::new()	
		$this.LButtonsPanel.Size = [System.Drawing.Size]::new(495,40) #(almost the whole form width for the controls and height of a button +5 and more 5 px for three lines of the seconds label)
		#$this.LButtonsPanel.BorderStyle = 'FixedSingle' #useful when we want to see the panel size and borders 
		$this.LTablePanel.Controls.Add($this.LButtonsPanel)
		Write-Verbose "$(date) buttons panel added to LTablePanel"
		#adding buttons below
	
	
		#refresh button
		$this.RefreshButton = [System.Windows.Forms.Button]::new()
		$this.RefreshButton.Text = "Refresh"
		$this.RefreshButton.Size = [System.Drawing.Size]::new(60,30)
		#add click event handler
		$this.RefreshButton.Add_Click({$thisGui.RefreshGrid($true)}.GetNewClosure()) #(!) #EnforcedByUI - true
		$this.LButtonsPanel.Controls.Add($this.RefreshButton)
		Write-Verbose "$(date) refresh button added to LButtonsPanel"
		#/refresh button
		
				
		#unlock enabled (users) button
		$this.UnlockEnabledButton = [System.Windows.Forms.Button]::new()
		$this.UnlockEnabledButton.Text = "Unlock Enabled"
		$this.UnlockEnabledButton.Size = [System.Drawing.Size]::new(100,30)
		#add click event handler
		$this.UnlockEnabledButton.Add_Click({$thisGui.UnlockUsers($true, $false)}.GetNewClosure()) #only enabled, not selection
		$this.LButtonsPanel.Controls.Add($this.UnlockEnabledButton)
		Write-Verbose "$(date) unlock enabled (users) button added to LButtonsPanel"
		#/unlock enabled button
		
			
		#unlock all (users) Button
		$this.UnlockAllButton = [System.Windows.Forms.Button]::new()
		$this.UnlockAllButton.Text = "Unlock All"
		$this.UnlockAllButton.Size = [System.Drawing.Size]::new(100,30)
		#add click event handler
		$this.UnlockAllButton.Add_Click({$thisGui.UnlockUsers($false, $false)}.GetNewClosure()) #not only enabled (all in the locked list), not selection
		$this.LButtonsPanel.Controls.Add($this.UnlockAllButton)
		Write-Verbose "$(date) unlockall button added to the LButtonsPanel"
		#/unlock all Button			
		
		#autorefresh checkbox
		$this.AutoRefreshChBox = [System.Windows.Forms.CheckBox]::New()
		$this.AutoRefreshChBox.Checked = $true
		$this.AutoRefreshChBox.AutoSize = $true #necessary, and all bellow (10x cgpt)
		$this.AutoRefreshChBox.CheckAlign = 'MiddleRight'
		$this.AutoRefreshChBox.TextAlign = 'MiddleLeft'
		$this.AutoRefreshChBox.Text = "Auto Refresh"
		$this.AutoRefreshChBox.Add_CheckedChanged({$thisGui.AutoRChBoxCheckedChanged($thisGui.AutoRefreshChBox, $args)}.GetNewClosure())
		$this.LButtonsPanel.Controls.Add($this.AutoRefreshChBox)
		Write-Verbose "$(date) autorefresh checkbox added to LButtonsPanel"
		#/autorefresh checkbox
		
		#autorefresh seconds label
		$this.AutoRSecondsLabel = [System.Windows.Forms.Label]::New()
		$this.AutoRSecondsLabel.Text = "Seconds:"
		$this.AutoRSecondsLabel.Text += "`r`n<Enter>"
		$this.AutoRSecondsLabel.Text += "`r`n(apply)" #about what <Enter> means
		#$this.AutoRSecondsLabel.BorderStyle = 'FixedSingle' #useful when we want to see the size and borders
		#$this.AutoRSecondsLabel.AutoSize = $true #this shoud not be true for our purposes here
		$this.AutoRSecondsLabel.Width = 55
		$this.AutoRSecondsLabel.Height = 40 #for the three lines to be visible
		Write-Verbose "$(date) AutoRSecondsLabel heihgt: $($this.AutoRSecondsLabel.Height)"
		Write-Verbose "$(date) AutoRSecondsLabel width: $($this.AutoRSecondsLabel.Width)"
		$this.LButtonsPanel.Controls.Add($this.AutoRSecondsLabel)
		Write-Verbose "$(date) autorefresh seconds label added to LButtonsPanel"
		#/autorefresh seconds label
		
		$this.DefaultLTimerPeriod = '60' #at first (now)
		
		#autorefresh seconds textbox
		$this.SecondsText = [System.Windows.Forms.TextBox]::new()
		$this.SecondsText.Width = 50
		$this.SecondsText.Text = $this.DefaultLTimerPeriod #default for LGui
		#adding KeyPress event handler to restrict symbols anly to digits 
		$this.SecondsText.Add_KeyPress({$thisGui.SecTextKeyPress($thisGui.SecondsText, $args)}.GetNewClosure())
		#adding KeyDown event handler for processing <Enter> and other
		$this.SecondsText.Add_KeyDown({$thisGui.SecTextKeyDown($thisGui.SecondsText, $args)}.GetNewClosure())
		$this.LButtonsPanel.Controls.Add($this.SecondsText)
		Write-Verbose "$(date) autorefresh seconds textbox added to LButtonsPanel"
		#/autorefresh seconds textbox
		
		#adding LButtonsPanel to the big LTablePanel
		$this.LTablePanel.Controls.Add($this.LButtonsPanel)
		Write-Verbose "$(date)  LButtonsPanel  added to LTablePanel"
		
		#datagridview
		$this.DataGridView = [System.Windows.Forms.DataGridView]::new()
		$this.DataGridView.Size = [System.Drawing.Size]::new(500,500) #form width
		$this.DataGridView.SelectionMode = 'FullRowSelect'
		$this.DataGridView.MultiSelect = $true
		$this.DataGridView.ReadOnly = $true
		$this.DataGridView.DataBindings.DefaultDataSourceUpdateMode = 'OnValidation' #?
		$this.DataGridView.AllowUserToAddRows = $false
		$this.DataGridView.ScrollBars = [System.Windows.Forms.ScrollBars]::Both #default but must
		$this.DataGridView.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::Fill #before the resize event
		$this.DataGridView.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Bottom #without right anchor for correct resizing
		
		#add cell double click event handler (unlocking user in that row)
		$this.DataGridView.Add_CellDoubleClick({$thisGui.DGridCellDoubleClick($thisGui.DataGridView, $args)}.GetNewClosure())
		#/add cell doubleclick
		
		#add column header click event handler (sorting)
		$this.DataGridView.Add_ColumnHeaderMouseClick({$thisGui.SortColumnOnHeaderClick($thisGui.DataGridView, $args)}.GetNewClosure())
		#/column header click
		
		#context menu
		$this.DgrContextMenuStrip = [System.Windows.Forms.ContextMenuStrip]::new()
		$this.DgrContextMenuStrip.Items.Add("Unlock selected users...").add_Click({$thisGui.UnlockUsers($false, $true)}.GetNewClosure()) #(!) all users (not only enabled), selection is in effect
		$this.DataGridView.ContextMenuStrip = $this.DgrContextMenuStrip
		#/context menu
		
		#ading datagridview to the big LTablePanel
		$this.LTablePanel.Controls.Add($this.DataGridView)
		Write-Verbose "$(date) datagridview added to LTablePanel"
		#/datagridview
		
		#add form resize event handler
		$this.LockedForm.Add_Resize({$thisGui.FormResize($thisGui.LockedForm, $args)}.GetNewClosure())
		#/add form resize	

		#status strip
		$this.StatusStrip = [System.Windows.Forms.StatusStrip]::new()
		$this.StatusStrip.Name = 'StatusStrip'
		$this.StatusStrip.AutoSize = $true
		$this.StatusStrip.Left = 0
		$this.StatusStrip.Visible = $true
		$this.StatusStrip.Enabled = $true
		$this.StatusStrip.Dock = [System.Windows.Forms.DockStyle]::Bottom
		$this.StatusStrip.LayoutStyle = [System.Windows.Forms.ToolStripLayoutStyle]::Table
		#/status strip
		
		#striplabel
		$this.Operation = [System.Windows.Forms.ToolStripLabel]::new()
		$this.Operation.Name = 'Operation'
		$this.Operation.Text = $null
		$this.Operation.Width = 50
		$this.Operation.Visible = $true
		#/striplabel
		
		#adding operation to status strip
		$this.StatusStrip.Items.AddRange([System.Windows.Forms.ToolStripItem[]]@($this.Operation))
		
		#adding status strip to the form 
		$this.LockedForm.Controls.Add($this.StatusStrip)
		
		$this.StatusStrip.Items[0].Text = "status" #not really used, here for completeness
		#/status strip

		#tooltip for precising seconds information
		$this.LToolTip = [System.Windows.Forms.ToolTip]::New() 
		
		#add Form Load event handler (mainly for the tooltip)
		$this.LockedForm.Add_Load({$thisGui.LFormLoad($thisGui.LockedForm, $args)}.GetNewClosure()) #before the form is first displayed
		#/add Form Load	

		#add shown event handler (the form is displayed); the form gets focus and information is refreshed
		$this.LockedForm.Add_Shown({$thisGui.LockedForm.Activate();$thisGui.RefreshGrid($true)}.GetNewClosure()) #RefreshGrid here is EnforcedByUI
		
		#/main form
		
		#refresh timer
		$this.LTimer = [System.Windows.Forms.Timer]::New()
		$this.LTimer.Interval = ([int32] $this.DefaultLTimerPeriod) * 1000 #the default period for the main object (LockedGui)
		$this.LTimer.Add_Tick({$thisGui.RefreshGrid($false)}.GetNewClosure()) #EnforcedByUI - false, it is the regular timer tick
		If ($this.AutoRefreshChBox.Checked) {$this.LTimer.Start()} #start if the autorefresh checkbox is chosen

		
		$this.getlusers_fun = $null #at first
		
		$this.unlocklusers_fun = $null #at first
		
		$this.getlusersarechanged_fun = $null #at first 
		
		#custom values (LockedGui object)
		$this.SortDirection = [System.ComponentModel.ListSortDirection]::Ascending #just to initialize
		
		$this.LastSortedColumnIndex = -1 #at first
		
		$this.FormPreviousSize = $this.LockedForm.ClientSize #form resize initialize
		
	} #constructor
	
	#class functions
	
	#returns the icon from the icon func, imported from IconB64.psm1 along other modules
	[System.Drawing.Icon] LoadIcon($GetB64) {
		Write-Verbose "$(date) LoadIcon function started"
		#Write-Verbose $(&$GetB64) #an old check
		return [System.Drawing.Icon][IO.MemoryStream][Convert]::FromBase64String($(&$GetB64))
		}
	
	#it is called by the worker object to give the Gui object its functions in a PSCustomObject
	#here the LockedGui class member functions acccept the outers from the PSCustomObject
	#in this class the the LockedGui class member functions are called 
	[void] GetOuterFnObject([PSCustomObject] $users_ulocker_funs) {
		$this.getlusers_fun = $users_ulocker_funs.GetLUsers
		$this.unlocklusers_fun = $users_ulocker_funs.UnlockLUsers
		$this.getlusersarechanged_fun = $users_ulocker_funs.GetLUsersAreChanged
	}
	
	#visual data refresher function; $EnforcedByUI is used when called from user interaction, otherwise - ordinary timer tick
	[void] RefreshGrid($EnforcedByUI) {
		Write-Verbose "`r`n$(date) *** Start of refreshgrid... ***"
		
		#restarting timer if it is EnforcedByUI and the autorefresh checkbox is checked
		Write-Verbose "$(date) chbox: $($this.AutoRefreshChBox.Checked)"
		if ($this.AutoRefreshChBox.Checked -and $EnforcedByUI) {
			$this.LTimer.Stop()
			$this.LTimer.Start() #alays restart (if refresh is forced)
			Write-Verbose "$(date) Timer restarted at the beginning of refreshgrid."
		}
		
	    $this.Operation.Text = "refreshing..."
	    $this.LockedForm.Refresh() #to show the text "refreshing..."
		$lusers_list = @($this.getlusers_fun.Invoke()) #the function is imported from the PSCustomObject into the class member
		#$lusers_list *= 30 #low users test only #some times is useful for the graphical interface
		if ($lusers_list) {Write-Verbose "$(date) type of lusers list is: $($lusers_list.gettype())";}
		if ($lusers_list) {
	        Write-Verbose "$(date) lusers_list count: $($lusers_list.count)"
	        $this.Operation.Text = "locked users count: $($lusers_list.count)"
	    }
		else {
			Write-Verbose "$(date) empty list"
			$this.Operation.Text = "no locked users"
	    }
		$this.Operation.Text += "$(' '*60)last refreshed: $([DateTime]::Now.ToString())" #65 is the margin for one char locked, here - 5 left
		#this kind of control doesn't support non printing chars (tab)	
		$this.LockedForm.Refresh() #to show the last operation.text
		
		#DataTable
		#datatable columns name filling (10x stackoverflow)
 		[System.Data.DataTable] $dataTable = 'GridData'
		foreach ($column in $lusers_list[0].psobject.properties.name) {
			[void] $dataTable.Columns.Add($column)
		}
		
		#datatable filling rows
		foreach ($item in $lusers_list) {
			$row = $dataTable.NewRow()
			foreach ($property in $dataTable.columns.columnName) {
				$row.$property = $item.$property
			}
			[void] $dataTable.Rows.Add($row)
		}
		
		#datagrid datasource is datatable
		$this.DataGridView.DataSource = $dataTable
		
		#/Datatable
		
		#showing in datagridview
		$this.LockedForm.Refresh()

		Write-Verbose "$(date) After form refresh in refreshgrid"
		
		#it is checked if the state of data i new, if so - icon in tsakbar starts glowing
		If ($this.getlusersarechanged_fun.Invoke()) {
			$this.FlashTaskBarIcon() #(10x cgpt) see the function below
			Write-Verbose "$(date) Started FLASHING The Icon..."
		} 
		
		Write-Verbose "$(date) *** End of refreshgrid ***"

	} #RefreshGrid fn
	
	#message form
	[System.Windows.Forms.Form] CreateMsgForm([string] $message, [int] $unlnum){
		#
		Write-Verbose "$(date) messsage in the message fn: $message"
		Write-Verbose "$(date) unlocked nuber in the message fn: $unlnum"
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
	    #Write-Verbose "$(date) LABEL: $MsgText"
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
		Write-Verbose "$(date) start of UnlockUsers fn"
		Write-Verbose "$(date) enabled only has value $enabledonly"
		Write-Verbose "$(date) selection has value $selection"
		$this.DataGridView.SelectedRows | % {Write-Verbose "Index of selected: $($_.Index)"}
		Write-Verbose "$(date) $($this.DataGridView.SelectedRows)"
	    #Write-Verbose $DataGridView.DataSource
		
		
		$UserData = @()
		
	    If ($selection) {
	        Write-Verbose "$(date) selection option case chosen"
			$this.DataGridView.SelectedRows | % {$UserData += $this.DataGridView.DataSource.Rows[$_.Index];}
	    }
	    else {
	        $UserData = $this.DataGridView.DataSource
	    }
		
	    Write-Verbose "$(date) userdata is: $($UserData)"
		Write-Verbose "$(date) before calling worker, row count is: $($UserData.Rows.Count)"
		
		$unlock_result = $this.unlocklusers_fun.Invoke($UserData, $enabledonly) #$enabledonly is the parameter
		
		Write-Verbose "$(date) after unlock (enabledonly is $enabledonly) pressed"
		$this.RefreshGrid($true) #this is EnforcedByUI, only UI can unlock
		Write-Verbose "$(date) after refreshing in unlock (enabledonly is $enabledonly) block"
		
		Write-Verbose "$(date) Unlocking result: $($unlock_result["unlockednum"]) unlocked users"
		Write-Verbose "$(date) message to sent to msLTablePanel: $($unlock_result["message"])"
		#[System.Windows.Forms.MessageBox]::Show($message) #just to remember how messagebox is called
		
		$msLTablePanel = $this.CreateMsgForm($unlock_result["message"], $unlock_result["unlockednum"])
		$msLTablePanel.ShowDialog()
		
	} #UnlockUsers fn
	
	
	#SortColumnOnHeaderClick column header click event handler (sorting)
	[Void] SortColumnOnHeaderClick($sender, $eventargs) {
		Write-Verbose "$(date) *** entered in SortColumnOnHeaderClick function ***"
		Write-Verbose "$(date) Column Header Clicked: $($eventArgs.ColumnIndex)"

		Write-Verbose "$(date) Column index to sort is $($eventArgs.ColumnIndex)"
		Write-Verbose "$(date) Last sorted column index was $($this.LastSortedColumnIndex)"
		
		If (($this.LastSortedColumnIndex -ge 0) -and ($eventArgs.ColumnIndex -eq $this.LastSortedColumnIndex)) { #here column is the same - the last one clicked
			Write-Verbose "$(date) (sort column) In If, before switching"
			$this.SortDirection = If ($this.SortDirection -eq [System.ComponentModel.ListSortDirection]::Ascending) {[System.ComponentModel.ListSortDirection]::Descending} Else {[System.ComponentModel.ListSortDirection]::Ascending}
		} Else {
			Write-Verbose "$(date) (sort column) In Else, before Ascending"
			$this.SortDirection = [System.ComponentModel.ListSortDirection]::Ascending
		}
		
		Write-Verbose "$(date) Direction to sort the column now is $($this.SortDirection)"
		$this.DataGridView.Sort($this.DataGridView.Columns[$eventArgs.ColumnIndex], $this.SortDirection)
		$this.LastSortedColumnIndex = $eventArgs.ColumnIndex #save the last sorted column
		Write-Verbose "$(date) End of SortColumnOnHeaderClick"
		Write-Verbose "$(date) ***************************************"
	}
	#/SortColumnOnHeaderClick
	
	#DGridCellDoubleClick cell double click event handler (unlocking user in the row)
	[Void] DGridCellDoubleClick($sender, $eventargs) {
		Write-Verbose "***$(date) entered in DGridCellDoubleClick function ***"
		Write-Verbose "$(date) sender: $($sender)"
		Write-Verbose "$(date) eventargs: $($eventargs)"
		Write-Verbose "$(date) eventargs[1].RowIndex: $($eventargs[1].RowIndex)"
		Write-Verbose "$(date) eventargs[1] properties: $($eventargs[1].GetType().GetProperties())"
		#first is the sender, second ([1]) is eventargs
		If ($eventargs[1].RowIndex -lt 0) {return} #header is -1 (10x cgpt)
		$this.UnlockUsers($false, $true) #all users (not only enbled), selection (here only one row is selected - doubleclick)
		Write-Verbose "$(date) End of DGridCellDoubleClick"
		Write-Verbose "$(date) ***************************************"
	}
	#/DGridCellDoubleClick
	
	
	#FormResize resize event handler
	[Void] FormResize([System.Windows.Forms.Control] $sender, $eventargs) {
		Write-Verbose "$(date) *** ENTERED in FormResizeDataGridView function ***"
		Write-Verbose "$(date) sender: $($sender)"
		#$FormControl = [System.Windows.Forms.Form] $sender #cast is not necessary, $sender is the form
		$FormControl = $sender #the name is clearer
		Write-Verbose "$(date) eventargs: $($eventargs)"
		
		$FormNewSize = $FormControl.ClientSize
		
		Write-Verbose "$(date) Previous Form size: Width = $($this.FormPreviousSize.Width), Height = $($this.FormPreviousSize.Height)"
		Write-Verbose "$(date) New Form size: Width = $($FormNewSize.Width), Height = $($FormNewSize.Height)"
		
		#coeficients
		$coefficientHeight = $coefficientWidth = 1
		
		if (($this.FormPreviousSize.Height -ne 0) -and ($FormNewSize.Height -ne 0)) {
			[double] $coefficientHeight = $FormNewSize.Height / $this.FormPreviousSize.Height
		}
		if (($this.FormPreviousSize.Width -ne 0) -and ($FormNewSize.Width -ne 0)) {
			[double] $coefficientWidth = $FormNewSize.Width / $this.FormPreviousSize.Width
		}
		
		Write-Verbose "$(date) coefficientHeight: $($coefficientHeight)"
		Write-Verbose "$(date) coefficientWidth: $($coefficientWidth)"
		
		#TableLayoutPanel resize is not necessary because it is docked to the form
		Write-Verbose "$(date) TableLayoutPanel resize is not necessary because it is docked to the form(!)"

		Write-Verbose "$(date) datagridview height before resize: $($this.DataGridView.Size.Height)"
		Write-Verbose "$(date) datagridview width before resize: $($this.DataGridView.Size.Width)"
		
		#DataGridView resize. It is resized by the form coeficients
		$DGWidth = [int32] ($this.DataGridView.Size.Width * $coefficientWidth)		
		$DGHeight = [int32] ($this.DataGridView.Size.Height * $coefficientHeight)
				
		$this.DataGridView.Size = [System.Drawing.Size]::new($DGWidth, $DGHeight)
		
		Write-Verbose "$(date) datagridview new height: $($this.DataGridView.Size.Height)"
		Write-Verbose "$(date) datagridview new width: $($this.DataGridView.Size.Width)"
		
		$this.FormPreviousSize = $FormNewSize
		
		#columns stretch and scrollbar
		#cgpt adbice #10x cgpt for the below idea and code
		$totalContentWidth = 0
		foreach ($column in $this.DataGridView.Columns) {
			#Calculate the minimum required width based on the content in each column
			$totalContentWidth += $column.GetPreferredWidth([System.Windows.Forms.DataGridViewAutoSizeColumnMode]::AllCells, $true)
		}
		$totalContentWidth += $this.DataGridView.RowHeadersWidth #+ the empty first column (41 px)
		#Write-Verbose "RowHeadersWidth: $($this.DataGridView.RowHeadersWidth)"

		Write-Verbose "$(date) totalContentWidth: $($totalContentWidth)"
		Write-Verbose "$(date) DataGridView.ClientSize.Width: $($this.DataGridView.ClientSize.Width)"

		# If the total content width is greater than the DataGridView width, show the scrollbar
		if ($totalContentWidth -gt $this.DataGridView.ClientSize.Width) {
			$this.DataGridView.AutoSizeColumnsMode = 'None'  # Disable Fill temporarily to show the scrollbar
			Write-Verbose "$(date) in IF (totalContentWidth > DataGridView.ClientSize.Width) DataGridView.AutoSizeColumnsMode: $($this.DataGridView.AutoSizeColumnsMode)"
			foreach ($column in $this.DataGridView.Columns) {
				$column.Width = $column.GetPreferredWidth([System.Windows.Forms.DataGridViewAutoSizeColumnMode]::AllCells, $true)
			} #foreach
		} else {
			$this.DataGridView.AutoSizeColumnsMode = 'Fill'  # Re-enable Fill when there's enough space
			Write-Verbose "$(date) in ELSE (totalContentWidth < DataGridView.ClientSize.Width) DataGridView.AutoSizeColumnsMode: $($this.DataGridView.AutoSizeColumnsMode)"
		} #if else	
		#/cgpt advice		
		Write-Verbose "$(date) *** END of FormResizeDataGridView function ***"
	}
	#/FormResize
	
	#autorefresh checkbox checkedchanged event handler
	[Void] AutoRChBoxCheckedChanged($sender, $eventargs) {
		Write-Verbose "***$(date) entered in AutoRChBoxCheckedChanged function ***"
		Write-Verbose "$(date) sender: $($sender)"
		Write-Verbose "$(date) eventargs: $($eventargs)"
		Write-Verbose "$(date) sender checked: $($sender.Checked)"
		If ($sender.Checked) {
			$this.LTimer.Enabled = $true
			$this.RefreshGrid($true) #EnforcedByUI (checkbox)
		} Else {
			$this.LTimer.Enabled = $false
		}
		Write-Verbose "$(date) the Timer enabled set to $($this.LTimer.Enabled)"
		Write-Verbose "***$(date) end of AutoRChBoxCheckedChanged function ***"
	} #/autorefresh checkbox checkedchanged
	
	#event hanfler to permit only digits and backspace (10x cgpt)
	#autorefresh KeyPress event handler (it is fired on any single key press)
	[Void] SecTextKeyPress($sender, $eventargs) {
		Write-Verbose "`n`r***$(date) entered in SecTextKeyPress function ***"
		Write-Verbose "$(date) sender: $($sender)"
		Write-Verbose "$(date) eventargs: $($eventargs)" #array of two
		Write-Verbose "$(date) Character pressed: $($eventargs.KeyCHar)"
		if (($eventargs.KeyChar -notmatch '[0-9]') -and ($eventargs.KeyChar -ne [char]8)) {	
			# If the input is not a digit or backspace(8), cancel the input
			$eventargs[1].Handled = $true #second member is $eventargs
		} elseif ($eventargs.KeyChar -eq [char]'.') { #carefully here cgpt helped
			$eventargs[1].Handled = $true #this case is especialy for blocking period character
		} else {
			$sender.ForeColor = [System.Drawing.Color]::Red #Change to red while typing #10x cgpt
			Write-Verbose "$(date) ForeColor set to Red"
		}
		Write-Verbose "***$(date) end of SecTextKeyPress function ***"
	}#autorefresh KeyPress event handler
	
	#event hanfler to handle Return key (10x cpgt)
	#seconds texbox KeyDown event handler
	[Void] SecTextKeyDown($sender, $eventargs) {
		Write-Verbose "`n`r***$(date) entered in SecTextKeyDown function ***"
		Write-Verbose "$(date) sender: $($sender)"
		Write-Verbose "$(date) eventargs: $($eventargs)" #array of two
		Write-Verbose "$(date) any key, before handling -  $($eventargs.KeyCode) key pressed"
		#Enable Del key explicitly (KeyCode for Del is 46) (46 coincides with ASCII 46, which is period, explaining why we address it here)
		if ($eventargs.KeyCode -eq [System.Windows.Forms.Keys]::Delete) {
			Write-Verbose "$(date) In if keycode -eq delete - yes"
			$eventargs[1].Handled = $false # Allow Delete key functionality
			$sender.ForeColor = [System.Drawing.Color]::Red # Change to red while typing #cgpt here
			Write-Verbose "$(date) ForeColor set to Red in KeyDown"
		}
		
		if ($eventargs.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
			#Process the input on Enter key
			Write-Verbose "$(date) $($eventargs.KeyCode) key pressed (should be only Enter now)"
			#if user applyed empty string or zero - reverse to default
			If (![int32]$sender.Text) {$sender.Text = $this.DefaultLTimerPeriod} #the default period is custom member of the $LockedGui, it is set in the constrictor
			$this.LTimer.Interval = ([int32] $sender.Text) * 1000
			Write-Verbose "$(date) the LTimer Interval was set to $($sender.Text) seconds"
			$sender.ForeColor = [System.Drawing.Color]::Black # Change back to black
			Write-Verbose "$(date) ForeColor set to Black"
			Write-Verbose "$(date) calling refreshedgrid , EnforcedByUI"
			$this.RefreshGrid($true) #EnforcedByUI (the user applyed new time period)
		}
		Write-Verbose "***$(date) end of SecTextKeyDown function ***"
	} #/seconds texbox KeyDown event handler
	
	#function glowing icon in taskbar, FlashWindow is a function imported from user32.dll into the class WinAPIFlash (10x cgpt)
	#the operation is implemented with Add-Type cmdlet in the assemblies psm1 file
	[Void] FlashTaskBarIcon() {
		If (!$this.LockedForm.Focused) {
			[WinAPIFlash]::FlashWindow($this.LockedForm.Handle, $true)
		}
	} #glowing function
	
	
	#Form Load event handler (serving tooltip purposes in this case)
	[Void] LFormLoad($sender, $eventargs) {	
		#Set up the delays for the LToolTip. (almost all of this is copied drom MS .net help)
		$this.LToolTip.AutoPopDelay = 5000; #the time to stay visible
		$this.LToolTip.InitialDelay = 500; #the time to wait until it appears
		$this.LToolTip.ReshowDelay = 500; #the time to wait when moving pointer between controls
		#Force the ToolTip text to be displayed whether or not the form is active.
		$this.LToolTip.ShowAlways = $true; #to be shown even if control is not in focus
      
		#Set up the ToolTip text for the TextBox and CheckBox.
		$LTooltipText = "Values above 5 seconds are recomended."
		$this.LToolTip.SetToolTip($this.AutoRefreshChBox, $LTooltipText)
		$this.LToolTip.SetToolTip($this.AutoRSecondsLabel, $LTooltipText)
		$this.LToolTip.SetToolTip($this.SecondsText, $LTooltipText)
	}
	
	#showing the main form function (it is called by the Run() function of worker)
	[void] Show() {
			[void]$this.LockedForm.ShowDialog()
	}#/Show main form fn
	
	
	
} #class LockedGui
