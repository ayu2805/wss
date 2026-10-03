# WSS
Windows 11 Setup Script

#### To run this script run this in Powershell as Administrator:
```powershell
irm https://raw.githubusercontent.com/ayu2805/wss/main/wss.ps1 | iex
```

> Note: If you want to run setup git, run:\
`irm https://raw.githubusercontent.com/ayu2805/wss/main/git-config.ps1 | iex`

### Windows Debloat Management

#### Remove unnecessary packages
To remove unnecessary packages, run the following PowerShell command:
```powershell
$Exceptions = 'Extension|NET|UI\.Xaml|Runtime|WindowsStore|WindowsNotepad|WindowsCalculator|Photos|VCLibs|ScreenSketch'

Get-AppxPackage |
    Where-Object {
        $_.NonRemovable -eq $false -and
        $_.PackageFullName -notmatch $Exceptions
    } |
    ForEach-Object {
        Remove-AppxPackage -Package $_.PackageFullName
    }
```

#### Remove All Removable Optional Features
To remove all removable optional features, run the following PowerShell command:
```powershell
Get-WindowsCapability -Online | Where-Object { $_.State -eq 'Installed' } | ForEach-Object {
    $name = $_.Name
    try {
        Remove-WindowsCapability -Online -Name $name
        Write-Host "Successfully removed: $name"
    }
    catch {
        Write-Host "Skipped removal: $name"
    }
}
```

#### Remove All Removable Windows Features
To check and disable all removable Windows features, run the following PowerShell command:
```powershell
Get-WindowsOptionalFeature -Online | Where-Object {$_.State -eq 'Enabled'} | ForEach-Object {
    $name = $_.FeatureName
    try {
        Disable-WindowsOptionalFeature -Online -NoRestart -FeatureName $name
        Write-Host "Successfully removed: $name"
    }
    catch {
        Write-Host "Skipped removal: $name"
    }
}
```

### Clear Windows Update History
To clear the Windows Update history, run the following PowerShell commands:
```powershell
Stop-Service -Name UsoSvc -Force
Grant-UserAccess -FilePath "C:\ProgramData\USOPrivate\UpdateStore\store.db"
Remove-Item -Path "C:\ProgramData\USOPrivate\UpdateStore\store.db"
Start-Service -Name UsoSvc
```
> Note: `Grant-UserAccess` will be added by the script, so use the commands above only after running the basic customization script.
