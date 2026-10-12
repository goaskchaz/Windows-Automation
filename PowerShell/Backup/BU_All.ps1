#Requires -Version 5.1
<#
.SYNOPSIS
    Previews or backs up workstation folders to a configurable target.
.DESCRIPTION
    Uses Robocopy to copy new or changed files without purging target files.
    Pictures and Documents default to the current Windows user's known folders.
    BackupSource defaults to D:\BU; override it with -BackupSource. Prevents automatic
    system sleep during an executed backup, but not manual sleep or shutdown.
    Cloud-only files require their provider (such as OneDrive) to be running.
.PARAMETER TargetRoot
    Existing, writable backup root (for example a NAS UNC share).
.PARAMETER BackupSource
    Additional source folder copied directly to TargetRoot (default D:\BU).
.PARAMETER PicturesSource
    Pictures folder; defaults to the current user's Pictures known folder.
.PARAMETER DocumentsSource
    Documents folder; defaults to the current user's Documents known folder.
.PARAMETER Execute
    Perform the backup. Without this switch, preview only.
.EXAMPLE
    .\BU_All.ps1 -TargetRoot '\\NAS\Backups' -BackupSource 'D:\BU'
    Preview the three configured jobs.
.EXAMPLE
    .\BU_All.ps1 -TargetRoot '\\NAS\Backups' -BackupSource 'D:\BU' -Execute
    Execute the backup and write a timestamped log.
.NOTES
    Author: C. W. Hitz
    Version: 1.4 (configurable public edition)
    Windows PowerShell 5.1 or PowerShell 7 on Windows required.
.OUTPUTS
    Console summary and timestamped log under TargetRoot\Logs.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$TargetRoot,

    [string]$BackupSource = 'D:\BU',

    [string]$PicturesSource = [Environment]::GetFolderPath('MyPictures'),

    [string]$DocumentsSource = [Environment]::GetFolderPath('MyDocuments'),

    [switch]$Execute
)

$ErrorActionPreference = 'Stop'
$LogTarget = Join-Path $TargetRoot 'Logs'
$BackupJobs = @()
$BackupJobs += @{ Name = 'Backup'; Source = $BackupSource; Target = $TargetRoot }
$BackupJobs += @{ Name = 'Pictures'; Source = $PicturesSource; Target = (Join-Path $TargetRoot 'My Pictures') }
$BackupJobs += @{ Name = 'Documents'; Source = $DocumentsSource; Target = (Join-Path $TargetRoot 'Misc') }

# Verify target and create a log before starting.
if (-not (Test-Path -LiteralPath $TargetRoot -PathType Container)) {
    throw "Backup target unavailable: $TargetRoot"
}
$Mode = if ($Execute) { 'Backup' } else { 'Preview' }
$Stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$LogFile = Join-Path $LogTarget "${Mode}_${Stamp}.log"
try {
    if (-not (Test-Path -LiteralPath $LogTarget -PathType Container)) {
        New-Item -Path $LogTarget -ItemType Directory -Force | Out-Null
    }
    "Mode: $Mode`r`nStarted: $(Get-Date -Format o)" |
        Set-Content -LiteralPath $LogFile
}
catch {
    throw "Unable to create backup log: $_"
}

# Windows execution-state API; allows the display to turn off.
if (-not ('BackupPower.SleepControl' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace BackupPower {
    public static class SleepControl {
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern uint SetThreadExecutionState(uint flags);
    }
}
'@
}
$ES_CONTINUOUS = [uint32]0x80000000
$ES_SYSTEM_REQUIRED = [uint32]0x00000001
$SleepGuardActive = $false
$Results = @()
$BackupFailed = $false

try {
    if ($Execute) {
        $State = [BackupPower.SleepControl]::SetThreadExecutionState(
            [uint32]($ES_CONTINUOUS -bor $ES_SYSTEM_REQUIRED))
        if ($State -eq 0) {
            Write-Warning 'Could not request system-awake state.'
        }
        else {
            $SleepGuardActive = $true
            Write-Host 'Automatic system sleep temporarily prevented.' -ForegroundColor Cyan
        }
    }

    $JobNumber = 0
    foreach ($Job in $BackupJobs) {
        $JobNumber++
        $Source = $Job.Source
        $Target = $Job.Target
        $JobStatus = 'Success'
        $Code = $null
        $Heading = "Job $JobNumber ($($Job.Name)): $Source -> $Target"
        Write-Host "`n$Heading" -ForegroundColor Cyan
        Add-Content -LiteralPath $LogFile -Value "`r`n$Heading"

        if ([string]::IsNullOrWhiteSpace($Source) -or
            -not (Test-Path -LiteralPath $Source -PathType Container)) {
            $JobStatus = 'Source unavailable'
            $BackupFailed = $true
            Write-Warning "${JobStatus}: $Source"
            Add-Content -LiteralPath $LogFile -Value "${JobStatus}: $Source"
        }
        else {
            # /L previews; /XO skips older sources; /XJ avoids junction loops.
            # No /MIR or /PURGE: target-only files are not removed.
            $Options = @('/E', '/XO', '/R:2', '/W:5', '/COPY:DAT',
                         '/DCOPY:DAT', '/XJ', '/TEE', "/LOG+:$LogFile")
            if (-not $Execute) { $Options += '/L' }

            try {
                & robocopy.exe $Source $Target @Options
                $Code = $LASTEXITCODE
            }
            catch {
                $Code = 16
                Add-Content -LiteralPath $LogFile -Value "Robocopy execution error: $_"
            }
            if ($Code -ge 8) {
                $JobStatus = 'Failed'
                $BackupFailed = $true
                Write-Warning "Job $JobNumber failed (Robocopy code $Code). See log."
            }
            else {
                Write-Host "Job $JobNumber completed (Robocopy code $Code)."
            }
        }
        $Results += [pscustomobject]@{
            Job = $JobNumber
            Name = $Job.Name
            Status = $JobStatus
            RobocopyCode = $Code
        }
    }
}
finally {
    if ($SleepGuardActive) {
        [void][BackupPower.SleepControl]::SetThreadExecutionState($ES_CONTINUOUS)
        Write-Host 'Normal system sleep behavior restored.' -ForegroundColor Cyan
    }
}

Write-Host "`nBackup job summary ($Mode):" -ForegroundColor Cyan
$Results | Format-Table -AutoSize | Out-Host
$Results | Format-Table -AutoSize | Out-String |
    Add-Content -LiteralPath $LogFile
$Status = if ($BackupFailed) { 'Completed with errors' } else { 'Completed successfully' }
Add-Content -LiteralPath $LogFile -Value "$Status - $(Get-Date -Format o)"
Write-Host $Status -ForegroundColor $(if ($BackupFailed) { 'Yellow' } else { 'Green' })
Write-Host "Log: $LogFile"
if ($BackupFailed) { exit 1 }
