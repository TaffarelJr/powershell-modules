#Requires -Version 7.4

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

foreach ($required in 'TaffarelJr.ProcessInvocation') {
    $loaded = Get-Module -Name $required
    if (-not $loaded) {
        throw "$required must be loaded before TaffarelJr.Git."
    }

    Import-Module -ModuleInfo $loaded -ErrorAction Stop
}

foreach ($file in Get-ChildItem -LiteralPath $PSScriptRoot/Private, $PSScriptRoot/Public -Filter *.ps1) {
    . $file.FullName
}

Export-ModuleMember -Function @(
    'Add-GitChange'
    'Compare-GitBranch'
    'Copy-GitRepository'
    'Get-GitBranch'
    'Get-GitCherry'
    'Get-GitCommit'
    'Get-GitConfig'
    'Get-GitConflict'
    'Get-GitDefaultBranch'
    'Get-GitDiff'
    'Get-GitDirectory'
    'Get-GitLog'
    'Get-GitMergeBase'
    'Get-GitRemote'
    'Get-GitRename'
    'Get-GitRepositoryRoot'
    'Get-GitRootCommit'
    'Get-GitStash'
    'Get-GitStatus'
    'Get-GitTag'
    'Merge-GitBranch'
    'Move-GitFile'
    'New-GitBranch'
    'New-GitCommit'
    'New-GitTag'
    'Push-GitCommit'
    'Remove-GitBranch'
    'Remove-GitFile'
    'Remove-GitRemote'
    'Remove-GitTag'
    'Reset-GitBranch'
    'Resolve-GitConflict'
    'Resolve-GitRef'
    'Restore-GitStash'
    'Resume-GitRebase'
    'Save-GitStash'
    'Set-GitConfig'
    'Set-GitRemote'
    'Start-GitRebase'
    'Stop-GitRebase'
    'Switch-GitBranch'
    'Sync-GitRemote'
    'Test-GitAncestor'
    'Test-GitChange'
    'Test-GitPath'
    'Test-GitRebaseInProgress'
    'Test-GitRepository'
    'Update-GitBranch'
)
