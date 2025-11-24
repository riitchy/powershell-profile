# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Communication Style

**Use "tu" (informal you) when communicating with the repository owner (Lexx).** This is a French informal form. Address him directly and casually, as you would with a colleague or friend.

## Repository Overview

This is a PowerShell profile repository containing a single, comprehensive `profile.ps1` file that configures the PowerShell environment with enhanced features, custom functions, and automated tooling.

## Key Architecture

### Profile Structure
The profile is organized in this order:
1. **Configuration variables** (`$debug`, `$updateInterval`, `$timeFilePath`)
2. **System setup** (telemetry opt-out, module paths, PATH configuration)
3. **Module loading** (Terminal-Icons, LexxPoshTools, poshible)
4. **Prompt configuration** (oh-my-posh or fallback custom prompt)
5. **PSReadLine configuration** (Vi mode, colors, keybindings, prediction)
6. **Update functions** (`Update-Profile`, `Update-PowerShell`)
7. **Utility functions** (system maintenance, file operations, git shortcuts)
8. **Tool installation functions** (`Install-ClaudeCode`)

### Critical Design Decisions

**PSReadLine Mode**: The profile uses **Vi mode** (`EditMode = 'Vi'`), not Windows mode. Users expect Vim keybindings.

**Update mechanism**: Profile auto-updates from `https://raw.githubusercontent.com/riitchy/powershell-profile/master/profile.ps1` every 7 days (configurable via `$updateInterval`). Setting `$debug = $true` disables updates.

**PATH configuration**: The profile adds `$env:USERPROFILE\.local\bin` to PATH for Claude Code and other tools. This directory is created if it doesn't exist.

**Module loading strategy**: Modules are checked for availability before loading. Missing optional modules (LexxPoshTools, poshible) trigger warnings but don't break the profile.

**Prediction features**: PSReadLine prediction is conditional on terminal capabilities (`$supportsVirtualTerminal`). Uses `HistoryAndPlugin` source with `ListView` style.

### Important Functions

**`Install-ClaudeCode`**: Automated Claude Code installer that:
1. Searches for Git Bash in common Windows locations
2. Sets `CLAUDE_CODE_GIT_BASH_PATH` environment variable
3. Downloads and executes the official installer
4. Prompts user if bash.exe not found

**`Update-Profile` / `Update-PowerShell`**: Both check for updates and are called together in a single conditional block to avoid duplication.

**Unix-like utilities**: Functions like `grep`, `sed`, `head`, `tail`, `which`, `pkill` provide Unix-like behavior in PowerShell with proper error handling and file validation.

## Making Changes

### When editing the profile:

**Language**: All comments and error messages must be in English.

**Code quality expectations**:
- Functions must validate file/directory existence before operations
- Error handling with try/catch for network operations
- No code duplication (consolidate similar logic)
- Use `Write-Error` for error messages, `Write-Warning` for warnings

**PSReadLine configuration**: If modifying PSReadLine settings, remember:
- Prediction features are conditionally enabled
- Vi mode is the expected behavior
- History filtering excludes sensitive keywords

**Testing changes**: After editing, test by running:
```powershell
. $PROFILE.CurrentUserAllHosts  # or use Reload-Profile function
```

Set `$debug = $true` at the top of the profile to skip auto-updates during testing.

## Git Workflow

The repository uses direct commits to `master` branch. When committing profile changes:
- Include Co-Authored-By: Claude tag if changes were AI-assisted
- Use descriptive commit messages that summarize multiple changes
- Always push after committing

## External Dependencies

- **oh-my-posh**: Optional prompt engine (config: `$env:USERPROFILE\Documents\PowerShell\oh-my-posh\themes\amro.omp.json`)
- **Terminal-Icons**: Auto-installed if missing
- **LexxPoshTools, poshible**: Optional modules, warnings shown if absent
- **Git Bash**: Required for Claude Code functionality
- **bat**: Uses `$env:BAT_STYLE` for styled output

## Profile Installation

Users source this profile by placing it at `$PROFILE.CurrentUserAllHosts` location. The profile is designed to be self-contained and handle first-run scenarios gracefully.
