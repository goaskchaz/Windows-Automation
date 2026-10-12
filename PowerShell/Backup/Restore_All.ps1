#Requires -Version 5.1
<#
.SYNOPSIS
    Preview or restore workstation files from a NAS backup.
.DESCRIPTION
    Reverses BU_All.ps1 mappings. NAS backup root restores to a local BU
    folder; NAS My Pictures and Misc restore to local Pictures and Documents.
    Preview is the default. -Execute enables copying. Target-only files are
    never purged and newer target files are protected by Robocopy /XO.
.PARAMETER SourceRoot
    NAS backup root, e.g. \\SERVER\Backup. Do not supply the local E: drive.
.PARAMETER BackupTarget
    Local target for NAS backup root; defaults to D:\BU.
.PARAMETER PicturesTarget
    Local Pictures destination; defaults to current user's known folder.
.PARAMETER DocumentsTarget
    Local Documents destination; defaults to current user's known folder.
.PARAMETER Execute
    Execute the restore instead of previewing it.
.EXAMPLE
    .\Restore_All.ps1 -SourceRoot '\\SERVER\Backup' -BackupTarget 'E:\BU'
.EXAMPLE
    .\Restore_All.ps1 -SourceRoot '\\SERVER\Backup' -BackupTarget 'E:\BU' -PicturesTarget 'E:\My Pictures' -DocumentsTarget 'E:\Misc' -Execute
.NOTES
    Version 1.1. SQL Server restore not included.
    Preview writes a log on the NAS but does not copy local files.
.OUTPUTS
    Robocopy output, job summary and a timestamped log under NAS Logs.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$SourceRoot,
    [string]$BackupTarget = 'D:\BU',
    [string]$PicturesTarget = [Environment]::GetFolderPath('MyPictures'),
    [string]$DocumentsTarget = [Environment]::GetFolderPath('MyDocuments'),
    [switch]$Execute
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $SourceRoot -PathType Container)) {
    throw "NAS restore source unavailable: $SourceRoot"
}
if (-not (Get-Command robocopy.exe -ErrorAction SilentlyContinue)) {
    throw 'Robocopy was not found.'
}
$Jobs = @(
    @{Name='Backup';Source=$SourceRoot;Target=$BackupTarget},
    @{Name='Pictures';Source=(Join-Path $SourceRoot 'My Pictures');Target=$PicturesTarget},
    @{Name='Documents';Source=(Join-Path $SourceRoot 'Misc');Target=$DocumentsTarget}
)
$Missing = @($Jobs | Where-Object {
    -not (Test-Path -LiteralPath $_.Source -PathType Container)
})
if ($Execute -and $Missing.Count -gt 0) {
    throw "Restore stopped: missing NAS source folders: $($Missing.Source -join ', '). Check -SourceRoot."
}
$Mode = if ($Execute) {'Restore'} else {'Preview'}
$LogDirectory = Join-Path $SourceRoot 'Logs'
$LogFile = Join-Path $LogDirectory ("Restore_{0}_{1}.log" -f $Mode,(Get-Date -Format 'yyyyMMdd_HHmmss'))
try {
    if (-not (Test-Path -LiteralPath $LogDirectory -PathType Container)) {
        New-Item -Path $LogDirectory -ItemType Directory -Force | Out-Null
    }
    "Restore_All.ps1 v1.1 - $Mode - $(Get-Date -Format o)" |
        Set-Content -LiteralPath $LogFile
}
catch { throw "Cannot create NAS restore log: $_" }
# Exclude the other jobs, logs, and Windows volume metadata from Job 1.
$ExcludeDirectories = @(
    (Join-Path $SourceRoot 'My Pictures'),
    (Join-Path $SourceRoot 'Misc'),
    $LogDirectory,
    (Join-Path $SourceRoot '$RECYCLE.BIN'),
    (Join-Path $SourceRoot 'System Volume Information')
)
# PowerShell 5.1: decimal UInt32 avoids signed 0x80000000 conversion error.
$ES_CONTINUOUS = [uint32]2147483648
$ES_SYSTEM_REQUIRED = [uint32]1
$SleepGuardActive = $false
$Results = @()
$RestoreFailed = $false
try {
    if ($Execute) {
        if (-not ('RestorePower.SleepControl' -as [type])) {
            Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace RestorePower {
    public static class SleepControl {
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern uint SetThreadExecutionState(uint flags);
    }
}
'@
        }
        $PowerResult = [RestorePower.SleepControl]::SetThreadExecutionState(
            [uint32]($ES_CONTINUOUS -bor $ES_SYSTEM_REQUIRED))
        if ($PowerResult -eq 0) {
            Write-Warning 'Could not enable automatic sleep prevention.'
        } else {
            $SleepGuardActive = $true
        }
    }
    $Number = 0
    foreach ($Job in $Jobs) {
        $Number++
        $Source = $Job.Source
        $Target = $Job.Target
        $Code = $null
        $Status = 'Success'
        $Heading = "Job $Number ($($Job.Name)): $Source -> $Target"
        Write-Host $Heading -ForegroundColor Cyan
        Add-Content -LiteralPath $LogFile -Value $Heading
        if ([string]::IsNullOrWhiteSpace($Target)) {
            $Status = 'Target unspecified'
        }
        elseif (-not (Test-Path -LiteralPath $Source -PathType Container)) {
            $Status = 'Source unavailable'
        }
        else {
            $Options = @('/E','/XO','/R:2','/W:5','/COPY:DAT',
                         '/DCOPY:DAT','/XJ','/TEE',"/LOG+:$LogFile")
            if ($Number -eq 1) {
                $Options += '/XD'
                $Options += $ExcludeDirectories
            }
            if (-not $Execute) { $Options += '/L' }
            try {
                & robocopy.exe $Source $Target @Options
                $Code = $LASTEXITCODE
                if ($Code -ge 8) { $Status = 'Failed' }
            }
            catch {
                $Status = 'Failed'
                Add-Content -LiteralPath $LogFile -Value "Robocopy error: $_"
            }
        }
        if ($Status -ne 'Success') {
            $RestoreFailed = $true
            Write-Warning "Job $Number : $Status (Robocopy code $Code)"
            Add-Content -LiteralPath $LogFile -Value "Job $Number : $Status (Robocopy code $Code)"
        }
        $Results += [pscustomobject]@{
            Job=$Number;Name=$Job.Name;Status=$Status;RobocopyCode=$Code
        }
    }
}
finally {
    if ($SleepGuardActive) {
        [void][RestorePower.SleepControl]::SetThreadExecutionState($ES_CONTINUOUS)
        Write-Host 'Normal automatic sleep behavior restored.'
    }
}
$Summary = $Results | Format-Table -AutoSize | Out-String
Write-Host $Summary
Add-Content -LiteralPath $LogFile -Value $Summary
$FinalStatus = if ($RestoreFailed) {'Completed with errors'} else {'Completed successfully'}
Add-Content -LiteralPath $LogFile -Value "$FinalStatus - $(Get-Date -Format o)"
Write-Host $FinalStatus
Write-Host "Mode: $Mode"
Write-Host "Log: $LogFile"
if ($RestoreFailed) { exit 1 }
