$ProgressPreference = 'SilentlyContinue'
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

# Function to add Clear-PSHistory to the profile
function Add-ClearPSHistoryFunction {
  $functionCode = @'
function Clear-PSHistory {
  $historyPath = (Get-PSReadLineOption).HistorySavePath
  if (Test-Path $historyPath) {
    Remove-Item $historyPath -Force
    Write-Host "PowerShell history cleared."
  }
  else {
    Write-Host "No history file found at $historyPath."
  }
}
'@

  if (-not (Test-Path $PROFILE)) {
    New-Item -Path $PROFILE -ItemType File -Force | Out-Null
  }
  
  if (-not (Get-Content $PROFILE | Select-String -Pattern 'function Clear-PSHistory')) {
    Add-Content -Path $PROFILE -Value $functionCode
    Write-Host "Clear-PSHistory function added to profile."
  }
  else {
    Write-Host "Clear-PSHistory function already exists in profile."
  }
}

# Function to check if running with administrative privileges
function Test-Admin {
  $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
  return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to change computer name
function Set-ComputerName {
  param (
    [string]$newName
  )
  if ($newName -match '^[a-zA-Z0-9-]+$' -and $newName.Length -le 15) {
    try {
      Rename-Computer -NewName $newName -Force -ErrorAction Stop
      Write-Host "Computer name changed successfully to $newName." -ForegroundColor Green
    }
    catch {
      Write-Error "Failed to change computer name: $_"
    }
  }
  else {
    Write-Error "Invalid computer name. Please ensure it contains only letters, numbers, and hyphens, and is no longer than 15 characters."
  }
}

# Function to update registry settings
function Update-RegistrySettings {
  param (
    [array]$settings
  )
  foreach ($setting in $settings) {
    try {
      if (-NOT (Test-Path $setting.Path)) {
        New-Item -Path $setting.Path -Force | Out-Null
      }
      Set-ItemProperty -Path $setting.Path -Name $setting.Name -Value $setting.Value -Type $setting.Type -Force -ErrorAction Stop
      Write-Host "Updated registry setting $($setting.Name) successfully." -ForegroundColor Green
    }
    catch {
      Write-Error "Failed to update registry setting $($setting.Name): $_"
    }
  }
}

# Function to remove registry keys
function Remove-RegistryKeys {
  param (
    [array]$keys
  )
  foreach ($key in $keys) {
    try {
      if (Test-Path $key) {
        Remove-Item -Path $key -Recurse -Force -ErrorAction Stop
        Write-Host "Removed registry key $key successfully." -ForegroundColor Green
      }
      else {
        Write-Host "Registry key $key does not exist." -ForegroundColor Yellow
      }
    }
    catch {
      Write-Error "Failed to remove registry key $($key): $_"
    }
  }
}

function Set-Wallpaper {
  param (
    [string]$ImagePath
  )

  if (Test-Path $ImagePath) {
    # Use the SystemParametersInfo function to change the wallpaper
    $null = Add-Type -TypeDefinition @"
    using System;
    using System.Runtime.InteropServices;
    public class Wallpaper {
      [DllImport("user32.dll", CharSet = CharSet.Auto)]
      public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
    }
"@
    $SPI_SETDESKWALLPAPER = 20
    $SPIF_UPDATEINIFILE = 0x01
    $SPIF_SENDCHANGE = 0x02
    [Wallpaper]::SystemParametersInfo($SPI_SETDESKWALLPAPER, 0, $ImagePath, $SPIF_UPDATEINIFILE -bor $SPIF_SENDCHANGE) | Out-Null
    Write-Host "Wallpaper changed to $ImagePath" -ForegroundColor Green
  }
  else {
    Write-Host "File not found: $ImagePath" -ForegroundColor Red
  }
}

# Function to apply theme and restart explorer
# function Set-Theme {
#   try {
#     Start-Process -FilePath "C:\Windows\Resources\Themes\dark.theme" -Wait -ErrorAction Stop
#     Stop-Process -Name SystemSettings -ErrorAction SilentlyContinue
#     Stop-Process -Name explorer -Force -ErrorAction Stop
#     Write-Host "Theme applied and explorer restarted." -ForegroundColor Green
#   }
#   catch {
#     Write-Error "Failed to apply theme: $_"
#   }
# }

# Function to create configuration file
function New-ConfigFile {
  $config = @"
<Configuration ID="35d3badb-d62d-4bf5-8438-0b3ee0766659">
  <Add OfficeClientEdition="64" Channel="Current">
    <Product ID="O365ProPlusRetail">
      <Language ID="MatchOS" />
      <ExcludeApp ID="Access" />
      <ExcludeApp ID="Groove" />
      <ExcludeApp ID="Lync" />
      <ExcludeApp ID="OneDrive" />
      <ExcludeApp ID="OneNote" />
      <ExcludeApp ID="Outlook" />
      <ExcludeApp ID="Publisher" />
      <ExcludeApp ID="Teams" />
      <ExcludeApp ID="Bing" />
    </Product>
  </Add>
  <Updates Enabled="TRUE" />
  <RemoveMSI />
</Configuration>
"@
  Set-Content -Path "$Env:TEMP\Configuration.xml" -Value $config
  Write-Host "Configuration file created successfully." -ForegroundColor Green
}

# Function to convert menu selection
function Convert-MenuSelection {
  param (
    [string]$selection
  )
  $selected = @()
  $parts = $selection -split ','
  foreach ($part in $parts) {
    if ($part -match "^(\d+)-(\d+)$") {
      $start = [int]$matches[1]
      $end = [int]$matches[2]
      $selected += $start..$end
    }
    elseif ($part -match "^\d+$") {
      $selected += [int]$part
    }
  }
  return ($selected | Sort-Object -Unique)
}

# Function to display menu options
function Show-Menu {
  Write-Host "=== Menu Options ==="
  Write-Host "0. Quit"
  for ($i = 0; $i -lt $menuOptions.Count; $i++) {
    Write-Host "Install $($i + 1). $($menuOptions[$i].Label)"
  }
  Write-Host "`nYou can select multiple options:"
  Write-Host "- Single numbers (e.g., 1,3,5)"
  Write-Host "- Ranges (e.g., 1-3)"
  Write-Host "- Combinations (e.g., 1-3,5)"
}

# Function to execute selected command
function Invoke-Command {
  param (
    [int]$option
  )
  $menuOption = $menuOptions[$option - 1]
  if ($menuOption.Url) {
    Write-Host "Downloading $($menuOption.Label)..." -ForegroundColor Yellow
    try {
      Invoke-WebRequest -Uri $menuOption.Url -OutFile "$Env:TEMP\wss\$($menuOption.FileName)" -ErrorAction Stop
      if ($menuOption.Label -eq "Microsoft Office 365") {
        New-ConfigFile
      }
      Write-Host "Installing $($menuOption.Label)..." -ForegroundColor Yellow
      Start-Process -FilePath "$Env:TEMP\wss\$($menuOption.FileName)" -ArgumentList $menuOption.Arguments -Wait -ErrorAction Stop
      Write-Host "Installation of $($menuOption.Label) has been completed." -ForegroundColor Green
    }
    catch {
      Write-Error "Failed to download or install $($menuOption.Label): $_"
    }
  }
  elseif ($menuOption.Script) {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Write-Host "Installing $($menuOption.Label)..." -ForegroundColor Yellow
    try {
      & $menuOption.Script
      Write-Host "Installation of $($menuOption.Label) has been completed." -ForegroundColor Green
    }
    catch {
      Write-Error "Failed to install $($menuOption.Label): $_"
    }
  }
}

# Main script execution
if (-not (Test-Admin)) {
  Write-Host "Script is not running with administrative privileges." -ForegroundColor Red
  Write-Host "Please run PowerShell as Administrator." -ForegroundColor Yellow
  return
}

$newComputerName = Read-Host "Please enter the new computer name (leave empty to do nothing)"
if (-not [string]::IsNullOrWhiteSpace($newComputerName)) {
  Set-ComputerName -newName $newComputerName
}
else {
  Write-Host "No new computer name entered. Exiting without changes." -ForegroundColor Yellow
}

$confirmRegistry = Read-Host "Do you want some basic customisation? (y/N)"
if ($confirmRegistry -match '^(yes|y)$') {
  $registrySettings = @(
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'EnableSnapAssistFlyout'; Value = 0; Type = 'DWord' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'EnableTaskGroups'; Value = 0; Type = 'DWord' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'EnableSnapBar'; Value = 0; Type = 'DWord' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'HideFileExt'; Value = 0; Type = 'DWord' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'Hidden'; Value = 1; Type = 'DWord' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'LaunchTo'; Value = 1; Type = 'DWord' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'MultiTaskingAltTabFilter'; Value = 3; Type = 'DWord' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'ShowTaskViewButton'; Value = 0; Type = 'DWord' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'SnapAssist'; Value = 0; Type = 'DWord' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'Start_AccountNotifications'; Value = 0; Type = 'DWord' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'Start_IrisRecommendations'; Value = 0; Type = 'DWord' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'Start_Layout'; Value = 1; Type = 'DWord' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'Start_TrackDocs'; Value = 0; Type = 'DWord' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'TaskbarAl'; Value = 0; Type = 'DWord' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings'; Name = 'TaskbarEndTask'; Value = 1; Type = 'DWord' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer'; Name = 'ShowCloudFilesInQuickAccess'; Value = 0; Type = 'DWord' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer'; Name = 'ShowFrequent'; Value = 0; Type = 'DWord' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer'; Name = 'ShowRecent'; Value = 0; Type = 'DWord' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize'; Name = 'Startupdelayinmsec'; Value = 0; Type = 'DWord' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'; Name = 'SearchboxTaskbarMode'; Value = 0; Type = 'DWord' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Start'; Name = 'ShowRecentList'; Value = 0; Type = 'DWord' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name = 'AppsUseLightTheme'; Value = 0; Type = 'DWord' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name = 'EnableTransparency'; Value = 0; Type = 'DWord' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name = 'SystemUsesLightTheme'; Value = 0; Type = 'DWord' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'UseCompactMode'; Value = 1; Type = 'DWord' },
    @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Power'; Name = 'HibernateEnabledDefault'; Value = 0; Type = 'DWord' },
    @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'; Name = 'ClearPageFileAtShutdown'; Value = 1; Type = 'DWord' },
    @{ Path = 'HKU:\.DEFAULT\Control Panel\Keyboard'; Name = 'InitialKeyboardIndicators'; Value = 2; Type = 'String' },
    @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection'; Name = 'AllowTelemetry'; Value = 0; Type = 'DWord' }
  )
  $keysToRemove = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}"
  )
  New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS
  Update-RegistrySettings -settings $registrySettings
  Remove-RegistryKeys -keys $keysToRemove
  # Set-Theme
  Set-Wallpaper -ImagePath "C:\Windows\Web\Wallpaper\Windows\img19.jpg"
  Add-ClearPSHistoryFunction
  sudo config --enable normal
  Write-Host "Please reboot your system to complete the changes." -ForegroundColor Yellow
}

