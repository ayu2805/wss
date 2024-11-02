# WSS
Windows Setup Script

> **Warning**: Always be careful when running scripts from the Internet.

**Note:** This script is only meant for latest Windows 10 and 11

#### To run this script run this in Powershell as Administrator:
```
irm https://raw.githubusercontent.com/ayu2805/wss/main/wss.ps1 | iex
```

#### To install chocolatey run this command in Powershell as Administrator:
```
Set-ExecutionPolicy RemoteSigned; irm https://community.chocolatey.org/install.ps1 | iex
```

#### To install scoop run this command in Powershell as Administrator:
```
Set-ExecutionPolicy RemoteSigned; iex "& {$(irm get.scoop.sh)} -RunAsAdmin"
```
