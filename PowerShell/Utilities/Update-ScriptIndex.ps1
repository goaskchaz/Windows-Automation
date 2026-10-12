#Requires -Version 5.1
<#
.SYNOPSIS
    Rebuilds the PowerShell script directory in the repository README.
.DESCRIPTION
    Scans PowerShell scripts and modules as text, extracts synopsis and version
    from comment-based help, and replaces only the marked README index.
    Does not execute any discovered scripts.
.PARAMETER RepositoryRoot
    Root folder of the checked-out repository; defaults to two levels above this file.
.EXAMPLE
    .\Update-ScriptIndex.ps1
.NOTES
    Version: 1.0
.OUTPUTS
    Updated README.md when the generated index differs.
#>
[CmdletBinding()]
param([string]$RepositoryRoot = (Join-Path $PSScriptRoot '..\..'))
$ErrorActionPreference = 'Stop'
$RepositoryRoot = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$ReadmePath = Join-Path $RepositoryRoot 'README.md'
if (-not (Test-Path -LiteralPath $ReadmePath -PathType Leaf)) { throw 'Root README.md not found.' }
$StartMarker = '<!-- SCRIPT-INDEX:START -->'
$EndMarker = '<!-- SCRIPT-INDEX:END -->'
$Scripts = @(Get-ChildItem -LiteralPath (Join-Path $RepositoryRoot 'PowerShell') -Recurse -File |
    Where-Object { $_.Extension -in @('.ps1', '.psm1') } | Sort-Object FullName)
$Rows = @()
foreach ($File in $Scripts) {
    $Relative = $File.FullName.Substring($RepositoryRoot.TrimEnd([char]'\').Length + 1).Replace('\','/')
    $Category = Split-Path (Split-Path $Relative -Parent) -Leaf
    $Content = Get-Content -LiteralPath $File.FullName -Raw
    $Synopsis = 'No synopsis provided'
    $Version = 'Not specified'
    $HelpMatch = [regex]::Match($Content, '(?s)<#(.*?)#>')
    if ($HelpMatch.Success) {
        $Help = $HelpMatch.Groups[1].Value
        $SynopsisMatch = [regex]::Match($Help, '(?ms)^\s*\.SYNOPSIS\s*\r?\n\s*(.+?)\s*$')
        if ($SynopsisMatch.Success) { $Synopsis = $SynopsisMatch.Groups[1].Value.Trim() }
        $VersionMatch = [regex]::Match($Help, '(?im)^\s*Version\s*:\s*(\S+)')
        if ($VersionMatch.Success) { $Version = $VersionMatch.Groups[1].Value.Trim() }
    }
    $Synopsis = $Synopsis.Replace('|', '\|').Replace('`', "'")
    $Version = $Version.Replace('|', '\|')
    $Rows += [pscustomobject]@{ Category=$Category; Path=$Relative; Name=$File.Name; Synopsis=$Synopsis; Version=$Version }
}
$Lines = @($StartMarker, '## Script Directory', '', 'Automatically generated from PowerShell comment-based help. Do not edit this section manually.', '')
foreach ($Group in ($Rows | Group-Object Category | Sort-Object Name)) {
    $Lines += '### ' + $Group.Name
    $Lines += ''
    $Lines += '| Script | Version | Description |'
    $Lines += '| --- | --- | --- |'
    foreach ($Entry in ($Group.Group | Sort-Object Name)) {
        $Lines += '| [' + $Entry.Name + '](' + $Entry.Path + ') | ' + $Entry.Version + ' | ' + $Entry.Synopsis + ' |'
    }
    $Lines += ''
}
$Lines += $EndMarker
$Generated = $Lines -join "`n"
$Original = Get-Content -LiteralPath $ReadmePath -Raw
$Pattern = '(?s)' + [regex]::Escape($StartMarker) + '.*?' + [regex]::Escape($EndMarker)
if ([regex]::IsMatch($Original, $Pattern)) {
    $Updated = [regex]::Replace($Original, $Pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $Generated })
} else {
    $Updated = $Original.TrimEnd() + "`n`n" + $Generated + "`n"
}
if ($Updated -cne $Original) {
    [System.IO.File]::WriteAllText($ReadmePath, $Updated, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host 'README.md script index updated.'
} else { Write-Host 'Script index already up to date.' }
