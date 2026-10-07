# TaffarelJr.Git

Wraps the git CLI for everyday scripting: repository state, branches,
remotes, staging and committing, push/pull, history and comparisons,
tags, merging, conflict resolution, rebasing, stashing, resetting,
config, and cloning.
Every call goes through one process-invocation core - never git
directly, never an interactive editor, and never a credential prompt
from git itself.

Part of the [powershell-modules] collection.

## Install

```powershell
Install-PSResource -Name TaffarelJr.Git
```

Requires PowerShell 7.4 or later, and git 2.32 or later.
A repository that git refuses because another user owns it
throws only with git 2.38 or later,
the first to honor `safe.directory` given on the command line;
git 2.35.2 to 2.37 refuse such a repository too,
and it then reads as no repository at all.

## Usage

```powershell
Import-Module TaffarelJr.Git

# stage only the modified files, then commit and push if anything is staged -
# a pipeline that matches nothing stages nothing
Get-GitStatus | Where-Object Status -like '*M*' | Add-GitChange
if (Test-GitChange -Staged) {
    New-GitCommit -Message 'chore: sync generated files'
    Push-GitCommit -SetUpstream
}

# on the default branch, delete the local branches already merged into it,
# never the default branch itself
$current = Get-GitBranch
$default = Get-GitDefaultBranch
$branches = Get-GitBranch -List
$merged = $branches | Where-Object {
    $_ -cne $current -and $_ -cne $default -and (Test-GitAncestor $_ $current)
}
$merged | Remove-GitBranch

# bring the current branch up to its upstream, refusing to merge
# when it has commits of its own
Update-GitBranch -FastForwardOnly
```

Every function that changes something supports `-WhatIf` and `-Confirm`;
with `-WhatIf` it reports what it would do and changes nothing.
It still checks first what it can without changing anything -
that the folder is a repository, that a branch, tag, commit or stash exists,
that a rebase is under way -
so `-WhatIf` throws for a call those checks show would fail.

Every function ships full comment-based help, with examples -
run `Get-Help <FunctionName> -Full` for its parameters and examples,
or `Get-Help <FunctionName> -Online` for this page.

## Good to know

- Nothing git itself asks waits on a person, unless given `-Confirm`.
  git is told to open no editor,
  whatever `GIT_EDITOR`, `core.editor`, or `EDITOR` name;
  to ask for no credential on the console;
  to start no askpass program, whatever `GIT_ASKPASS`, `core.askPass`,
  or `SSH_ASKPASS` name;
  and Git Credential Manager is told never to open a sign-in window.
  A command that needs a credential nothing has stored fails with git's
  own message. A configured credential helper still runs, and can supply
  a stored one. ssh's own prompts - a key passphrase, an unknown host key -
  are ssh's, not git's, and are not covered.
  Nor is gpg's: with `commit.gpgsign` or `tag.gpgsign` set
  and a signing key that has a passphrase,
  gpg's pinentry opens a window to ask for it,
  and the call waits until someone answers.
  An askpass program that hands over a token is not run either;
  supply a credential through a credential helper (`credential.helper`)
  or the URL instead.
- A function that answers a question - `Test-GitChange`, `Test-GitAncestor`,
  `Resolve-GitRef`, `Get-GitBranch`, `Get-GitDefaultBranch` and the like -
  answers only when git gave a clean answer.
  A ref that does not exist where one is required, a config git cannot
  read, a folder that is no repository, or a repository git refuses
  because another user owns it throws, instead of reading as
  "yes", "no", "not set", or "detached".
  Outside a repository, `Get-GitConfig` reads the global and system config,
  and `Test-GitRebaseInProgress` answers `$false`.
- A path handed to a function is literal.
  A bare relative path, such as `src/x.txt`, is relative to the repository
  root, the way `Get-GitStatus`, `Get-GitConflict` and `Get-GitDiff -NameOnly`
  report paths, from whichever folder the call runs in;
  its inner `.` and `..` segments are resolved,
  and one that climbs above the root throws.
  A relative path that starts with `.` or `..`, such as `.\x.txt` or `.`,
  is relative to the folder the call runs in - `-RepoPath`,
  else the current location - the way tab completion writes it;
  and a rooted path with no drive, such as `\x.txt`,
  names the root of that folder's drive, as Windows reads it.
  An absolute path, such as `Get-ChildItem`'s `FullName`, is used as it is.
  `Get-GitRename -Path` takes all three forms too.
  `*`, `?` and `[` are part of a name, never a pattern,
  and a backslash is read as a forward slash.
  A name is matched in its exact case, even where `core.ignorecase` is set,
  so a path typed in another case than the repository's matches nothing.
- `-RepoPath` wins over the variables a git hook sets that select
  a repository or change its view of history - `GIT_DIR`, `GIT_INDEX_FILE`,
  `GIT_WORK_TREE`, `GIT_SHALLOW_FILE`, `GIT_NAMESPACE` and the like -
  and over `GIT_CONFIG`, which points `git config` at another file;
  without `-RepoPath`, git uses them as it would anywhere.
  `Copy-GitRepository` always ignores them, since a new clone is never
  the repository they name.
  Configuration passed through the environment - `GIT_CONFIG_COUNT`,
  `GIT_CONFIG_KEY_0` and `GIT_CONFIG_VALUE_0` for an auth header, say -
  still applies either way.
