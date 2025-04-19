$ProgressPreference = 'SilentlyContinue'

# Check if running with administrative privileges
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Script is not running with administrative privileges." -ForegroundColor Red
    Write-Host "Please run PowerShell as Administrator." -ForegroundColor Yellow
    return
}

# Prompt for new computer name
$newComputerName = Read-Host "Please enter the new computer name (leave empty to do nothing)"
if (-not [string]::IsNullOrWhiteSpace($newComputerName)) {
    if ($newComputerName -match '^[a-zA-Z0-9-]+$' -and $newComputerName.Length -le 15) {
        Rename-Computer -NewName $newComputerName -Force
        if ($?) {
            Write-Host "Computer name changed successfully to $newComputerName." -ForegroundColor Yellow
        } else {
            Write-Host "Failed to change computer name." -ForegroundColor Red
        }
    } else {
        Write-Host "Invalid computer name. Please ensure it contains only letters, numbers, and hyphens, and is no longer than 15 characters." -ForegroundColor Red
    }
} else {
    Write-Host "No new computer name entered. Exiting without changes." -ForegroundColor Yellow
}

# Modify registry settings
$confirmRegistry = Read-Host "Do you want some basic customisation? (y/N)"
if ($confirmRegistry -match '^(yes|y)$') {
    $registrySettings = @(
        @{  Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';
            Name = 'EnableSnapAssistFlyout';
            Value = 0;
            Type = 'DWord'
        },
        @{  Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';
            Name = 'EnableTaskGroups';
            Value = 0;
            Type = 'DWord'
        },
        @{  Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';
            Name = 'EnableSnapBar';
            Value = 0;
            Type = 'DWord'
        },
        @{  Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';
            Name = 'HideFileExt';
            Value = 0;
            Type = 'DWord'
        },
        @{  Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';
            Name = 'Hidden';
            Value = 1;
            Type = 'DWord'
        },
        @{  Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';
            Name = 'LaunchTo';
            Value = 1;
            Type = 'DWord'
        },
        @{  Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';
            Name = 'MultiTaskingAltTabFilter';
            Value = 3;
            Type = 'DWord'
        },
        @{  Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';
            Name = 'ShowTaskViewButton';
            Value = 0;
            Type = 'DWord'
        },
        @{  Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';
            Name = 'SnapAssist';
            Value = 0;
            Type = 'DWord'
        },
        @{  Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';
            Name = 'Start_Layout';
            Value = 1;
            Type = 'DWord'
        },
        @{  Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';
            Name = 'TaskbarAl';
            Value = 0;
            Type = 'DWord'
        },
        @{  Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings';
            Name = 'TaskbarEndTask';
            Value = 1;
            Type = 'DWord'
        },
        @{  Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer';
            Name = 'ShowCloudFilesInQuickAccess';
            Value = 0;
            Type = 'DWord'
        },
        @{  Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer';
            Name = 'ShowFrequent';
            Value = 0;
            Type = 'DWord'
        },
        @{  Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer';
            Name = 'ShowRecent';
            Value = 0;
            Type = 'DWord'
        },
        @{  Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize';
            Name = 'Startupdelayinmsec';
            Value = 0;
            Type = 'DWord'
        },
        @{  Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search';
            Name = 'SearchboxTaskbarMode';
            Value = 0;
            Type = 'DWord'
        },
        @{  Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize';
            Name = 'EnableTransparency';
            Value = 0;
            Type = 'DWord'
        },
        @{  Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System';
            Name = 'PromptOnSecureDesktop';
            Value = 0;
            Type = 'DWord'
        },
        @{  Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';
            Name = 'UseCompactMode';
            Value = 1;
            Type = 'DWord'
        }
    )

    foreach ($setting in $registrySettings) {
        Set-ItemProperty -Path $setting.Path -Name $setting.Name -Value $setting.Value -Type $setting.Type -Force
    }
    
    # Apply theme and restart explorer
    Start-Process -FilePath "C:\Windows\Resources\Themes\dark.theme" -Wait
    Stop-Process -Name SystemSettings
    Stop-Process -Name explorer -Force
}



# Create temporary directory
$tempDir = New-Item -ItemType Directory -Path "$env:TEMP\wss" -Force | Out-Null

# Function to create configuration file
function Create-ConfigFile {
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
}

# Define menu options
$menuOptions = @(
    @{  Label = "Cloudflare Warp";
        Url = "https://1111-releases.cloudflareclient.com/win/latest";
        FileName = "CloudflareWarp.msi";
        Arguments = "/quiet"
    },
    @{  Label = "Firefox";
        Url = "https://download.mozilla.org/?product=firefox-latest&os=win64";
        FileName = "FirefoxSetup.exe";
        Arguments = "/s"
    },
    @{  Label = "Google Chrome";
        Url = "https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi";
        FileName = "GoogleChrome.msi";
        Arguments = "/quiet"
    },
    @{  Label = "Microsoft Office 365";
        Url = "https://officecdn.microsoft.com/pr/wsus/setup.exe";
        FileName = "setup.exe";
        Arguments = "/configure $Env:TEMP\Configuration.xml"
    },
    @{  Label = "Telegram";
        Url = "https://telegram.org/dl/desktop/win64";
        FileName = "TelegramSetup.exe";
        Arguments = "/verysilent"
    },
    @{  Label = "Visual Studio Code";
        Url = "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64";
        FileName = "VSCodeSetup.exe";
        Arguments = "/verysilent /mergetasks=!runcode"
    },
    @{  Label = "Chocolatey";
        Script = { Invoke-RestMethod -Uri https://community.chocolatey.org/install.ps1 | Invoke-Expression }
    },
    @{  Label = "Scoop";
        Script = { Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression }
    }
)

# Function to parse menu selection
function Parse-MenuSelection {
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
        } elseif ($part -match "^\d+$") {
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

# Function to execute selected command
function Execute-Command {
    param (
        [int]$option
    )

    $menuOption = $menuOptions[$option - 1]
    if ($menuOption.Url) {
        Write-Host "Downloading $($menuOption.Label)..." -ForegroundColor Yellow
        Invoke-WebRequest -Uri $menuOption.Url -OutFile "$Env:TEMP\wss\$($menuOption.FileName)"
        Write-Host "Installing $($menuOption.Label)..." -ForegroundColor Yellow
        Start-Process -FilePath "$Env:TEMP\wss\$($menuOption.FileName)" -ArgumentList $menuOption.Arguments -Wait
        Write-Host "Installation of $($menuOption.Label) has been completed.." -ForegroundColor Yellow
    }
    elseif ($menuOption.Script) {
        Write-Host "Installing $($menuOption.Label)..." -ForegroundColor Yellow
        & $menuOption.Script
        Write-Host "Installation of $($menuOption.Label) has been completed.." -ForegroundColor Yellow
    }
}


# Main loop to show menu and process user input
do {
    Show-Menu
    $choice = Read-Host "`nEnter your selection"

    if ($choice -eq '0') {
        break
    }

    $selectedOptions = Parse-MenuSelection $choice
    $validOptions = $selectedOptions | Where-Object { $_ -ge 1 -and $_ -le $menuOptions.Count }

    if ($validOptions.Count -eq 0) {
        Write-Host "Invalid selection. Please try again." -ForegroundColor Red
        continue
    }

    foreach ($option in $validOptions) {
        Execute-Command $option
    }

} while ($true)
