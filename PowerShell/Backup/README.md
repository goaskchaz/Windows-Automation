# BU_All.ps1 — Workstation Backup

PowerShell backup utility (version **1.4**, configurable public edition). Uses Windows **Robocopy** to preview or back up selected folders to a NAS share or other writable directory.

## Requirements

- Windows PowerShell 5.1 or PowerShell 7 on Windows
- Robocopy (included with Windows)
- A reachable, writable backup target (for NAS, use a UNC share rather than relying on a mapped drive)
- Access to the source folders; OneDrive cloud-only files require OneDrive to be running and able to retrieve their contents

## Usage

Preview first (default — no source files copied):

```powershell
.\BU_All.ps1 -TargetRoot '\\NAS\Backups' -BackupSource 'D:\BU'
```

Perform the backup:

```powershell
.\BU_All.ps1 -TargetRoot '\\NAS\Backups' -BackupSource 'D:\BU' -Execute
```

Override the automatically detected Windows folders if needed:

```powershell
.\BU_All.ps1 -TargetRoot '\\NAS\Backups' -PicturesSource 'C:\Photos' -DocumentsSource 'C:\Docs' -Execute
```

`-BackupSource` defaults to D:\BU; override it to select another folder. The backup source copies directly into the target root. Pictures goes into `My Pictures`, Documents into `Misc`, and logs into `Logs`. The target root must already exist.

## Parameters

| Parameter | Purpose |
| --- | --- |
| `-TargetRoot` | Required existing target directory or UNC share |
| `-BackupSource` | Additional folder backed up to the target root (defaults to D:\BU) |
| `-PicturesSource` | Overrides current user's Pictures folder |
| `-DocumentsSource` | Overrides current user's Documents folder |
| `-Execute` | Copies files; omit to preview using Robocopy `/L` |

## Safety and behavior

- Does **not** mirror or purge target-only files (`/MIR` and `/PURGE` are not used).
- `/XO` skips source files older than target copies; changed or newer source files may overwrite target copies. This is **not a versioned backup**.
- Robocopy exit codes 0–7 are treated as nonfatal; 8 or greater indicates failure.
- Actual backup mode requests that Windows remain awake while copying and restores normal automatic sleep behavior afterward. It does not prevent manual sleep or shutdown.
- Cloud-file errors (including OneDrive error 362) are logged and cause a failed job. This script does not pre-download cloud-only files.
- Preview mode creates a timestamped log on the target even though it does not copy source files.
- The script does not back up SQL Server databases.

## PowerShell help

```powershell
Get-Help .\BU_All.ps1 -Full
Get-Help .\BU_All.ps1 -Examples
```

## Troubleshooting

If a downloaded script is blocked under `RemoteSigned`, review the file and then run `Unblock-File .\BU_All.ps1` if you trust it. If a NAS drive letter is missing in an elevated PowerShell window, use the UNC share directly. For OneDrive cloud-file errors, ensure OneDrive is running and the files are locally available.

## Future enhancements

Optional configuration files, richer per-job statistics, and backup retention/versioning can be added in later versions. Do not commit passwords, credentials, or machine-specific configuration files to a public repository.

## PS Backup project conventions

The default three jobs are D:\BU to the target root, the current user's Pictures to My Pictures, and the current user's Documents to Misc. Run preview first; use -Execute only after reviewing paths. Keep machine-specific NAS names and credentials out of this public repository.


## Restore_All.ps1 — Restore or migrate to another PC

Version **1.1** reverses the BU_All.ps1 jobs. **SourceRoot is the NAS backup root, not the local restore drive.**

| NAS source | Local target (default) |
| --- | --- |
| SourceRoot | D:\BU |
| SourceRoot\My Pictures | Current user's Pictures |
| SourceRoot\Misc | Current user's Documents |

Preview restoring Job 1 to E:\BU (Pictures and Documents retain their Windows known-folder targets):

```powershell
.\Restore_All.ps1 -SourceRoot '\\SERVER\Backup' -BackupTarget 'E:\BU'
```

Preview restoring **all three jobs** to E::

```powershell
.\Restore_All.ps1 -SourceRoot '\\SERVER\Backup' -BackupTarget 'E:\BU' -PicturesTarget 'E:\My Pictures' -DocumentsTarget 'E:\Misc'
```

Append `-Execute` only after verifying the preview. The restore uses Robocopy `/E /XO /R:2 /W:5 /COPY:DAT /DCOPY:DAT /XJ`, never `/MIR` or `/PURGE`. Job 1 excludes NAS `My Pictures`, `Misc`, `Logs`, `$RECYCLE.BIN`, and `System Volume Information` to avoid duplicate or Windows metadata restores. The script stops before execution if any expected NAS source folder is missing; preview reports unavailable folders. Preview writes a timestamped log under NAS `Logs` but does not copy files.

The PowerShell 5.1 sleep-prevention flag uses decimal UInt32 values to avoid the signed hexadecimal conversion error. OneDrive-redirected local targets may require OneDrive to be configured on the new PC. SQL Server database restoration is not yet included.

```powershell
Get-Help .\Restore_All.ps1 -Full
```
