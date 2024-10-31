class LockedGui {
	
	[System.Windows.Forms.Form] $LockedForm
	
	[System.Windows.Forms.Label] $UnlockLabel
	
	#FlowLayoutPanel for buttons to be in a row
	[System.Windows.Forms.FlowLayoutPanel] $LButtonsPanel
	
	[System.Windows.Forms.Button] $RefreshButton
	
	[System.Windows.Forms.Button] $UnlockEnabledButton
	
	[System.Windows.Forms.Button] $UnlockAllButton
	
	[System.Windows.Forms.DataGridView] $DataGridView
	
	[System.Windows.Forms.StatusStrip] $StatusStrip
	
	[System.Windows.Forms.ToolStripLabel] $Operation
	
	[System.Windows.Forms.ContextMenuStrip] $DgrContextMenuStrip
	
	#FlowLayoutPanel for all controls (including $LButtonsPanel) to be in a grid for resize
	[System.Windows.Forms.TableLayoutPanel] $LFlowPanel
	
	#custom values
	[System.ComponentModel.ListSortDirection] $SortDirection
	
	[Int32] $LastSortedColumnIndex
	
	[System.Drawing.Size] $FormPreviousSize
	
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
	
		#TableFlowLayoutPanel (contains all other controls)
		$this.LFlowPanel = [System.Windows.Forms.TableLayoutPanel]::new()
		#GrowStyle is AddRows by default (ours)
		$this.LFlowPanel.Location = [System.Drawing.Point]::new(30,15)
		$this.LFlowPanel.Size = [System.Drawing.Size]::new(455,595) #afterwards docked fill
		#$this.LFlowPanel.BorderStyle = 'FixedSingle' #when we want to see the panel 
		$this.LFlowPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
		$this.LockedForm.Controls.Add($this.LFlowPanel)
		#continuing with inner controls
	
		#label
		$this.UnlockLabel = [System.Windows.Forms.Label]::new()
		$this.UnlockLabel.Text = "Locked users:"
		$this.UnlockLabel.Text += "`r`nUnlock specific user with double click on the row."
		$this.UnlockLabel.Text += "`r`nUnlock marked users with right click and context menu click."

		$this.UnlockLabel.Size = [System.Drawing.Size]::new(450,40) #40 (!)
		#$this.UnlockLabel.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left #left for howto

		$this.LFlowPanel.Controls.Add($this.UnlockLabel)
		#/label
		
		#LButtonsPanel (contains the buttons in a row)
		$this.LButtonsPanel = [System.Windows.Forms.FlowLayoutPanel]::new()	
		$this.LButtonsPanel.Size = [System.Drawing.Size]::new(290,35) #(buttons width + 15 for distance and hight of a button +5)
		$this.LFlowPanel.Controls.Add($this.LButtonsPanel)
		Write-Verbose "$(date) buttons panel added"
		#adding buttons below
	
	
		#refresh button
		$this.RefreshButton = [System.Windows.Forms.Button]::new()
		$this.RefreshButton.Text = "Refresh"
		$this.RefreshButton.Size = [System.Drawing.Size]::new(60,30)
		#add click event handler
		$this.RefreshButton.Add_Click({$thisGui.RefreshGrid()}.GetNewClosure()) #(!)
		$this.LButtonsPanel.Controls.Add($this.RefreshButton)
		Write-Verbose "$(date) refresh button added"
		#/refresh button
		
				
		#unlock enabled button
		$this.UnlockEnabledButton = [System.Windows.Forms.Button]::new()
		$this.UnlockEnabledButton.Text = "Unlock Enabled"
		$this.UnlockEnabledButton.Size = [System.Drawing.Size]::new(100,30)
		#add click event handler
		$this.UnlockEnabledButton.Add_Click({$thisGui.UnlockUsers($true, $false)}.GetNewClosure()) #(!) enabledonly, not selection
		$this.LButtonsPanel.Controls.Add($this.UnlockEnabledButton)
		Write-Verbose "$(date) unlock enabled button added"
		#/unlock enabled button
		
			
		#unlock all Button
		$this.UnlockAllButton = [System.Windows.Forms.Button]::new()
		$this.UnlockAllButton.Text = "Unlock All"
		$this.UnlockAllButton.Size = [System.Drawing.Size]::new(100,30)
		#add click event handler
		$this.UnlockAllButton.Add_Click({$thisGui.UnlockUsers($false, $false)}.GetNewClosure()) #(!) enabled all (not only), not selection
		$this.LButtonsPanel.Controls.Add($this.UnlockAllButton)
		Write-Verbose "$(date) unlockall button added"
		#/unlock all Button	
		
		#adding the LButtonsPanel to the big LFlowPanel
		$this.LFlowPanel.Controls.Add($this.LButtonsPanel)

		
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
		$this.DataGridView.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Bottom #without right for correct resizing
		
		#context menu
		$this.DgrContextMenuStrip = [System.Windows.Forms.ContextMenuStrip]::new()
		$this.DgrContextMenuStrip.Items.Add("Unlock selected users...").add_Click({$thisGui.UnlockUsers($false, $true)}.GetNewClosure()) #(!) enabled all (not only), selection
		$this.DataGridView.ContextMenuStrip = $this.DgrContextMenuStrip
		#/context menu
	
		#add cell double click event handler 
		$this.DataGridView.Add_CellDoubleClick({$thisGui.DGridCellDoubleClick($thisGui.DataGridView, $args)}.GetNewClosure())
		#/add cell doubleclick
		
		#add column header click event handler
		$this.DataGridView.Add_ColumnHeaderMouseClick({$thisGui.SortColumnOnHeaderClick($thisGui.DataGridView, $args)}.GetNewClosure())
		#/column header click
				
		#add resize event handler
		$this.LockedForm.Add_Resize({$thisGui.FormResize($thisGui.LockedForm, $args)}.GetNewClosure())
		#/add resize		
		
		#ading datagridview to the big LFlowPanel
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
		
		$this.StatusStrip.Items[0].Text = "status" #not really used
		#/status strip
		
		$this.LockedForm.Add_Shown({$thisGui.RefreshGrid()}.GetNewClosure()) #on load
	
		$this.getlusers_fun = $null #at first
		
		$this.unlocklusers_fun = $null # at first
		
		#custom values
		$this.SortDirection = [System.ComponentModel.ListSortDirection]::Ascending #just to initialize
		
		$this.LastSortedColumnIndex = -1 # at first
		
		$this.FormPreviousSize = $this.LockedForm.ClientSize #resize initialize
		
	} #constructor
	
	[System.Drawing.Icon] LoadIcon($GetB64) {
		Write-Verbose "$(date) load icon func"
		#Write-Verbose $(&$GetB64)
		return [System.Drawing.Icon][IO.MemoryStream][Convert]::FromBase64String($(&$GetB64))
		}
	
	[void] GetOuterFnObject([PSCustomObject] $users_ulocker_funs) {
		$this.getlusers_fun = $users_ulocker_funs.GetLUsers
		$this.unlocklusers_fun = $users_ulocker_funs.UnlockLUsers
	}
	
	[void] RefreshGrid() {
		Write-Verbose "$(date) Start of refreshgrid..."
	    $this.Operation.Text = "refreshing..."
	    $this.LockedForm.Refresh()
		$lusers_list = @($this.getlusers_fun.Invoke())
		#$lusers_list *= 30 #low users test only
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
		$this.LockedForm.Refresh()
		
		#DataTable
		#datatable columns name filling
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
		
		
		$this.LockedForm.Refresh()

		Write-Verbose "$(date) After refresh in refreshgrid"
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
		
		$unlock_result = $this.unlocklusers_fun.Invoke($UserData, $enabledonly) #$enabledonly is the parameter
		
		Write-Verbose "$(date) after unlock (enabledonly is $enabledonly) pressed"
		$this.RefreshGrid()
		Write-Verbose "$(date) after refreshing in unlock (enabledonly is $enabledonly) block"
		
		Write-Verbose "$(date) Unlocking result: $($unlock_result["unlockednum"]) unlocked users"
		Write-Verbose "$(date) message to sent to msLFlowPanel: $($unlock_result["message"])"
		#[System.Windows.Forms.MessageBox]::Show($message) #just to remember how messagebox is called
		
		$msLFlowPanel = $this.CreateMsgForm($unlock_result["message"], $unlock_result["unlockednum"])
		$msLFlowPanel.ShowDialog()
		
	} #UnlockUsers fn
	
	
	#SortColumnOnHeaderClick column header click event handler
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
	
	#DGridCellDoubleClick cell double click event handler
	[Void] DGridCellDoubleClick($sender, $eventargs) {
		Write-Verbose "***$(date) entered in DGridCellDoubleClick function ***"
		Write-Verbose "$(date) sender: $($sender)"
		Write-Verbose "$(date) eventargs: $($eventargs)"
		Write-Verbose "$(date) eventargs[1].RowIndex: $($eventargs[1].RowIndex)"
		Write-Verbose "$(date) eventargs[1] properties: $($eventargs[1].GetType().GetProperties())"
		#first is the sender, second ([1]) is eventargs
		If ($eventargs[1].RowIndex -lt 0) {return} #header is -1
		$this.UnlockUsers($false, $true) #(!) enabled all (not only), selection
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
		<#
		$FPWidth = [int32] ($this.LFlowPanel.Size.Width * $coefficientWidth)
		$FPHeight = [int32] ($this.LFlowPanel.Size.Height * $coefficientHeight)
		$this.LFlowPanel.Size = [System.Drawing.Size]::new($FPWidth, $FPHeight)
		Write-Verbose "LFlowPanel new height: $($this.LFlowPanel.Size.Height)"
		Write-Verbose "LFlowPanel new width: $($this.LFlowPanel.Size.Width)"
		#>

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
		#cgpt advice (little cgpt prompting...)
		$totalContentWidth = 0
		foreach ($column in $this.DataGridView.Columns) {
			# Calculate the minimum required width based on the content in each column
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
	
	
	[void] Show() {
			[void]$this.LockedForm.ShowDialog()
	} #Show fn
	
	
	
	
} #class LockedGui

