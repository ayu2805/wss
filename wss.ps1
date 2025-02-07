$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Script is not running with administrative privileges." -ForegroundColor Red
    Write-Host "Please run PowerShell as Administrator." -ForegroundColor Yellow
    Write-Host "Press any key to close this window..."
    $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    exit
}

$setupPath = "$HOME\Downloads\Windows Setup"
New-Item -ItemType Directory -Path $setupPath -Force
Set-Location $setupPath

$filePath = "Configuration.xml"
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

if (-not (Test-Path -Path $filePath)) {
    $config | Out-File -FilePath $filePath -Force
}

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
        }
        elseif ($part -match "^\d+$") {
            $selected += [int]$part
        }
    }
    
    return ($selected | Sort-Object -Unique)
}

function Show-Menu {
    Clear-Host
    Write-Host "=== Menu Options ==="
    Write-Host "0. Quit"
    Write-Host "1. Install Cloudflare Warp"
    Write-Host "2. Install Firefox"
    Write-Host "3. Install Google Chrome"
    Write-Host "4. Install Microsoft Office 365"
    Write-Host "5. Install Telegram"
    Write-Host "6. Install Visual Studio Code"
    Write-Host "`nYou can select multiple options:"
    Write-Host "- Single numbers (e.g., 1,3,5)"
    Write-Host "- Ranges (e.g., 1-3)"
    Write-Host "- Combinations (e.g., 1-3,5)"
}

function Execute-Command {
    param (
        [int]$option
    )
    
    switch ($option) {
        1 { Start-Process -FilePath "cmd.exe" -ArgumentList '/c curl -#Lo CloudflareWarp.msi "https://1111-releases.cloudflareclient.com/win/latest" && msiexec /i CloudflareWarp.msi' }
        2 { Start-Process -FilePath "cmd.exe" -ArgumentList '/c curl -#Lo FirefoxSetup.exe "https://download.mozilla.org/?product=firefox-latest&os=win64" && FirefoxSetup.exe' }
        3 { Start-Process -FilePath "cmd.exe" -ArgumentList '/c curl -#Lo GoogleChrome.msi "https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi" && msiexec /i GoogleChrome.msi' }
        4 { Start-Process -FilePath "cmd.exe" -ArgumentList '/c curl -#LO "https://officecdn.microsoft.com/pr/wsus/setup.exe" && setup.exe /configure Configuration.xml' }
        5 { Start-Process -FilePath "cmd.exe" -ArgumentList '/c curl -#Lo TelegramSetup.exe "https://telegram.org/dl/desktop/win64" && TelegramSetup.exe' }
        6 { Start-Process -FilePath "cmd.exe" -ArgumentList '/c curl -#Lo VSCodeSetup.exe "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64" && VSCodeSetup.exe' }
    }
}

do {
    Show-Menu
    $choice = Read-Host "`nEnter your selection"
    
    if ($choice -eq '0') {
        break
    }
    
    $selectedOptions = Parse-MenuSelection $choice
    $validOptions = $selectedOptions | Where-Object { $_ -ge 1 -and $_ -le 6 }
    
    if ($validOptions.Count -eq 0) {
        Write-Host "Invalid selection. Please try again."
        continue
    }
    
    foreach ($option in $validOptions) {
        Execute-Command $option
    }

} while ($true)

Write-Host 'You can now manually delete the "Windows Setup" inside Downloads directory'
