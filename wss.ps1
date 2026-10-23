$ProgressPreference = "SilentlyContinue"

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())

if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Script is not running with administrative privileges." -ForegroundColor Red
    Write-Host "Please run PowerShell as Administrator." -ForegroundColor Yellow
    return
}

$newComputerName = Read-Host "Please enter the new computer name (leave empty to do nothing)"
if ([string]::IsNullOrWhiteSpace($newComputerName)) {
    Write-Host "No new computer name entered. Exiting without changes." -ForegroundColor Yellow
}
else {
    Rename-Computer -NewName $newComputerName -Force -ErrorAction SilentlyContinue
}

# Function to add custom functions to the PowerShell profile
function Add-ProfileFunction {
    param(
        [Parameter(Mandatory)]
        [string]$FunctionCode,
        
        [Parameter(Mandatory)]
        [string]$FunctionName
    )

    if (-not (Test-Path -LiteralPath $PROFILE)) {
        New-Item -Path $PROFILE -ItemType File -Force | Out-Null
    }

    if (-not (Get-Content -LiteralPath $PROFILE | Select-String -Pattern "function $FunctionName")) {
        Add-Content -LiteralPath $PROFILE -Value $FunctionCode
        Write-Host "$FunctionName function added to profile."
    }
    else {
        Write-Host "$FunctionName function already exists in profile."
    }
}

Add-ProfileFunction -FunctionName "Clear-PSHistory" -FunctionCode @'
function Clear-PSHistory {
    $historyPath = (Get-PSReadLineOption).HistorySavePath

    if (Test-Path -LiteralPath $historyPath) {
        Remove-Item -LiteralPath $historyPath -Force
        Write-Host "PowerShell history cleared."
    }
    else {
        Write-Host "No history file found at $historyPath."
    }
}
'@

Add-ProfileFunction -FunctionName "Grant-UserAccess" -FunctionCode @'
function Grant-UserAccess {
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$FilePath
    )

    $usersAccount = [System.Security.Principal.NTAccount]"BUILTIN\Users"
    $administratorsAccount = [System.Security.Principal.NTAccount]"BUILTIN\Administrators"

    $FilePath | ForEach-Object {
        $path = $_

        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            Write-Error "The file does not exist: $path"
            return
        }

        try {
            $fileAcl = Get-Acl -LiteralPath $path
            $fileAcl.SetOwner($usersAccount)

            $usersPermission = [System.Security.AccessControl.FileSystemAccessRule]::new(
                $usersAccount, "FullControl", "Allow"
            )
            $administratorsPermission = [System.Security.AccessControl.FileSystemAccessRule]::new(
                $administratorsAccount, "FullControl", "Allow"
            )

            $fileAcl.SetAccessRule($usersPermission)
            $fileAcl.SetAccessRule($administratorsPermission)

            Set-Acl -LiteralPath $path -AclObject $fileAcl -ErrorAction Stop
        }
        catch {
            Write-Error "Could not update "$path": $_"
        }
    }
}
'@

. $PROFILE

# Function to make MS Edge as Uninstallable
function Set-EdgeAsUninstallable {
    $path = "C:\Windows\System32\IntegratedServicesRegionPolicySet.json"
    $json = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    $policy = $json.policies | Where-Object guid -eq "{1bca278a-5d11-4acf-ad2f-f9ab6d7f93a6}"
    $regions = [System.Collections.Generic.List[string]]$policy.conditions.region.enabled
    $geoId = (Get-WinHomeLocation).GeoID
    $region = [System.Globalization.CultureInfo]::GetCultures("SpecificCultures") |
        ForEach-Object {
            [System.Globalization.RegionInfo]::new($_.Name)
        } |
        Where-Object GeoId -eq $geoId |
        Select-Object -First 1
    $regionCode = $region.TwoLetterISORegionName
    
    if ($regions -notcontains $regionCode) {
        $regions.Add($regionCode)
        $regions.Sort()
    }
    
    $policy.conditions.region.enabled = $regions.ToArray()
    $json | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $path
}

