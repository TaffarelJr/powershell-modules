# Changelog

## 0.1.0

Initial release: repository state (`Test-GitRepository`,
`Get-GitRepositoryRoot`, `Get-GitDirectory`, `Get-GitBranch`,
`Get-GitDefaultBranch`, `Get-GitStatus`, `Resolve-GitRef`,
`Get-GitRootCommit`); branches (`New-GitBranch`, `Switch-GitBranch`,
`Remove-GitBranch`); remotes (`Get-GitRemote`, `Set-GitRemote`,
`Remove-GitRemote`, `Sync-GitRemote`); staging and committing
(`Add-GitChange`, `New-GitCommit`, `Test-GitChange`, `Move-GitFile`,
`Remove-GitFile`, `Test-GitPath`); push and pull (`Push-GitCommit`,
`Update-GitBranch`); history and comparison (`Get-GitLog`,
`Get-GitCommit`, `Get-GitDiff`, `Get-GitRename`, `Get-GitConflict`,
`Get-GitMergeBase`, `Test-GitAncestor`, `Compare-GitBranch`,
`Get-GitCherry`); tags (`Get-GitTag`, `New-GitTag`, `Remove-GitTag`);
merging (`Merge-GitBranch`, `Resolve-GitConflict`); rebasing
(`Start-GitRebase`, `Test-GitRebaseInProgress`, `Resume-GitRebase`,
`Stop-GitRebase`); stashing (`Save-GitStash`, `Restore-GitStash`,
`Get-GitStash`); resetting (`Reset-GitBranch`); config
(`Get-GitConfig`, `Set-GitConfig`); and cloning
(`Copy-GitRepository`).
