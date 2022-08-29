## PROOF of CONCEPT ONLY

This code is a proof of concept to show how data can be pulled from M365 Advanced Hunting API GCC to Azure Sentinel.  It is **NOT** prodcution ready code.  Author assumes no responsibility for its use nor implies any warranty.

# Setup

## AAD Application Setup

Follow steps here to setup an Azure AD Application with API permissions <https://github.com/Azure/Azure-Sentinel/tree/master/DataConnectors/O365%20Data#onboarding-azure-sentinel>

## Endpoints

This script was written for GCC endpoints.  If you need M365 Public, GCC-H or DoD, please change the following in `run.ps1`:

``` powershell
#$resourceAppIdUri = 'https://api-gcc.security.microsoft.us'
#$oAuthUri = "https://login.microsoftonline.com/$tenantId/oauth2/token"
```

GCC-H and DoD endpoint urls can be found here: <https://docs.microsoft.com/en-us/microsoft-365/security/defender/usgov?view=o365-worldwide>

## Function App Config

  1. Create an Azure AD App, grant permissions
  2. Install Bicep (see installBicep.ps1 in this repo)
  3. Set parameters in parameters.json file
  4. Run deployApp.ps1

### 1. Create Azure AD App

Directions can be found here: <https://github.com/Azure/Azure-Sentinel/tree/master/DataConnectors/O365%20Data#onboarding-azure-sentinel>

### 2. Bicep Install

``` powershell
# Create the install folder
$installPath = "$env:USERPROFILE\.bicep"
$installDir = New-Item -ItemType Directory -Path $installPath -Force
$installDir.Attributes += 'Hidden'
# Fetch the latest Bicep CLI binary
(New-Object Net.WebClient).DownloadFile("https://github.com/Azure/bicep/releases/latest/download/bicep-win-x64.exe", "$installPath\bicep.exe")
# Add bicep to your PATH
$currentPath = (Get-Item -path "HKCU:\Environment" ).GetValue('Path', '', 'DoNotExpandEnvironmentNames')
if (-not $currentPath.Contains("%USERPROFILE%\.bicep")) { setx PATH ($currentPath + ";%USERPROFILE%\.bicep") }
if (-not $env:path.Contains($installPath)) { $env:path += ";$installPath" }
# Verify you can now access the 'bicep' command.
bicep --help
# Done!
```
### 3 Install Azure Storage Module
```
Install-Module AzTable
```