# Function to set registry settings
function Set-RegistrySettings {
    param (
        [Parameter(Mandatory)]
        [array]$keys
    )
    foreach ($key in $keys) {
        if (-NOT (Test-Path $key.Path)) {
            New-Item -Path $key.Path -Force | Out-Null
        }
        New-ItemProperty `
            -Path $key.Path `
            -Name $key.Name `
            -Value $key.Value `
            -Type $key.Type `
            -Force -ErrorAction SilentlyContinue | Out-Null
        Write-Host "Updated registry setting $($key.Name) successfully." -ForegroundColor Green
    }
}

# Function to remove registry keys
function Remove-RegistryKeys {
    param (
        [Parameter(Mandatory)]
        [array]$keys
    )
    foreach ($key in $keys) {
        if (Test-Path $key) {
            Remove-Item -Path $key -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Removed registry key $key successfully." -ForegroundColor Green
        }
        else {
            Write-Host "Registry key $key does not exist." -ForegroundColor Yellow
        }
    }
}

$confirmRegistry = Read-Host "Do you want some basic customisation? (y/N)"
if ($confirmRegistry -match "^(yes|y)$") {
    $keysToSet = @(
        @{ Path = "HKCU:\AppEvents\Schemes"; Name = "(Default)"; Value = ".None"; Type = "String" },
        @{ Path = "HKCU:\Control Panel\Desktop"; Name = "DragFullWindows"; Value = 1; Type = "String" },
        @{ Path = "HKCU:\Control Panel\Desktop"; Name = "FontSmoothing"; Value = 2; Type = "String" },
        @{ Path = "HKCU:\Control Panel\Desktop"; Name = "UserPreferencesMask"; Value = [byte[]](0x90, 0x12, 0x03, 0x80, 0x10, 0x00, 0x00, 0x00); Type = "Binary" },
        @{ Path = "HKCU:\Control Panel\International\User Profile"; Name = "HttpAcceptLanguageOptOut"; Value = 1; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Clipboard"; Name = "EnableClipboardHistory"; Value = 1; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\InputPersonalization"; Name = "RestrictImplicitInkCollection"; Value = 1; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\InputPersonalization"; Name = "RestrictImplicitTextCollection"; Value = 1; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\InputPersonalization\TrainedDataStore"; Name = "HarvestContacts"; Value = 0; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Personalization\Settings"; Name = "AcceptedPrivacyPolicy"; Value = 0; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Siuf\Rules"; Name = "NumberOfSIUFInPeriod"; Value = 0; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\CDP"; Name = "EnablePromotionalAppsForShare"; Value = 0; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\CPSS\Store\InkingAndTypingPersonalization"; Name = "Value"; Value = 0; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "RotatingLockScreenEnabled"; Value = 0; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "RotatingLockScreenOverlayEnabled"; Value = 0; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SubscribedContent-338389Enabled"; Value = 0; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SubscribedContent-338393Enabled"; Value = 0; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SubscribedContent-353694Enabled"; Value = 0; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SubscribedContent-353696Enabled"; Value = 0; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer"; Name = "ShowCloudFilesInQuickAccess"; Value = 0; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer"; Name = "ShowFrequent"; Value = 0; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer"; Name = "ShowRecent"; Value = 0; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "EnableSnapAssistFlyout"; Value = 0; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "EnableSnapBar"; Value = 0; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "EnableTaskGroups"; Value = 0; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "Hidden"; Value = 1; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "HideFileExt"; Value = 0; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "IconsOnly"; Value = 0; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "LaunchTo"; Value = 1; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "ListviewAlphaSelect"; Value = 1; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "ListviewShadow"; Value = 0; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "MultiTaskingAltTabFilter"; Value = 3; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "ShowTaskViewButton"; Value = 0; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "SnapAssist"; Value = 0; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "Start_AccountNotifications"; Value = 0; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "Start_IrisRecommendations"; Value = 0; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "Start_Layout"; Value = 1; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "Start_TrackDocs"; Value = 0; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "Start_TrackProgs"; Value = 0; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "TaskbarAl"; Value = 0; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "TaskbarAnimations"; Value = 0; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "UseCompactMode"; Value = 1; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings"; Name = "TaskbarEndTask"; Value = 1; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers"; Name = "DisableAutoplay"; Value = 1; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize"; Name = "Startupdelayinmsec"; Value = 0; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"; Name = "VisualFXSetting"; Value = 3; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"; Name = "BingSearchEnabled"; Value = 0; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"; Name = "SearchboxTaskbarMode"; Value = 0; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings"; Name = "IsAADCloudSearchEnabled"; Value = 0; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings"; Name = "IsDeviceSearchHistoryEnabled"; Value = 0; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings"; Name = "IsDynamicSearchBoxEnabled"; Value = 0; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings"; Name = "IsMSACloudSearchEnabled"; Value = 0; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings"; Name = "IsStoreSuggestionsEnabled"; Value = 0; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings"; Name = "IsWebSuggestionsEnabled"; Value = 0; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings"; Name = "SafeSearchMode"; Value = 0; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Start"; Name = "AllAppsViewMode"; Value = 2; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Start"; Name = "ShowPinnedSection"; Value = 0; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Start"; Name = "ShowRecentList"; Value = 0; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Start"; Name = "ShowRecentSection"; Value = 0; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Start"; Name = "ShowSuggestedFiles"; Value = 0; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\SystemSettings\AccountNotifications"; Name = "EnableAccountNotifications"; Value = 0; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"; Name = "EnableTransparency"; Value = 0; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement"; Name = "ScoobeSystemSettingEnabled"; Value = 0; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\DWM"; Name = "AlwaysHibernateThumbnails"; Value = 0; Type = "DWord" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\DWM"; Name = "EnableAeroPeek"; Value = 0; Type = "DWord" },
        @{ Path = "HKCU:\Software\Policies\Microsoft\Windows\CloudContent"; Name = "DisableWindowsSpotlightFeatures"; Value = 1; Type = "DWord" },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"; Name = "SettingsPageVisibility"; Value = "hide:home"; Type = "String" },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"; Name = "DisableStartupSound"; Value = 1; Type = "DWord" },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"; Name = "NoConnectedUser"; Value = 3; Type = "DWord" },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"; Name = "verbosestatus"; Value = 1; Type = "DWord" },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\SystemRestore"; Name = "DisableSR"; Value = 1; Type = "DWord" },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"; Name = "AllowTelemetry"; Value = 0; Type = "DWord" },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"; Name = "EnableSmartScreen"; Value = 0; Type = "DWord" },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"; Name = "PublishUserActivities"; Value = 0; Type = "DWord" },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WTDS\Components"; Name = "CaptureThreatWindow"; Value = 0; Type = "DWord" },
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy"; Name = "VerifiedAndReputablePolicyState"; Value = 1; Type = "DWord" },
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name = "ClearPageFileAtShutdown"; Value = 1; Type = "DWord" }
    )

    $keysToRemove = @(
        "HKCU:\Software\Microsoft\Siuf\Rules\PeriodInNanoSeconds",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}"
    )
    
    Set-RegistrySettings -keys $keysToSet
    Remove-RegistryKeys -keys $keysToRemove

    # Disable reserved storage
    try { Set-WindowsReservedStorageState -State Disabled }
    catch { }

    # Delete all restore points on all drives
    vssadmin delete shadows /all /quiet

    # Disable hibernation
    powercfg.exe /hibernate off

    Stop-Service -Name DiagTrack -Force
    Set-Service -Name DiagTrack -StartupType Manual
  
    Grant-UserAccess -FilePath "C:\Windows\System32\IntegratedServicesRegionPolicySet.json"
    Set-EdgeAsUninstallable
    
    if (Get-Command sudo.exe -ErrorAction SilentlyContinue) {
        sudo.exe config --enable normal
    } else {
        Write-Error "sudo.exe was not found. Windows Sudo requires Windows 11, version 24H2 or later."
    }
}

# Remove all removable packages
function Remove-RemovableAppxPackages {
    $Exceptions = "Extension|NET|Photos|Runtime|ScreenSketch|Xaml|VCLibs|WindowsCalculator|WindowsCamera|WindowsNotepad|WindowsStore"

    Get-AppxPackage |
        Where-Object {
            $_.NonRemovable -eq $false -and
            $_.PackageFullName -notmatch $Exceptions
        } |
        ForEach-Object {
            Remove-AppxPackage -Package $_.PackageFullName
        }
}

# Remove all removable optional features
function Remove-RemovableWindowsCapabilities {
    Get-WindowsCapability -Online |
        Where-Object { $_.State -eq "Installed" } |
        ForEach-Object {
            $name = $_.Name
            try {
                Remove-WindowsCapability -Online -Name $name
                Write-Host "Successfully removed: $name"
            }
            catch {
                Write-Host "`nSkipped removal: $name"
            }
        }
}

