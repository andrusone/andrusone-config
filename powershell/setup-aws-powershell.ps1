<#
aws_bootstrap.ps1

DESCRIPTION:
    Bootstraps a clean, professional AWS PowerShell environment for corporate laptops.

VALUE:
    - Fast, minimal PowerShell profile
    - AWS CLI ready
    - Oh My Posh prompt with AWS profile awareness
    - Linux-style PowerShell functions
    - Environment-aware login reminders (dev / qa / prod)

AUDIENCE:
    AWS users in corporate environments using manual keys or AWS SSO.

REQUIREMENTS:
    - PowerShell 5+
    - Java JDK 17+ for Okta SSO (optional)
    - JetBrainsMono Nerd Font: https://www.nerdfonts.com/font-downloads
    - Solarized Dark High Contrast Windows Terminal Theme

USAGE:
    powershell -ExecutionPolicy Bypass -File .\aws_bootstrap.ps1
#>

$baseDir = "$env:USERPROFILE\aws-tools"
$awsCliInstaller = "$baseDir\AWSCLIV2.msi"
$awsCliUrl = "https://awscli.amazonaws.com/AWSCLIV2.msi"
$ompExe = "$baseDir\oh-my-posh.exe"
$ompTheme = "$baseDir\solarized_dark.omp.json"
$ompThemeUrl = "https://ohmyposh.dev/themes/solarized_dark.omp.json"
$profileScript = $PROFILE

New-Item -ItemType Directory -Force -Path $baseDir | Out-Null

function Safe-Download {
    param(
        [string]$Url,
        [string]$OutFile
    )
    try {
        Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing -ErrorAction Stop
    } catch {
        Write-Warning "Invoke-WebRequest failed for $Url, trying curl.exe..."
        try {
            curl.exe -L $Url -o $OutFile
        } catch {
            Write-Error "Both download methods failed. Download manually from: $Url"
        }
    }
}

if ((Get-ExecutionPolicy -Scope CurrentUser) -eq "Restricted") {
    try { Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force }
    catch { Write-Warning "Set execution policy manually: Set-ExecutionPolicy RemoteSigned -Scope CurrentUser" }
}

if (-not (Get-Command aws.exe -ErrorAction SilentlyContinue)) {
    Safe-Download -Url $awsCliUrl -OutFile $awsCliInstaller
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$awsCliInstaller`" /quiet" -Wait
}

if (-not (Test-Path $ompExe)) {
    Safe-Download -Url "https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/posh-windows-amd64.exe" -OutFile "$baseDir\omp-temp.exe"
    Rename-Item -Path "$baseDir\omp-temp.exe" -NewName "oh-my-posh.exe" -Force
}

# Custom OMP theme with AWS segment
$ompThemeContent = @'
{
  "$schema": "https://ohmyposh.dev/config.schema.json",
  "blocks": [
    {
      "type": "prompt",
      "alignment": "left",
      "segments": [
        { "type": "path" },
        { "type": "aws" },
        { "type": "git" }
      ]
    }
  ]
}
'@

if (-not (Test-Path $ompTheme)) {
    $ompThemeContent | Out-File -Encoding utf8 -FilePath $ompTheme
}

if (-not (Test-Path $profileScript)) {
    New-Item -ItemType File -Force -Path $profileScript | Out-Null
    $content = ""
} else {
    $content = Get-Content $profileScript -Raw
}

function Add-ProfileLine {
    param ([string]$line)
    if ($content -notmatch [regex]::Escape($line)) {
        Add-Content $profileScript "`n$line"
    }
}

Add-ProfileLine '$env:PATH += ";C:\Users\aa5hdzz\aws-tools\AWSCLIV2"'
Add-ProfileLine '$env:POSH_THEMES_PATH = "$env:USERPROFILE\aws-tools"'
Add-ProfileLine '& "$env:USERPROFILE\aws-tools\oh-my-posh.exe" init pwsh --config "$env:POSH_THEMES_PATH\solarized_dark.omp.json" | Invoke-Expression'

Add-ProfileLine 'Function ll { Get-ChildItem -Force | Format-Table -AutoSize }'
Add-ProfileLine 'Function grep { Select-String @args }'
Add-ProfileLine 'Function touch { New-Item -ItemType File -Name $args }'
Add-ProfileLine 'Function rm { Remove-Item -Force -Recurse $args }'
Add-ProfileLine 'Function cp { Copy-Item -Verbose $args }'
Add-ProfileLine 'Function mv { Move-Item -Verbose $args }'
Add-ProfileLine 'Function .. { Set-Location .. }'
Add-ProfileLine 'Set-Alias .. Set-Location -Force'

Add-ProfileLine @'
if (-not $global:awsReminderShown) {
    if (Test-Path "$env:USERPROFILE\.aws\config") {
        Write-Host ""
        Write-Host "AWS SSO Profiles Available:" -ForegroundColor Yellow
        Write-Host "  awslogin-dev" -ForegroundColor Green
        Write-Host "  awslogin-qa" -ForegroundColor Green
        Write-Host "  awslogin-prod" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "AWS not configured yet." -ForegroundColor Yellow
        Write-Host "Run: aws configure sso" -ForegroundColor Green
    }
    $global:awsReminderShown = $true
}
'@

# Optional: AWS PowerShell Module
if (-not (Get-Module -ListAvailable -Name AWSPowerShell.NetCore)) {
    try {
        Install-Module -Name AWSPowerShell.NetCore -Scope CurrentUser -Force -AllowClobber
    } catch {
        Write-Warning "Install AWSPowerShell.NetCore manually if needed."
    }
}

Write-Host "`nEnvironment setup complete!"
Write-Host "Restart PowerShell to activate all features."
Write-Host "Manual Steps:"
Write-Host " - Set Terminal Font: JetBrainsMono Nerd Font"
Write-Host " - Apply Theme: Solarized Dark High Contrast"
Write-Host " - Configure AWS SSO if needed: aws configure sso"
Write-Host "`nUse awslogin-dev, awslogin-qa, awslogin-prod to login as needed."
