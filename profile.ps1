# Partially based on Chris Titus Tech: https://raw.githubusercontent.com/ChrisTitusTech/powershell-profile/main/profile.ps1

$debug = $false

# Define the path to the file that stores the last execution time
$timeFilePath = [Environment]::GetFolderPath("MyDocuments") + "\PowerShell\LastExecutionTime.txt"

# Define the update interval in days, set to -1 to always check
$updateInterval = 7

# Opt-out of telemetry before doing anything, only if PowerShell is run as admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) {
    [System.Environment]::SetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT', 'true', [System.EnvironmentVariableTarget]::Machine)
}

$ModulesPath = "C:\Users\$env:USERNAME\PSModules"
if (-not (Test-Path -Path $ModulesPath)) {
    New-Item -ItemType Directory -Path $ModulesPath -Force
}

# Add local modules folder to path
$env:PSModulePath = $ModulesPath + ";" + $env:PSModulePath

# Add ~/.local/bin to PATH for Claude Code and other tools
$LocalBinPath = "$env:USERPROFILE\.local\bin"
if (-not (Test-Path -Path $LocalBinPath)) {
    New-Item -ItemType Directory -Path $LocalBinPath -Force
}
if ($env:PATH -notlike "*$LocalBinPath*") {
    $env:PATH = $LocalBinPath + ";" + $env:PATH
}

# Check if Terminal Icons is installed
if (-not (Get-Module -ListAvailable -Name Terminal-Icons)) {
    Install-Module -Name Terminal-Icons -Scope CurrentUser -Force -SkipPublisherCheck
}

$LexxPoshToolsInstalled = Get-Module -ListAvailable -Name LexxPoshTools
$poshibleInstalled = Get-Module -ListAvailable -Name poshible

$modulesToLoad = @('Terminal-Icons')

if ($LexxPoshToolsInstalled) { $modulesToLoad += 'LexxPoshTools' } else { Write-Warning "LexxPoshTools is not installed." }
if ($poshibleInstalled) { $modulesToLoad += 'poshible' } else { Write-Warning "poshible is not installed." }

try {
    Import-Module -Name $modulesToLoad -ErrorAction Stop
}
catch {
    Write-Warning "Some modules failed to import: $_"
}

# Using Starship prompt (winget install --id Starship.Starship)
# Invoke-Expression (&starship init powershell)

