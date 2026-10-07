# Changelog

The format follows [Keep a Changelog][changelog], and the module follows
[Semantic Versioning][semver].

## [Unreleased]

### Added

- Initial release: repository state (`Test-GitRepository`,
  `Get-GitRepositoryRoot`, `Get-GitDirectory`, `Get-GitBranch`,
  `Get-GitDefaultBranch`, `Get-GitStatus`, `Resolve-GitRef`,
  `Get-GitRootCommit`); branches (`New-GitBranch`, `Switch-GitBranch`,
  `Remove-GitBranch`); remotes (`Get-GitRemote`, `Set-GitRemote`,
  `Remove-GitRemote`, `Sync-GitRemote`); staging and committing
  (`Add-GitChange`, `New-GitCommit`, `Test-GitChange`, `Move-GitFile`,
  `Remove-GitFile`, `Test-GitPath`); push and pull (`Push-GitCommit`,
  `Update-GitBranch`); history and comparison (`Get-GitLog`, `Get-GitCommit`,
  `Get-GitDiff`, `Get-GitRename`, `Get-GitConflict`, `Get-GitMergeBase`,
  `Test-GitAncestor`, `Compare-GitBranch`, `Get-GitCherry`); tags (`Get-GitTag`,
  `New-GitTag`, `Remove-GitTag`); merging (`Merge-GitBranch`,
  `Resolve-GitConflict`); rebasing (`Start-GitRebase`,
  `Test-GitRebaseInProgress`, `Resume-GitRebase`, `Stop-GitRebase`); stashing
  (`Save-GitStash`, `Restore-GitStash`, `Get-GitStash`); resetting
  (`Reset-GitBranch`); config (`Get-GitConfig`, `Set-GitConfig`); and cloning
  (`Copy-GitRepository`). Every function that changes something supports
  `-WhatIf` and `-Confirm`. With `-Verbose`, each `git` command line a function
  runs goes to the verbose stream, with the credential a URL carries hidden;
  `Set-GitConfig` hides the value it writes from every message and from
  `-Verbose`.
- `Update-GitBranch -FastForwardOnly`, which only moves the branch forward and
  throws for one that has diverged.

<!-- Public URIs (alphabetical) -->

[changelog]: https://keepachangelog.com/en/1.1.0/
[semver]: https://semver.org/spec/v2.0.0.html
