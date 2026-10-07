@{
    RootModule           = 'TaffarelJr.Git.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = '9900294e-62ad-43c9-9648-dd7e8e478e6c'
    Author               = 'RJ Hollberg'
    CompanyName          = 'RJ Hollberg'
    Copyright            = '(c) 2026 RJ Hollberg.'
    Description          = 'Scripts git from PowerShell: commands for the everyday work of a repository that return objects, never wait for an editor or a prompt, and support -WhatIf wherever they change something.'
    PowerShellVersion    = '7.4'
    CompatiblePSEditions = @('Core')

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
            Tags         = @(
                'Git', 'VersionControl', 'CLI', 'DevOps', 'Branch', 'Commit', 'Repository', 'Tag', 'PSEdition_Core'
            )
            ProjectUri   = 'https://github.com/TaffarelJr/powershell-modules'
            LicenseUri   = 'https://github.com/TaffarelJr/powershell-modules/blob/main/LICENSE'
            ReleaseNotes = 'https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Git/CHANGELOG.md'
        }
    }
}
