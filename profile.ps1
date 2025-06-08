# Partiellement repris de Chris Titus Tech : https://raw.githubusercontent.com/ChrisTitusTech/powershell-profile/main/profile.ps1

$debug = $false

# Define the path to the file that stores the last execution time
$timeFilePath = [Environment]::GetFolderPath("MyDocuments") + "\PowerShell\LastExecutionTime.txt"

# Define the update interval in days, set to -1 to always check
$updateInterval = 7

#opt-out of telemetry before doing anything, only if PowerShell is run as admin
if ([bool]([System.Security.Principal.WindowsIdentity]::GetCurrent()).IsSystem) {
    [System.Environment]::SetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT', 'true', [System.EnvironmentVariableTarget]::Machine)
}

$ModulesPath = "C:\Users\$env:USERNAME\PSModules"
if (-not (Test-Path -Path $ModulesPath)) {
    New-Item -ItemType Directory -Path $ModulesPath -Force
}

# Ajout du dossier modules locaux au path
$env:PSModulePath = $ModulesPath + ";" + $env:PSModulePath

# Vérifier si Terminal Icons est installé
if (-not (Get-Module -ListAvailable -Name Terminal-Icons)) {
    Install-Module -Name Terminal-Icons -Scope CurrentUser -Force -SkipPublisherCheck
}

Import-Module -Name Terminal-Icons, LexxPoshTools, poshible

if (Get-Command "oh-my-posh" -ErrorAction SilentlyContinue) {
    $ohmyposhConfig = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "PowerShell\oh-my-posh\themes\amro.omp.json"
    oh-my-posh --init --shell pwsh --config $ohmyposhConfig | Invoke-Expression
}
else {
    function prompt {
        $host.UI.RawUI.WindowTitle = "PowerShell $($ExecutionContext.SessionState.Path.CurrentLocation)$('>' * ($NestedPromptLevel + 1))"
        Write-Host " "
        Write-Host ($ExecutionContext.SessionState.Path.CurrentLocation) -ForegroundColor Cyan
    
        $promptString = "PS>" + (" " * $NestedPromptLevel) + " "
        Write-Host $promptString -NoNewLine
        return ' '
    }
}

# Enhanced PowerShell Experience
# Enhanced PSReadLine Configuration
$PSReadLineOptions = @{
    EditMode = 'Windows'
    HistoryNoDuplicates = $true
    HistorySearchCursorMovesToEnd = $true
    Colors = @{
        Command = '#87CEEB'  # SkyBlue (pastel)
        Parameter = '#98FB98'  # PaleGreen (pastel)
        Operator = '#FFB6C1'  # LightPink (pastel)
        Variable = '#DDA0DD'  # Plum (pastel)
        String = '#FFDAB9'  # PeachPuff (pastel)
        Number = '#B0E0E6'  # PowderBlue (pastel)
        Type = '#F0E68C'  # Khaki (pastel)
        Comment = '#D3D3D3'  # LightGray (pastel)
        Keyword = '#8367c7'  # Violet (pastel)
        Error = '#FF6347'  # Tomato (keeping it close to red for visibility)
    }
    BellStyle = 'None'
}

# Vérifier si l'environnement prend en charge les fonctionnalités de prédiction
$supportsVirtualTerminal = $Host.UI.SupportsVirtualTerminal -and -not [System.Console]::IsOutputRedirected

# Ajouter les options de prédiction seulement si l'environnement les prend en charge
if ($supportsVirtualTerminal) {
    $PSReadLineOptions['PredictionSource'] = 'History'
    $PSReadLineOptions['PredictionViewStyle'] = 'ListView'
}

Set-PSReadLineOption @PSReadLineOptions

# Custom key handlers
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadLineKeyHandler -Chord 'Ctrl+d' -Function DeleteChar
Set-PSReadLineKeyHandler -Chord 'Ctrl+w' -Function BackwardDeleteWord
Set-PSReadLineKeyHandler -Chord 'Alt+d' -Function DeleteWord
Set-PSReadLineKeyHandler -Chord 'Ctrl+LeftArrow' -Function BackwardWord
Set-PSReadLineKeyHandler -Chord 'Ctrl+RightArrow' -Function ForwardWord
Set-PSReadLineKeyHandler -Chord 'Ctrl+z' -Function Undo
Set-PSReadLineKeyHandler -Chord 'Ctrl+y' -Function Redo

