# WSS
Windows 11 Setup Script

#### To run this script run this in Powershell as Administrator:
```powershell
irm https://raw.githubusercontent.com/ayu2805/wss/main/wss.ps1 | iex
```

> Note: If you want to run setup git, run:\
`irm https://raw.githubusercontent.com/ayu2805/wss/main/git-config.ps1 | iex`

### Remove unnecessary packages
To remove unnecessary packages i.e. Store (UWP) Apps, run the following PowerShell command:
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
### Clear Windows Update History
To clear the Windows Update history, run the following PowerShell commands:
```powershell
Stop-Service -Name UsoSvc -Force
Grant-UserAccess -FilePath "C:\ProgramData\USOPrivate\UpdateStore\store.db"
Remove-Item -Path "C:\ProgramData\USOPrivate\UpdateStore\store.db"
Start-Service -Name UsoSvc
```
> Note: `Grant-UserAccess` will be added by the script, so use the commands above only after running the basic customization script.
