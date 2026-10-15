#Requires -Version 5.1
<#
.SYNOPSIS
    Creates year-based folders in consecutive fixed-length intervals.
.DESCRIPTION
    Partitions an inclusive range of years into consecutive blocks of Num years.
    For Num = 1, folder names are single years (for example, 1960).
    For Num > 1, names are first-last (for example, 1960-1964).
    The last interval is capped at End. Existing folders are skipped.
    Omitted Start, End, Num, or Path values are prompted interactively.
    The script defines a function; dot-source it before calling the function.
.PARAMETER Start
    Inclusive first year; prompts when omitted.
.PARAMETER End
    Inclusive last year; prompts when omitted.
.PARAMETER Num
    Positive number of years per interval; prompts when omitted.
.PARAMETER Path
    Parent directory; prompts when omitted or blank. Created if necessary.
.EXAMPLE
    . .\Create_YearFldrs.ps1
    Create_YearFldrs -Start 1960 -End 1980 -Num 5 -Path 'C:\OTR Test'
.EXAMPLE
    Create_YearFldrs -Start 1960 -End 1980 -Num 1
.NOTES
    Version: 1.1
    Category: Utilities
    PowerShell: Windows PowerShell 5.1 or PowerShell 7+
    Warning: Creates directories; no files are deleted.
.OUTPUTS
    Console status messages and the total number of intervals.
#>
function Create_YearFldrs {
    [CmdletBinding()]
    param(
        [int]$Start,
        [int]$End,
        [int]$Num,
        [string]$Path = ''
    )

    if (-not $PSBoundParameters.ContainsKey('Start')) {
        $Start = [int](Read-Host 'Starting year')
    }
    if (-not $PSBoundParameters.ContainsKey('End')) {
        $End = [int](Read-Host 'Ending year')
    }
    if (-not $PSBoundParameters.ContainsKey('Num')) {
        $Num = [int](Read-Host 'Years per interval')
    }
    if ([string]::IsNullOrWhiteSpace($Path)) {
        $Path = Read-Host 'Parent folder path'
    }

    if ($Num -lt 1) { throw 'Num must be greater than zero.' }
    if ($End -lt $Start) { throw 'End must be greater than or equal to Start.' }
    if ([string]::IsNullOrWhiteSpace($Path)) { throw 'Parent folder path cannot be blank.' }

    if (Test-Path -LiteralPath $Path) {
        if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
            throw "Parent path exists but is not a directory: $Path"
        }
    }
    else {
        New-Item -ItemType Directory -Path $Path -Force -ErrorAction Stop | Out-Null
    }

    $Index = 0
    while (([long]$Start + ([long]$Index * $Num)) -le $End) {
        $FirstYear = [long]$Start + ([long]$Index * $Num)
        $LastYear = [Math]::Min([long]$End, ($FirstYear + $Num - 1L))
        if ($Num -eq 1) {
            $FolderName = "$FirstYear"
        }
        else {
            $FolderName = "$FirstYear-$LastYear"
        }
        $FolderPath = Join-Path -Path $Path -ChildPath $FolderName

        if (Test-Path -LiteralPath $FolderPath) {
            if (-not (Test-Path -LiteralPath $FolderPath -PathType Container)) {
                throw "Folder name conflicts with an existing file: $FolderPath"
            }
            $Status = 'Exists'
        }
        else {
            New-Item -ItemType Directory -Path $FolderPath -ErrorAction Stop | Out-Null
            $Status = 'Created'
        }
        Write-Host ("Index {0}: {1} [{2}]" -f $Index, $FolderName, $Status)
        $Index++
    }
    Write-Host "`nTotal intervals: $Index"
}