# Disable all enabled optional features
function Remove-RemovableOptionalFeatures {
    Get-WindowsOptionalFeature -Online |
        Where-Object { $_.State -eq "Enabled" } |
        ForEach-Object {
            $name = $_.FeatureName
            try {
                Disable-WindowsOptionalFeature -Online -NoRestart -FeatureName $name
                Write-Host "Successfully disabled: $name"
            }
            catch {
                Write-Host "`nSkipped disabling: $name"
            }
        }
}

# Clear Windows Update history
function Clear-WindowsUpdateHistory {
    $path = "C:\ProgramData\USOPrivate\UpdateStore"

    Stop-Service -Name UsoSvc, wuauserv -Force -ErrorAction SilentlyContinue

    # Grant-UserAccess must be defined or available in your environment.
    Grant-UserAccess -FilePath "$path\store.db", "$path\store.bak" `
        -ErrorAction SilentlyContinue

    Remove-Item -Path @(
        "$path\store.db",
        "$path\store.bak",
        "C:\Windows\SoftwareDistribution\DataStore\Logs\edb.log"
    ) -ErrorAction SilentlyContinue

    Start-Service -Name UsoSvc, wuauserv -ErrorAction SilentlyContinue
}

# Create temporary directory for installers
$InstallerDirectory = Join-Path $env:TEMP "wss"
New-Item -ItemType Directory -Path $InstallerDirectory -Force | Out-Null

# Shared download-and-install function
function Install-DownloadedApplication {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Url,

        [Parameter(Mandatory)]
        [string]$FileName,

        [string]$Arguments
    )

    $output = Join-Path $InstallerDirectory $FileName

    try {
        Write-Host "Downloading $Name..."
        Invoke-WebRequest -Uri $Url -OutFile $output -ErrorAction Stop

        Write-Host "Installing $Name..."
        $process = Start-Process -FilePath $output -ArgumentList $Arguments -Wait -PassThru

        if ($process.ExitCode -eq 0) {
            Write-Host "$Name installed successfully."
        }
        else {
            Write-Warning "$Name installer exited with code $($process.ExitCode)."
        }
    }
    catch {
        Write-Error "Failed to download or install $Name`: $_"
    }
}