if (Get-Command "oh-my-posh" -ErrorAction SilentlyContinue) {
    $ohmyposhConfig = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "\PowerShell\oh-my-posh\themes\amro.omp.json"
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
    EditMode = 'Vi'
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

# Check if the environment supports prediction features
$supportsVirtualTerminal = $Host.UI.SupportsVirtualTerminal -and -not [System.Console]::IsOutputRedirected

# Add prediction options only if the environment supports them
if ($supportsVirtualTerminal) {
    $PSReadLineOptions['PredictionSource'] = 'HistoryAndPlugin'
    $PSReadLineOptions['PredictionViewStyle'] = 'ListView'
}

Set-PSReadLineOption @PSReadLineOptions
Set-PSReadLineOption -MaximumHistoryCount 10000

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

# Vi mode cursor shapes
Set-PSReadLineOption -ViModeIndicator Cursor

# Custom functions for PSReadLine
Set-PSReadLineOption -AddToHistoryHandler {
    param($line)
    $sensitive = @('password', 'secret', 'token', 'apikey', 'connectionstring')
    $hasSensitive = $sensitive | Where-Object { $line -match $_ }
    return ($null -eq $hasSensitive)
}

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

# Check for profile and PowerShell updates
if (-not $debug -and `
    ($updateInterval -eq -1 -or `
      -not (Test-Path $timeFilePath) -or `
      ((Get-Date).Date - [datetime]::ParseExact((Get-Content -Path $timeFilePath), 'yyyy-MM-dd', $null).Date).TotalDays -gt $updateInterval)) {

    Update-Profile
    Update-PowerShell
    $currentTime = Get-Date -Format 'yyyy-MM-dd'
    $currentTime | Out-File -FilePath $timeFilePath

} elseif ($debug) {
    Write-Warning "Skipping profile and PowerShell updates in debug mode"
}

function Clear-Cache {
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


function Install-ClaudeCode {
    <#
    .SYNOPSIS
        Installs Claude Code and configures the Git Bash environment variable.
    .DESCRIPTION
        Configures the CLAUDE_CODE_GIT_BASH_PATH environment variable first,
        then downloads and installs Claude Code from the official installation script.
    #>

    Write-Host "`r`nPreparing Claude Code installation..." -ForegroundColor Cyan

    # Configure Git Bash environment variable BEFORE installation
    Write-Host "Configuring Claude Code environment variable..." -ForegroundColor Yellow

    try {
        # Search for bash.exe in common locations
        $possiblePaths = @(
            "C:\Program Files\Git\bin\bash.exe",
            "C:\Program Files (x86)\Git\bin\bash.exe",
            "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe",
            "C:\Program Files\Git\usr\bin\bash.exe"
        )

        $gitBashPath = $possiblePaths | Where-Object { Test-Path $_ } | Select-Object -First 1

        if ($gitBashPath) {
            [System.Environment]::SetEnvironmentVariable("CLAUDE_CODE_GIT_BASH_PATH", $gitBashPath, "User")
            $env:CLAUDE_CODE_GIT_BASH_PATH = $gitBashPath  # Set for current session
            Write-Host "CLAUDE_CODE_GIT_BASH_PATH set to: $gitBashPath" -ForegroundColor Green
        }
        else {
            Write-Warning "bash.exe not found in common locations. Claude Code may not work properly."
            Write-Host "You can manually set the environment variable with:" -ForegroundColor Yellow
            Write-Host '[System.Environment]::SetEnvironmentVariable("CLAUDE_CODE_GIT_BASH_PATH", "C:\Path\To\bash.exe", "User")' -ForegroundColor Gray

            $continue = Read-Host "`nDo you want to continue with the installation anyway? (Y/N)"
            if ($continue -notmatch '^[Yy]') {
                Write-Host "Installation cancelled." -ForegroundColor Yellow
                return
            }
        }
    }
    catch {
        Write-Error "Error while configuring CLAUDE_CODE_GIT_BASH_PATH: $_"
        return
    }

    # Install Claude Code AFTER environment variable is set
    Write-Host "`r`nInstalling Claude Code..." -ForegroundColor Cyan

    try {
        Write-Host "Downloading and executing Claude Code installer..." -ForegroundColor Yellow
        Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression
        Write-Host "Claude Code installation completed successfully." -ForegroundColor Green
    }
    catch {
        Write-Error "Error while installing Claude Code: $_"
        return
    }

    Write-Host "`r`nClaude Code installation process completed!" -ForegroundColor Cyan
    Write-Host "You may need to restart your PowerShell session for changes to take effect." -ForegroundColor Magenta
}


# Quick Access to Editing the Profile
function Edit-Profile {
    nvim $PROFILE.CurrentUserAllHosts
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

function Get-PubIP {
    try {
        (Invoke-WebRequest http://ifconfig.me/ip).Content
    } catch {
        Write-Error "Unable to retrieve public IP: $_"
    }
}

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
            Write-Error "The directory $dir does not exist"
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
        Write-Error "The file $file does not exist"
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
        Write-Host "Process $name terminated" -ForegroundColor Green
    } else {
        Write-Host "No process $name found" -ForegroundColor Yellow
    }
}

function pgrep($name) {
Get-Process $name
}

function head {
    param($Path, $n = 10)
    if (!(Test-Path $Path)) {
        Write-Error "The file $Path does not exist"
        return
    }
    Get-Content $Path -Head $n
}

function tail {
    param($Path, $n = 10, [switch]$f = $false)
    if (!(Test-Path $Path)) {
        Write-Error "The file $Path does not exist"
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

function ws($app) {
	winget search $app
}

function wi($id) {
	winget install --id $id --source winget
}

function wl { winget list }

function wlu { winget list --upgrade-available }

function wua { winget upgrade --all }

# Quick Access to System Information
function sysinfo { Get-ComputerInfo }

# Networking Utilities
function flushdns {
	Clear-DnsClientCache
	Write-Host "DNS has been flushed"
}
