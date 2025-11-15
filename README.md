# WSS
Windows 11 Setup Script

#### To run this script run this in Powershell as Administrator:
```powershell
irm https://raw.githubusercontent.com/ayu2805/wss/main/wss.ps1 | iex
```

> Note: If you want to run setup git, run:\
`irm https://raw.githubusercontent.com/ayu2805/wss/main/git-config.ps1 | iex`

### Windows Debloat Management
#### Remove All Removable Packages
To remove all removable packages, run the following PowerShell command:
```powershell
Get-AppxPackage -AllUsers | Remove-AppxPackage -ErrorAction SilentlyContinue
```

#### Remove All Removable Optional Features
To remove all removable optional features, execute the command below:
```powershell
Get-WindowsCapability -Online | Where-Object {$_.State -eq 'Installed'} | ForEach-Object { 
    try { 
        Remove-WindowsCapability -Online -Name $_.Name 
    } catch { 
        Write-Host "Skipped Permanent Optional Features"
    } 
}
```

#### Check All Removable Windows Features
To check and disable all removable Windows features, use the following command:
```powershell
Get-WindowsOptionalFeature -Online | Where-Object {$_.State -eq 'Enabled'} | ForEach-Object { 
    try {
        Disable-WindowsOptionalFeature -Online -Name $_.Name 
    } catch { 
        Write-Host "Skipped Permanent Windows Features" 
    } 
}
```
