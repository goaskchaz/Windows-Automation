# Create_YearFldrs

**Version:** 1.1  
**Location:** `PowerShell/Utilities/Create_YearFldrs.ps1`  
**Requirements:** Windows PowerShell 5.1 or PowerShell 7+.

## Purpose
Creates subdirectories for consecutive, fixed-length year intervals over an **inclusive** start/end range. Existing directories are left unchanged; missing directories are created.

## Parameters

| Parameter | Type | Meaning | When omitted |
| --- | --- | --- | --- |
| `Start` | int | First year, inclusive | Prompt |
| `End` | int | Last year, inclusive | Prompt |
| `Num` | int | Positive interval size in years | Prompt |
| `Path` | string | Parent directory | Prompt if omitted/blank |
| `Index` | internal | Zero-based interval counter | Calculated |

## Mathematical definition
For interval index `k = 0, 1, ...`:

- First year = `Start + k * Num`
- Last year = `min(End, Start + (k + 1) * Num - 1)`
- Number of folders = `ceil((End - Start + 1) / Num)`

The last interval may be shorter than `Num` years. Folder names use `FirstYear-LastYear`, except when `Num = 1`, which uses only `FirstYear`.

## Load and run
Dot-source the script into the current PowerShell session (note the dot followed by a space):

```powershell
. .\PowerShell\Utilities\Create_YearFldrs.ps1
Create_YearFldrs -Start 1960 -End 1980 -Num 5 -Path 'C:\OTR Test'
```

To be prompted for the parent directory:

```powershell
Create_YearFldrs -Start 1960 -End 1980 -Num 5
```

To confirm the function is loaded:

```powershell
Get-Command Create_YearFldrs
```

## Example results

`-Start 1960 -End 1980 -Num 5` creates:

```text
1960-1964
1965-1969
1970-1974
1975-1979
1980-1980
```

`-Start 1960 -End 1963 -Num 1` creates:

```text
1960
1961
1962
1963
```

`-Start 1960 -End 1980 -Num 10` creates:

```text
1960-1969
1970-1979
1980-1980
```

## Behavior and safety
- Creates the parent directory when missing.
- Skips an existing subdirectory and reports `Exists`.
- Throws an error when the parent path is an existing file, or a proposed folder name conflicts with an existing file.
- Rejects `Num <= 0`, `End < Start`, and blank parent paths.
- Uses `-LiteralPath` for existence checks to avoid interpreting wildcard characters.
- Reports `Index 0` for the first folder and the total number of intervals at completion.
- Does not delete, rename, or overwrite existing files or directories.
- **No preview mode**: calling the function creates directories. Use a temporary parent directory for testing.
- Requires write access to the chosen parent location; filesystem errors stop execution.

## Troubleshooting
**Command not recognized:** dot-source the script first; merely saving the file does not load the function.

**Access denied:** choose a writable directory or run under an account with suitable permissions.

**Unexpected final folder such as `1980-1980`:** this is the deliberate partial final interval when the ending year is inclusive.

## Maintenance
Update the version in comment-based help when behavior changes. The repository includes `PowerShell/Utilities/Update-ScriptIndex.ps1`, which rebuilds the root README script directory from comment-based help.
