@{
    RootModule        = 'TaffarelJr.Git.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = '9900294e-62ad-43c9-9648-dd7e8e478e6c'
    Author            = 'TaffarelJr'
    CompanyName       = 'TaffarelJr'
    Copyright         = '(c) TaffarelJr.'
    Description       = 'Wraps the git CLI for everyday scripting: repository state, branches, remotes, staging and committing, push/pull, history and comparisons, tags, merging, conflict resolution, rebasing, stashing, and config - every call going through one private process-invocation core.'
    PowerShellVersion = '7.0'

    RequiredModules   = @(
        @{ ModuleName = 'TaffarelJr.ProcessInvocation'; ModuleVersion = '0.1.0' }
    )

    FunctionsToExport = @(
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
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData       = @{
        PSData = @{
            Tags         = @('Git', 'VersionControl', 'CLI', 'DevOps')
            ProjectUri   = 'https://github.com/TaffarelJr/powershell-modules'
            ReleaseNotes = 'See CHANGELOG.md.'
        }
    }
}