function Install-CloudflareWarp {
    Install-DownloadedApplication `
        -Name "Cloudflare WARP" `
        -Url "https://1111-releases.cloudflareclient.com/win/latest" `
        -FileName "CloudflareWarp.msi" `
        -Arguments "/quiet"
}

function Install-MozillaFirefox {
    Install-DownloadedApplication `
        -Name "Mozilla Firefox" `
        -Url "https://download.mozilla.org/?product=firefox-msi-latest-ssl&os=win64&lang=en-GB" `
        -FileName "MozillaFirefox.msi" `
        -Arguments "/quiet"
}

function Install-GoogleChrome {
    Install-DownloadedApplication `
        -Name "Google Chrome" `
        -Url "https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi" `
        -FileName "GoogleChrome.msi" `
        -Arguments "/quiet"
}

function Install-MicrosoftOffice365 {
   Set-Content -Path "$Env:TEMP\Configuration.xml" -Value @'
<Configuration ID="03cdf0e8-2737-4d2f-b1b8-d50a6103046d">
  <Add OfficeClientEdition="64" Channel="Current">
    <Product ID="O365ProPlusRetail">
      <Language ID="en-gb" />
      <ExcludeApp ID="Access" />
      <ExcludeApp ID="Groove" />
      <ExcludeApp ID="Lync" />
      <ExcludeApp ID="OneDrive" />
      <ExcludeApp ID="OneNote" />
      <ExcludeApp ID="Outlook" />
      <ExcludeApp ID="OutlookForWindows" />
      <ExcludeApp ID="Publisher" />
      <ExcludeApp ID="Teams" />
    </Product>
  </Add>
  <Property Name="SharedComputerLicensing" Value="0" />
  <Property Name="FORCEAPPSHUTDOWN" Value="TRUE" />
  <Property Name="DeviceBasedLicensing" Value="0" />
  <Property Name="SCLCacheOverride" Value="0" />
  <Updates Enabled="TRUE" />
  <RemoveMSI />
  <Display Level="Full" AcceptEULA="TRUE" />
</Configuration>
'@
    Install-DownloadedApplication `
        -Name "Microsoft 365" `
        -Url "https://officecdn.microsoft.com/pr/wsus/setup.exe" `
        -FileName "OfficeSetup.exe" `
        -Arguments "/configure $Env:TEMP\Configuration.xml"
}

