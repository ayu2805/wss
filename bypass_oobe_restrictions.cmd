@echo off
set "KEY=HKLM\Software\Microsoft\Windows\CurrentVersion\OOBE"
reg add "%KEY%" /v HideOnlineAccountScreens /t REG_DWORD /d 1 /f
reg add "%KEY%" /v HideWirelessSetupInOOBE /t REG_DWORD /d 1 /f

echo Registry values added successfully
pause
