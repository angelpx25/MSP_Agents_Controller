# MSP Agents Controller

A lightweight Windows desktop app (PowerShell + WinForms) that gives MSP technicians a single window for viewing endpoint agents across the tools they manage: Webroot, Cynet, Datto RMM, ScreenConnect, and Liongard.

> **Status:** beta 0.1. Only the Webroot integration is wired up. The other agents appear in the menu as placeholders.

---

## Features

- Single-window WinForms interface with a menu bar (**File**, **Refresh**, **Agents**, **About**)
- **Webroot** integration:
  - Authenticates with OAuth 2.0 client credentials
  - Lists all sites in the left pane
  - Click a site to list its agents (ID, name, online/offline status) in the right pane
- Resizable window with a responsive title label
- No installation or external modules required. It uses only built-in .NET assemblies.

### Supported agents

| Agent | Status |
|---|---|
| Webroot | Working: lists sites and agents |
| Cynet | Planned |
| Datto RMM | Planned |
| ScreenConnect | Planned |
| Liongard | Planned |

---

## Requirements

- Windows 10/11 or Windows Server
- Windows PowerShell 5.1 (WinForms is not available in PowerShell 7 on non-Windows platforms)
- Webroot API credentials (client ID and client secret) with read access to your sites

---

## Getting started

### 1. Clone the repository

```powershell
git clone https://github.com/angelpx25/MSP_Agents_Controller.git
cd MSP_Agents_Controller
```

### 2. Configure Webroot credentials

The defaults are set in the `Get-WebrootToken` function in `Start.ps1`:

```powershell
function Get-WebrootToken {
    param(
        [string]$ClientId     = '<YOUR_CLIENT_ID>',
        [string]$ClientSecret = '<YOUR_CLIENT_SECRET>',
        [string]$TokenUrl     = 'https://api.webrootanywhere.com/auth/token'
    )
    ...
}
```

Rather than typing secrets into the script, read them from environment variables:

```powershell
[string]$ClientId     = $env:WEBROOT_CLIENT_ID,
[string]$ClientSecret = $env:WEBROOT_CLIENT_SECRET,
```

and set them once per user:

```powershell
[Environment]::SetEnvironmentVariable('WEBROOT_CLIENT_ID', 'your-id', 'User')
[Environment]::SetEnvironmentVariable('WEBROOT_CLIENT_SECRET', 'your-secret', 'User')
```

Check the token URL and API base URL (`Get-WebrootSites`, `Get-WebrootAgentsBySite`) against the Webroot API documentation for your account before use.

### 3. Run

```powershell
powershell.exe -ExecutionPolicy Bypass -STA -File .\Start.ps1
```

`-STA` is recommended for WinForms apps.

---

## Usage

1. Launch `Start.ps1`.
2. Open **Agents → Webroot**. The app requests a token and loads your sites.
3. Select a site on the left to see its agents on the right.
4. **Refresh** updates the timestamp on the home screen.
5. **About** shows the version.

---

## Project structure

```
MSP_Agents_Controller/
└── Start.ps1     # Entire application: UI, menus, and Webroot API helpers
```

### Key functions

| Function | Purpose |
|---|---|
| `Get-WebrootToken` | Requests an OAuth access token with client credentials |
| `Get-WebrootSites` | `GET /sites`: returns the sites for the account |
| `Get-WebrootAgentsBySite` | `GET /sites/{siteId}/agents`: returns the agents for a site |

---

## Known issues

- The placeholder message for non-Webroot agents always shows the last agent name ("Liongard"). This happens because the click handler reads `$a` when it runs, not when it was created. Using `.GetNewClosure()` on the handler fixes this.
- A new token is requested every time a site is selected. It could be cached until it expires.
- **File → Open Configuration** is not implemented yet.
- If an agent has no `name`, the name column may show `True`/`False`. This is because of the `-or ''` expression in the site-selection handler.

---

## Roadmap

- Integrations for Cynet, Datto RMM, ScreenConnect, and Liongard
- A configuration file for API credentials, with secrets stored in Windows Credential Manager or SecretManagement
- Agent actions such as scan, isolate, and uninstall
- Search, filtering, and CSV export of agent lists
- A combined view of each device's status across all tools

---

## Author

Angel Paruas