- A ref, branch, or tag named like a file or folder is still read as a ref,
  and a local branch is compared and pushed by its full name,
  so a tag that shares it is never used in its place.
- A merge, rebase, pull, or stash restore returns `Conflict` and `Paths`:
  `$false` with no paths when it finished,
  `$true` with the conflicted paths when it stopped on a conflict,
  leaving the work paused.
  `Resolve-GitConflict` resolves a path, and `Resume-GitRebase` carries a
  rebase on; `Stop-GitRebase` abandons a rebase, and
  `Reset-GitBranch -Mode Hard` abandons a merge,
  discarding every uncommitted change with it.
  A stash that stopped on a conflict stays in the stash list
  until git's own `git stash drop` removes it.
  Any other failure throws, with git's own message.
- `Update-GitBranch -FastForwardOnly` only moves a branch forward,
  and throws for one that has commits of its own instead of merging.
- A ref, branch, remote, or URL that is blank or starts with `-` is refused:
  git would read a dash as an option,
  and a blank value would silently mean the default.
  So is a blank `-RepoPath`; leave it out for the current folder.
- `Remove-GitBranch`, `Remove-GitTag`, `Remove-GitRemote`, `Remove-GitFile`
  and `Reset-GitBranch -Mode Hard` change things for good,
  and nothing asks for confirmation unless you pass `-Confirm`.
- A user name or password in a URL is shown as `***` in any failure message,
  even one pasted in raw with an `@`, `/` or space in it.
  Where it cannot tell, more is hidden rather than less.
  `host:8080/` before an `@` and a dot-less name, as in `host:8080/pkg@1.0`,
  reads as a port, so a password of digits and a `/` before such a name
  is not hidden; one before a real host name is.
  The same goes for a config key or a remote that carries one, such as
  `url.https://x-access-token:TOKEN@github.com/.insteadOf`,
  in `-WhatIf`, `-Verbose` and every message.
- `Set-GitConfig` hides the value it writes: `-Verbose` and every failure
  message, with the error's target, show `***` in its place.
  A very short value is not hidden; `Get-Help Set-GitConfig` says how short.
- With `-Verbose`, each `git` command line a function runs goes to the
  verbose stream, with its secrets hidden as every message hides them.
- `Save-GitStash` returns whether it created a stash,
  so a script does not restore an older one after saving nothing.
- `Get-GitRepositoryRoot` and `Get-GitDirectory` use the platform's own
  separators.
- A non-ASCII file name comes back as it is on disk,
  not as git's escaped octal.
- Output is git's stdout alone, so a warning on stderr
  cannot end up in a value a function parses.

## Errors

A failing call is a terminating error for that call:
the function stops where it failed,
and `-ErrorAction SilentlyContinue` and `Ignore` neither skip nor hide the error.
It ends the call, not the caller's script,
unless the script sets `$ErrorActionPreference = 'Stop'`
(the `pwsh` shell of GitHub Actions already does)
or catches the error with `try` and `catch`.

A failing record in a pipeline stops the pipeline:
`'merged', 'missing', 'other' | Remove-GitBranch`
deletes `merged`, fails on `missing`, and never reaches `other`.
`Add-GitChange` gathers its input first and stages it at the end,
so a failing record means nothing was staged.
A piped value that fails to bind, such as an empty string,
is the exception: that is PowerShell's own error, not the function's.
It ends the caller's script unless a `try` and `catch` catches it,
and `-ErrorAction SilentlyContinue` or `Ignore`
skips that record without a word.

The error's `FullyQualifiedErrorId` names the exception type
and the commands it passed through,
as in `RuntimeException,Remove-GitBranch` for a branch that is missing,
or `RuntimeException,Invoke-NativeCommand,Add-GitChange`
for a failure of git itself;
most failures share that exception type and the `InvalidOperation` category,
so the message is what says what failed.
PowerShell's default error view quotes the line of the calling script,
so a secret written literally in that line is shown there;
give a secret by variable.

## Name collisions

Other Gallery modules for git export commands with the same names,
and the overlap is broad: [posh-git], [GitAutomation], and [PowerGit]
each share several of this module's names,
from `Get-GitStatus` and `Get-GitBranch` to the rebase commands.
The module imported last wins, silently,
so a profile that loads posh-git changes what `Get-GitStatus` means.
Call a command module-qualified, as `TaffarelJr.Git\Get-GitStatus`,
or import this module with a prefix,
as `Import-Module TaffarelJr.Git -Prefix Tj`,
which names that command `Get-TjGitStatus`.

<!-- Public URIs (alphabetical) -->

[GitAutomation]: https://www.powershellgallery.com/packages/GitAutomation
[posh-git]: https://www.powershellgallery.com/packages/posh-git
[PowerGit]: https://www.powershellgallery.com/packages/PowerGit/0.9.0
[powershell-modules]: https://github.com/TaffarelJr/powershell-modules