# Create temporary directory
New-Item -ItemType Directory -Path "$env:TEMP\wss" -Force | Out-Null

# Define menu options
$menuOptions = @(
  @{ Label = "Cloudflare Warp"; Url = "https://1111-releases.cloudflareclient.com/win/latest"; FileName = "CloudflareWarp.msi"; Arguments = "/quiet" },
  @{ Label = "Firefox"; Url = "https://download.mozilla.org/?product=firefox-latest&os=win64"; FileName = "FirefoxSetup.exe"; Arguments = "/s" },
  @{ Label = "Google Chrome"; Url = "https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi"; FileName = "GoogleChrome.msi"; Arguments = "/quiet" },
  @{ Label = "Microsoft Office 365"; Url = "https://officecdn.microsoft.com/pr/wsus/setup.exe"; FileName = "setup.exe"; Arguments = "/configure $Env:TEMP\Configuration.xml" },
  @{ Label = "Telegram"; Url = "https://telegram.org/dl/desktop/win64"; FileName = "TelegramSetup.exe"; Arguments = "/verysilent" },
  @{ Label = "Visual Studio Code"; Url = "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64"; FileName = "VSCodeSetup.exe"; Arguments = "/verysilent /mergetasks=!runcode" },
  @{ Label = "Chocolatey"; Script = { Invoke-RestMethod -Uri https://community.chocolatey.org/install.ps1 | Invoke-Expression } },
  @{ Label = "Scoop"; Script = { Invoke-Expression "& {$(Invoke-RestMethod -Uri 'https://get.scoop.sh')} -RunAsAdmin" } }
)

# Main loop to show menu and process user input
do {
  Show-Menu
  $choice = Read-Host "`nEnter your selection"

  if ($choice -eq '0') {
    break
  }

  $selectedOptions = Convert-MenuSelection $choice
  $validOptions = $selectedOptions | Where-Object { $_ -ge 1 -and $_ -le $menuOptions.Count }

  if ($validOptions.Count -eq 0) {
    Write-Host "Invalid selection. Please try again." -ForegroundColor Red
    continue
  }

  foreach ($option in $validOptions) {
    Invoke-Command $option
  }

} while ($true)
