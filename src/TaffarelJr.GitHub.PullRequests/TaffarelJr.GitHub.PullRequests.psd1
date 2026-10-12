@{
    RootModule           = 'TaffarelJr.GitHub.PullRequests.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = '3d256949-8a09-4773-aa60-926da8db32ee'
    Author               = 'RJ Hollberg'
    CompanyName          = 'RJ Hollberg'
    Copyright            = '(c) 2026 RJ Hollberg.'
    Description          = 'Works with GitHub pull requests through the GitHub CLI (gh): create, review, comment on, merge, and close them, and read their checks and diffs.'
    PowerShellVersion    = '7.4'
    CompatiblePSEditions = @('Core')

    RequiredModules      = @(
        @{ ModuleName = 'TaffarelJr.GitHub.Core'; ModuleVersion = '0.1.0' }
        @{ ModuleName = 'TaffarelJr.ProcessInvocation'; ModuleVersion = '0.1.0' }
    )

    FunctionsToExport    = @(
        'Add-GitHubPullRequestComment'
        'Close-GitHubPullRequest'
        'Get-GitHubPullRequest'
        'Get-GitHubPullRequestCheck'
        'Get-GitHubPullRequestDiff'
        'Get-GitHubPullRequestStatus'
        'Lock-GitHubPullRequest'
        'Merge-GitHubPullRequest'
        'New-GitHubPullRequest'
        'Open-GitHubPullRequest'
        'Set-GitHubPullRequest'
        'Submit-GitHubPullRequestReview'
        'Switch-GitHubPullRequest'
        'Unlock-GitHubPullRequest'
        'Update-GitHubPullRequestBranch'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()

    PrivateData          = @{
        PSData = @{
            Tags         = @(
                'GitHub'
                'gh'
                'CLI'
                'PullRequest'
                'PullRequests'
                'Merge'
                'Review'
                'Checks'
                'PSEdition_Core'
            )
            ProjectUri   = 'https://github.com/TaffarelJr/powershell-modules'
            LicenseUri   = 'https://github.com/TaffarelJr/powershell-modules/blob/main/LICENSE'
            ReleaseNotes = 'https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.PullRequests/CHANGELOG.md'
        }
    }
}