# Custom functions for PSReadLine
Set-PSReadLineOption -AddToHistoryHandler {
    param($line)
    $sensitive = @('password', 'secret', 'token', 'apikey', 'connectionstring')
    $hasSensitive = $sensitive | Where-Object { $line -match $_ }
    return ($null -eq $hasSensitive)
}

# Improved prediction settings - seulement si l'environnement le prend en charge
if ($supportsVirtualTerminal) {
    Set-PSReadLineOption -PredictionSource HistoryAndPlugin
}
Set-PSReadLineOption -MaximumHistoryCount 10000

# Custom completion for common commands
$scriptblock = {
    param($wordToComplete, $commandAst, $cursorPosition)
    $customCompletions = @{
        'git' = @('status', 'add', 'commit', 'push', 'pull', 'clone', 'checkout')
    }
    
    $command = $commandAst.CommandElements[0].Value
    if ($customCompletions.ContainsKey($command)) {
        $customCompletions[$command] | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
}
Register-ArgumentCompleter -Native -CommandName git -ScriptBlock $scriptblock

$env:BAT_STYLE="header,header-filesize,grid"

# Check for Profile Updates
function Update-Profile {
    try {
        $url = "https://raw.githubusercontent.com/riitchy/powershell-profile/master/profile.ps1"
        $oldhash = Get-FileHash $PROFILE.CurrentUserAllHosts
        Invoke-RestMethod $url -OutFile "$env:temp/profile.ps1"
        $newhash = Get-FileHash "$env:temp/profile.ps1"
        if ($newhash.Hash -ne $oldhash.Hash) {
            Copy-Item -Path "$env:temp/profile.ps1" -Destination $PROFILE.CurrentUserAllHosts -Force
            Write-Host "Profile has been updated. Please restart your shell to reflect changes" -ForegroundColor Magenta
        } else {
            Write-Host "Profile is up to date." -ForegroundColor Green
        }
    } catch {
        Write-Error "Unable to check for `$PROFILE.CurrentUserAllHosts updates: $_"
    } finally {
        Remove-Item "$env:temp/profile.ps1" -ErrorAction SilentlyContinue
    }
}

# Check if not in debug mode AND (updateInterval is -1 OR file doesn't exist OR time difference is greater than the update interval)
if (-not $debug -and `
    ($updateInterval -eq -1 -or `
      -not (Test-Path $timeFilePath) -or `
      ((Get-Date) - [datetime]::ParseExact((Get-Content -Path $timeFilePath), 'yyyy-MM-dd', $null)).TotalDays -gt $updateInterval)) {

    Update-Profile
    $currentTime = Get-Date -Format 'yyyy-MM-dd'
    $currentTime | Out-File -FilePath $timeFilePath

} elseif ($debug) {
    Write-Warning "Skipping profile update check in debug mode"
}

function Update-PowerShell {
    try {
        Write-Host "Checking for PowerShell updates..." -ForegroundColor Cyan
        $updateNeeded = $false
        $currentVersion = $PSVersionTable.PSVersion.ToString()
        $gitHubApiUrl = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
        $latestReleaseInfo = Invoke-RestMethod -Uri $gitHubApiUrl
        $latestVersion = $latestReleaseInfo.tag_name.Trim('v')
        if ($currentVersion -lt $latestVersion) {
            $updateNeeded = $true
        }

        if ($updateNeeded) {
            Write-Host "Updating PowerShell..." -ForegroundColor Yellow
            Start-Process powershell.exe -ArgumentList "-NoProfile -Command winget upgrade Microsoft.PowerShell --accept-source-agreements --accept-package-agreements" -Wait -NoNewWindow
            Write-Host "PowerShell has been updated. Please restart your shell to reflect changes" -ForegroundColor Magenta
        } else {
            Write-Host "Your PowerShell is up to date." -ForegroundColor Green
        }
    } catch {
        Write-Error "Failed to update PowerShell. Error: $_"
    }
}

# skip in debug mode
# Check if not in debug mode AND (updateInterval is -1 OR file doesn't exist OR time difference is greater than the update interval)
if (-not $debug -and `
    ($updateInterval -eq -1 -or `
     -not (Test-Path $timeFilePath) -or `
     ((Get-Date).Date - [datetime]::ParseExact((Get-Content -Path $timeFilePath), 'yyyy-MM-dd', $null).Date).TotalDays -gt $updateInterval)) {

    Update-PowerShell
    $currentTime = Get-Date -Format 'yyyy-MM-dd'
    $currentTime | Out-File -FilePath $timeFilePath
} elseif ($debug) {
    Write-Warning "Skipping PowerShell update in debug mode"
}

function Clear-Cache {
    # add clear cache logic here
    Write-Host "Clearing cache..." -ForegroundColor Cyan

    # Clear Windows Prefetch
    Write-Host "Clearing Windows Prefetch..." -ForegroundColor Yellow
    Remove-Item -Path "$env:SystemRoot\Prefetch\*" -Force -ErrorAction SilentlyContinue

    # Clear Windows Temp
    Write-Host "Clearing Windows Temp..." -ForegroundColor Yellow
    Remove-Item -Path "$env:SystemRoot\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue

    # Clear User Temp
    Write-Host "Clearing User Temp..." -ForegroundColor Yellow
    Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue

    # Clear Internet Explorer Cache
    Write-Host "Clearing Internet Explorer Cache..." -ForegroundColor Yellow
    Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Windows\INetCache\*" -Recurse -Force -ErrorAction SilentlyContinue

    Write-Host "Cache clearing completed." -ForegroundColor Green
}

# Quick Access to Editing the Profile
function Edit-Profile {
    hx $PROFILE.CurrentUserAllHosts
}
Set-Alias -Name ep -Value Edit-Profile

function Reload-Profile {
    . $PROFILE.CurrentUserAllHosts
}

function touch($file) {
    if (!(Test-Path $file)) {
        "" | Out-File $file -Encoding ASCII
    } else {
        (Get-Item $file).LastWriteTime = Get-Date
    }
}

function Get-PubIP { (Invoke-WebRequest http://ifconfig.me/ip).Content }

# Open WinUtil full-release
function winutil {
	Invoke-RestMethod https://christitus.com/win | Invoke-Expression
}

function admin {
    if ($args.Count -gt 0) {
        $argList = $args -join ' '
        Start-Process wt -Verb runAs -ArgumentList "pwsh.exe -NoExit -Command $argList"
    } else {
        Start-Process wt -Verb runAs
    }
}

# Quick File Creation
function nf { param($name) New-Item -ItemType "file" -Path . -Name $name }

# Directory Management
function mkcd { param($dir) mkdir $dir -Force; Set-Location $dir }

function grep($regex, $dir) {
    if ($dir) {
        if (!(Test-Path $dir)) {
            Write-Error "Le répertoire $dir n'existe pas"
            return
        }
        Get-ChildItem $dir | Select-String $regex -ErrorAction SilentlyContinue
        return
    }
    $input | Select-String $regex -ErrorAction SilentlyContinue
}

function df {
    get-volume
}

function sed($file, $find, $replace) {
    if (!(Test-Path $file)) {
        Write-Error "Le fichier $file n'existe pas"
        return
    }
    (Get-Content $file).replace("$find", $replace) | Set-Content $file
}

function which($name) {
    Get-Command $name | Select-Object -ExpandProperty Definition
}

function export($name, $value) {
    set-item -force -path "env:$name" -value $value;
}

function pkill($name) {
    $processes = Get-Process $name -ErrorAction SilentlyContinue
    if ($processes) {
        $processes | Stop-Process
        Write-Host "Processus $name terminé(s)" -ForegroundColor Green
    } else {
        Write-Host "Aucun processus $name trouvé" -ForegroundColor Yellow
    }
}

function pgrep($name) {
Get-Process $name
}

function head {
    param($Path, $n = 10)
    Get-Content $Path -Head $n
}

function tail {
    param($Path, $n = 10, [switch]$f = $false)
    if (!(Test-Path $Path)) {
        Write-Error "Le fichier $Path n'existe pas"
        return
    }
    Get-Content $Path -Tail $n -Wait:$f
}

# Git Shortcuts
function gs { git status }

function ga { git add . }

function gc { param($m) git commit -m "$m" }

function gp { git push }

function gcl { git clone "$args" }

function gcom {
    git add .
    git commit -m "$args"
}
function lazyg {
    git add .
    git commit -m "$args"
    git push
}

# Quick Access to System Information
function sysinfo { Get-ComputerInfo }

# Networking Utilities
function flushdns {
	Clear-DnsClientCache
	Write-Host "DNS has been flushed"
}
