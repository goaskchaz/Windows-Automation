# BU_All.ps1 — Workstation Backup

**Version 1.5** | Windows PowerShell 5.1+ | Robocopy

Backs up **one source directory only** (default `D:\BU`) directly into an existing NAS or local target directory. Pictures, Documents, and SQL Server backups are **excluded**. The script does not perform OneDrive-specific checks.

## Usage

Preview (default, no source files copied):

```powershell
.\BU_All.ps1 -TargetRoot '\\MYCLOUD\Backup'
```

Execute actual backup:

```powershell
.\BU_All.ps1 -TargetRoot '\\MYCLOUD\Backup' -Execute
```

Use a different source or destination:

```powershell
.\BU_All.ps1 -TargetRoot '\\SERVER\Backup' -BackupSource 'E:\Data'
```

## Parameters

| Parameter | Meaning |
| --- | --- |
| `-TargetRoot` | **Required** existing NAS UNC share or writable directory |
| `-BackupSource` | Source directory; defaults to `D:\BU` |
| `-Execute` | Copy files; omit for ROBOCOPY read-only preview (`/L`) |

## Robocopy switches

| Switch | Definition |
| --- | --- |
| `/E` | Include subdirectories, including empty directories |
| `/XO` | Exclude source files older than their destination copies |
| `/FFT` | Use 2-second timestamp precision for NAS compatibility |
| `/Z` | Restartable copy mode |
| `/R:2` | Retry failed copies twice |
| `/W:5` | Wait five seconds between retries |
| `/NP` | Hide percentage progress |
| `/V` | Verbose output, including skipped files |
| `/FP` | Show full file paths |
| `/COPY:DAT` | Copy data, attributes, timestamps |
| `/DCOPY:DAT` | Copy directory data, attributes, timestamps |
| `/XJ` | Exclude junction points |
| `/TEE` | Display output and write to log |
| `/LOG+` | Append Robocopy output to the timestamped log |
| `/L` | Preview only; no source files copied (omitted with `-Execute`) |

The script never uses `/MIR` or `/PURGE`, so extra files at the destination are not deleted. Existing destination files may be overwritten when an eligible source update is copied. This is not a versioned backup.

## Logs, validation, and exit codes

The target root must exist. A timestamped log is written under `TargetRoot\Logs` in **both** preview and execute modes. Thus preview is read-only for the backed-up data, but **does write a log to the NAS**.

Robocopy exit codes 0–7 are treated as nonfatal; 8 or greater indicates a failure. The script prints a per-job summary. Executed backups request that Windows remain awake, then restore normal automatic sleep behavior.

Before executing, verify the source, destination, NAS capacity, and preview. Do not place NAS credentials or personal paths in the public repository.

## Restore compatibility

`Restore_All.ps1` remains at version 1.1 and is **not modified** by this update. It still expects the older three-job layout (`Backup`, `My Pictures`, and `Misc`). **Do not run its `-Execute` option as a matching restore for BU_All.ps1 v1.5** without first updating and reviewing the restore job mapping. An aligned restore revision is a separate task.

## Changelog

- **1.5** — Single backup job only; removed Pictures and Documents; added `/V`, `/FP`, `/FFT`, `/Z`, `/NP`; clarified logging and restore compatibility; adjusted sleep flag for Windows PowerShell 5.1.
- **1.4** — Configurable three-job backup with preview, logging, and sleep prevention.
