Add-Type -AssemblyName System.Windows.Forms,System.Drawing

# Main form
$form = New-Object System.Windows.Forms.Form
$form.Text = "MSPController"
$form.Size = New-Object System.Drawing.Size(900,600)
$form.StartPosition = "CenterScreen"
$form.MinimumSize = New-Object System.Drawing.Size(400,300)

# Centered dynamic label (resizes and stays centered)
$label = New-Object System.Windows.Forms.Label
$label.Text = "MSPController"
$label.Dock = 'Fill'
$label.TextAlign = 'MiddleCenter'
$label.Font = New-Object System.Drawing.Font("Segoe UI",28,[System.Drawing.FontStyle]::Bold)
$label.BackColor = [System.Drawing.Color]::White
$form.Controls.Add($label)

# Menu strip
$menuStrip = New-Object System.Windows.Forms.MenuStrip

# File menu with Exit
$menuFile = New-Object System.Windows.Forms.ToolStripMenuItem "File"
$menuOpenConfiguration = New-Object System.Windows.Forms.ToolStripMenuItem "Open Configuration"
$menuOpenConfiguration.Add_Click({
    [System.Windows.Forms.MessageBox]::Show("Open Configuration clicked","File", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
})
$menuFile.DropDownItems.Add($menuOpenConfiguration) | Out-Null
$menuExit = New-Object System.Windows.Forms.ToolStripMenuItem "Exit"
$menuExit.Add_Click({ $form.Close() })
$menuFile.DropDownItems.Add($menuExit) | Out-Null
$menuStrip.Items.Add($menuFile) | Out-Null

# Refresh menu (main entry)
$menuRefresh = New-Object System.Windows.Forms.ToolStripMenuItem "Refresh"
$menuRefresh.Add_Click({
    $label.Text = "Refreshed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
})
$menuStrip.Items.Add($menuRefresh) | Out-Null

# Agents menu with subitems (Webroot will have a richer handler)
$menuAgents = New-Object System.Windows.Forms.ToolStripMenuItem "Agents"
$agents = @("Webroot","Cynet","Datto RMM","ScreenConnect","Liongard")
foreach ($a in $agents) {
    $item = New-Object System.Windows.Forms.ToolStripMenuItem $a
    # default handlers for non-Webroot entries
    if ($a -ne 'Webroot') {
        $item.Add_Click({
            [System.Windows.Forms.MessageBox]::Show("Selected agent: $a","Agents", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
        })
    }
    $menuAgents.DropDownItems.Add($item) | Out-Null
}
$menuStrip.Items.Add($menuAgents) | Out-Null

# About menu
$menuAbout = New-Object System.Windows.Forms.ToolStripMenuItem "About"
$menuAbout.Add_Click({
    [System.Windows.Forms.MessageBox]::Show("MSPController`nVersion: beta 0.1`nBy Angel Paruas","About MSPController", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
})
$menuStrip.Items.Add($menuAbout) | Out-Null

$form.MainMenuStrip = $menuStrip
$form.Controls.Add($menuStrip)

# Show welcome popup when form first appears
#$shownOnce = $false
#$form.Add_Shown({
#    if (-not $shownOnce) {
#        $shownOnce = $true
#        [System.Windows.Forms.MessageBox]::Show("Welcome to MSPController by Angel Paruas`nVersion: beta 0.1","MSPController", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
#    }
#})

# Keep label font responsive
$form.Add_Resize({
    try {
        $newSize = [Math]::Max(10, [int]($form.ClientSize.Height / 8))
        $label.Font = New-Object System.Drawing.Font("Segoe UI", $newSize, [System.Drawing.FontStyle]::Bold)
    } catch {}
})

# --- Webroot UI controls (hidden until needed) ---
$splitWebroot = New-Object System.Windows.Forms.SplitContainer
$splitWebroot.Dock = 'Fill'
$splitWebroot.Orientation = 'Vertical'
$splitWebroot.SplitterDistance = 260
$splitWebroot.Visible = $false

# Left: sites list
$listSites = New-Object System.Windows.Forms.ListBox
$listSites.Dock = 'Fill'
$listSites.IntegralHeight = $true
$listSites.DisplayMember = 'Name'
$splitWebroot.Panel1.Controls.Add($listSites)

# Right: agents list (details)
$listAgents = New-Object System.Windows.Forms.ListView
$listAgents.Dock = 'Fill'
$listAgents.View = 'Details'
$listAgents.FullRowSelect = $true
$listAgents.GridLines = $true
$listAgents.Columns.Add("Agent ID",120) | Out-Null
$listAgents.Columns.Add("Name",220) | Out-Null
$listAgents.Columns.Add("Status",120) | Out-Null
$splitWebroot.Panel2.Controls.Add($listAgents)

# Add to form but hidden initially. Put it above the label so it can replace when shown.
$form.Controls.Add($splitWebroot)
$splitWebroot.BringToFront()

# --- Webroot API helper functions ---
# NOTE: Replace client id/secret and endpoints with real values before use
function Get-WebrootToken {
    param(
        [string]$ClientId = '<YOUR_CLIENT_ID>',
        [string]$ClientSecret = '<YOUR_CLIENT_SECRET>',
        [string]$TokenUrl = 'https://api.webrootanywhere.com/auth/token'
    )
    $body = @{
        grant_type = 'client_credentials'
        client_id = $ClientId
        client_secret = $ClientSecret
    }
    try {
        $resp = Invoke-RestMethod -Method Post -Uri $TokenUrl -Body $body -ContentType 'application/x-www-form-urlencoded' -ErrorAction Stop
        return $resp.access_token
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to get token: $($_.Exception.Message)","Error",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        return $null
    }
}

function Get-WebrootSites {
    param(
        [string]$BaseUrl = 'https://api.webrootanywhere.com/v1',
        [string]$Token
    )
    if (-not $Token) { return @() }
    $headers = @{ Authorization = "Bearer $Token" }
    try {
        $uri = "$BaseUrl/sites"
        $resp = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ErrorAction Stop
        if ($resp -and $resp.items) { return $resp.items } else { return $resp }
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to get sites: $($_.Exception.Message)","Error",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        return @()
    }
}

function Get-WebrootAgentsBySite {
    param(
        [string]$BaseUrl = 'https://api.webrootanywhere.com/v1',
        [string]$Token,
        [string]$SiteId
    )
    if (-not $Token) { return @() }
    $headers = @{ Authorization = "Bearer $Token" }
    try {
        $uri = "$BaseUrl/sites/$SiteId/agents"
        $resp = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -ErrorAction Stop
        if ($resp -and $resp.items) { return $resp.items } else { return $resp }
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to get agents for site $SiteId $($_.Exception.Message)","Error",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        return @()
    }
}

# --- Wiring logic for Webroot menu item ---
$webrootMenuItem = $menuAgents.DropDownItems | Where-Object { $_.Text -eq 'Webroot' }
if ($webrootMenuItem) {
    # remove any existing handler by creating a fresh delegate and adding it
    $handler = {
        # Show UI
        $label.Visible = $false
        $splitWebroot.Visible = $true
        $form.Cursor = [System.Windows.Forms.Cursors]::Wait

        # Acquire token (edit Get-WebrootToken defaults or pass credentials)
        $token = Get-WebrootToken
        if (-not $token) {
            $form.Cursor = [System.Windows.Forms.Cursors]::Default
            return
        }

        # Get sites and populate left list
        $listSites.Items.Clear()
        $sites = Get-WebrootSites -Token $token
        foreach ($s in $sites) {
            $display = if ($s.name) { $s.name } else { $s.id }
            $obj = [PSCustomObject]@{ Id = $s.id; Name = $display; Raw = $s }
            $listSites.Items.Add($obj) | Out-Null
        }

        $form.Cursor = [System.Windows.Forms.Cursors]::Default
    }
    # Clear previous click handlers by replacing the item (safe approach)
    $parent = $webrootMenuItem.OwnerItem
    $menuAgents.DropDownItems.Remove($webrootMenuItem)
    $newItem = New-Object System.Windows.Forms.ToolStripMenuItem "Webroot"
    $newItem.Add_Click($handler)
    $menuAgents.DropDownItems.Insert(0, $newItem) | Out-Null
    # update reference
    $webrootMenuItem = $newItem
}

# When a site is selected, load agents for that site
$listSites.Add_SelectedIndexChanged({
    if ($listSites.SelectedItem -ne $null) {
        $sel = $listSites.SelectedItem
        $siteId = $sel.Id
        $form.Cursor = [System.Windows.Forms.Cursors]::Wait

        $token = Get-WebrootToken
        if (-not $token) {
            $form.Cursor = [System.Windows.Forms.Cursors]::Default
            return
        }

        $agents = Get-WebrootAgentsBySite -Token $token -SiteId $siteId
        $listAgents.Items.Clear()
        foreach ($a in $agents) {
            $id = if ($a.id) { $a.id } else { '' }
            $name = if ($a.name) { $a.name } else { ($a.displayName -as [string]) -or '' }
            $status = if ($a.status) { $a.status } else { if ($a.online) { 'Online' } else { 'Offline' } }
            $lvi = New-Object System.Windows.Forms.ListViewItem($id)
            $lvi.SubItems.Add($name) | Out-Null
            $lvi.SubItems.Add($status) | Out-Null
            $listAgents.Items.Add($lvi) | Out-Null
        }

        # Auto-size columns a bit
        for ($i=0; $i -lt $listAgents.Columns.Count; $i++) {
            $listAgents.AutoResizeColumn($i, [System.Windows.Forms.ColumnHeaderAutoResizeStyle]::HeaderSize)
        }

        $form.Cursor = [System.Windows.Forms.Cursors]::Default
    }
})

# Start the message loop (single place)
[void][System.Windows.Forms.Application]::Run($form)