function Install-TelegramDesktop {
    Install-DownloadedApplication `
        -Name "Telegram Desktop" `
        -Url "https://telegram.org/dl/desktop/win64" `
        -FileName "TelegramDesktop.exe" `
        -Arguments "/verysilent"
}

function Install-VisualStudioCode {
    Install-DownloadedApplication `
        -Name "Visual Studio Code" `
        -Url "https://code.visualstudio.com/?build=stable&dv=win64" `
        -FileName "VSCodeSetup.exe" `
        -Arguments "/verysilent /mergetasks=!runcode"
}

$menuOptions = @{
    "1"  = @{ Name = "Install Cloudflare WARP";      Action = { Install-CloudflareWarp } }
    "2"  = @{ Name = "Install Google Chrome";        Action = { Install-GoogleChrome } }
    "3"  = @{ Name = "Install Microsoft Office 365"; Action = { Install-MicrosoftOffice365 } }
    "4"  = @{ Name = "Install Mozilla Firefox";      Action = { Install-MozillaFirefox } }
    "5"  = @{ Name = "Install Telegram Desktop";     Action = { Install-TelegramDesktop } }
    "6"  = @{ Name = "Install Visual Studio Code";   Action = { Install-VisualStudioCode } }
    "7"  = @{ Name = "Remove Appx packages";         Action = { Remove-RemovableAppxPackages } }
    "8"  = @{ Name = "Remove Optional Features";     Action = { Remove-RemovableOptionalFeatures } }
    "9"  = @{ Name = "Disable Windows features";     Action = { Disable-WindowsFeatures } }
    "10" = @{ Name = "Clear Windows Update history"; Action = { Clear-WindowsUpdateHistory } }
}

do {
    Write-Host ""
    Write-Host "Windows Setup Menu" -ForegroundColor Cyan
    Write-Host "-------------------`n" -ForegroundColor Cyan

    foreach ($key in ($menuOptions.Keys | Sort-Object { [int]$_ })) {
        Write-Host "$key. $($menuOptions[$key].Name)"
    }

    Write-Host ""
    $choices = Read-Host "Choose option(s), separated by commas (leave empty to do nothing)"

    if ([string]::IsNullOrWhiteSpace($choices)) {
        break
    }

    $selectedChoices = $choices -split '\s*,\s*'

    $orderedChoices = @($selectedChoices | Where-Object { $_ -ne "3" })

    if ($selectedChoices -contains "3") {
        $orderedChoices += "3"
    }

    foreach ($choice in $orderedChoices) {
        if ($menuOptions.ContainsKey($choice)) {
            & $menuOptions[$choice].Action
        }
        else {
            Write-Host "Invalid choice." -ForegroundColor Yellow
        }
    }
} while ($true)
