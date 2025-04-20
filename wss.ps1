$ProgressPreference = 'SilentlyContinue'

# Function to check administrative privileges
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
    Rename-Computer -NewName $newName -Force
    if ($?) {
      Write-Host "Computer name changed successfully to $newName." -ForegroundColor Yellow
    }
    else {
      Write-Host "Failed to change computer name." -ForegroundColor Red
    }
  }
  else {
    Write-Host "Invalid computer name. Please ensure it contains only letters, numbers, and hyphens, and is no longer than 15 characters." -ForegroundColor Red
  }
}

# Function to set registry settings
function Set-RegistrySettings {
  param (
    [array]$settings
  )
  foreach ($setting in $settings) {
    try {
      Set-ItemProperty -Path $setting.Path -Name $setting.Name -Value $setting.Value -Type $setting.Type -Force
    }
    catch {
      Write-Host "Failed to set registry value: $($setting.Path)\$($setting.Name)" -ForegroundColor Red
    }
  }
}

# Function to create configuration file for Office 365
function New-OfficeConfigFile {
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
  Set-Content -Path "$Env:TEMP\wss\Configuration.xml" -Value $config
}

# Function to install software
function Install-Software {
  param (
    [string]$url,
    [string]$fileName,
    [string]$arguments
  )
  try {
    Write-Host "Downloading $fileName..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $url -OutFile "$Env:TEMP\wss\$fileName"
    Write-Host "Installing $fileName..." -ForegroundColor Yellow
    Start-Process -FilePath "$Env:TEMP\wss\$fileName" -ArgumentList $arguments -Wait
    Write-Host "Installation of $fileName has been completed." -ForegroundColor Yellow
  }
  catch {
    Write-Host "Failed to install $fileName." -ForegroundColor Red
  }
}

# Function to install software from script
function Install-SoftwareFromScript {
  param (
    [scriptblock]$script
  )
  try {
    Write-Host "Installing software..." -ForegroundColor Yellow
    & $script
    Write-Host "Installation has been completed." -ForegroundColor Yellow
  }
  catch {
    Write-Host "Failed to install software." -ForegroundColor Red
  }
}

# Main script execution
if (-not (Test-Admin)) {
  Write-Host "Script is not running with administrative privileges." -ForegroundColor Red
  Write-Host "Please run PowerShell as Administrator." -ForegroundColor Yellow
  exit
}

# Prompt for new computer name
$newComputerName = Read-Host "Please enter the new computer name (leave empty to do nothing)"
if (-not [string]::IsNullOrWhiteSpace($newComputerName)) {
  Set-ComputerName -newName $newComputerName
}
else {
  Write-Host "No new computer name entered. Exiting without changes." -ForegroundColor Yellow
}

# Modify registry settings
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
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'Start_Layout'; Value = 1; Type = 'DWord' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'TaskbarAl'; Value = 0; Type = 'DWord' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings'; Name = 'TaskbarEndTask'; Value = 1; Type = 'DWord' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer'; Name = 'ShowCloudFilesInQuickAccess'; Value = 0; Type = 'DWord' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer'; Name = 'ShowFrequent'; Value = 0; Type = 'DWord' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer'; Name = 'ShowRecent'; Value = 0; Type = 'DWord' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize'; Name = 'Startupdelayinmsec'; Value = 0; Type = 'DWord' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'; Name = 'SearchboxTaskbarMode'; Value = 0; Type = 'DWord' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name = 'EnableTransparency'; Value = 0; Type = 'DWord' },
    @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'; Name = 'PromptOnSecureDesktop'; Value = 0; Type = 'DWord' },
    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'UseCompactMode'; Value = 1; Type = 'DWord' }
  )
  Set-RegistrySettings -settings $registrySettings

  # Apply theme and restart explorer
  Start-Process -FilePath "C:\Windows\Resources\Themes\dark.theme" -Wait
  Stop-Process -Name SystemSettings
  Stop-Process -Name explorer -Force
}

# Create temporary directory
New-Item -ItemType Directory -Path "$env:TEMP\wss" -Force | Out-Null

# Define menu options
$menuOptions = @(
  @{ Label = "Cloudflare Warp"; Url = "https://1111-releases.cloudflareclient.com/win/latest"; FileName = "CloudflareWarp.msi"; Arguments = "/quiet" },
  @{ Label = "Firefox"; Url = "https://download.mozilla.org/?product=firefox-latest&os=win64"; FileName = "FirefoxSetup.exe"; Arguments = "/s" },
  @{ Label = "Google Chrome"; Url = "https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi"; FileName = "GoogleChrome.msi"; Arguments = "/quiet" },
  @{ Label = "Microsoft Office 365"; Url = "https://officecdn.microsoft.com/pr/wsus/setup.exe"; FileName = "setup.exe"; Arguments = "/configure $Env:TEMP\wss\Configuration.xml" },
  @{ Label = "Telegram"; Url = "https://telegram.org/dl/desktop/win64"; FileName = "TelegramSetup.exe"; Arguments = "/verysilent" },
  @{ Label = "Visual Studio Code"; Url = "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64"; FileName = "VSCodeSetup.exe"; Arguments = "/verysilent /mergetasks=!runcode" },
  @{ Label = "Chocolatey"; Script = { Invoke-RestMethod -Uri https://community.chocolatey.org/install.ps1 | Invoke-Expression } },
  @{ Label = "Scoop"; Script = { Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression } }
)

# Function to parse menu selection
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
  Clear-Host
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

# Main loop to show menu and process user input
do {
  Show-Menu
  $choice = Read-Host "`nEnter your selection"
  if ($choice -eq '0') {
    break
  }
  $selectedOptions = Convert-MenuSelection -selection $choice
  $validOptions = $selectedOptions | Where-Object { $_ -ge 1 -and $_ -le $menuOptions.Count }
  if ($validOptions.Count -eq 0) {
    Write-Host "Invalid selection. Please try again." -ForegroundColor Red
    continue
  }
  foreach ($option in $validOptions) {
    $menuOption = $menuOptions[$option - 1]
    if ($menuOption.Url) {
      if ($menuOption.Label -eq "Microsoft Office 365") {
        New-OfficeConfigFile
      }
      Install-Software -url $menuOption.Url -fileName $menuOption.FileName -arguments $menuOption.Arguments
    }
    elseif ($menuOption.Script) {
      Install-SoftwareFromScript -script $menuOption.Script
    }
  }
} while ($true)
