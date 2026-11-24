# TaffarelJr.Tally

Tagged counters for PowerShell scripts:
add to a count under any tags you choose,
read the sum of the adds that carry the tags you ask for,
or clear them,
so one add can be totaled along several dimensions at once.

Part of the [powershell-modules] collection.

## Install

```powershell
Install-PSResource -Name TaffarelJr.Tally
```

Requires PowerShell 7.6 or later.

## Usage

```powershell
Import-Module TaffarelJr.Tally

# Counters outlive a re-import, so start from zero
Clear-Tally

Add-Tally 5 -Tag A, B
Add-Tally 3 -Tag A
Add-Tally 1 -Tag B

Get-Tally
Get-Tally -Tag A
Get-Tally -Tag B
Get-Tally -Tag A, B

# Counted under a tag of its own, a run can be read and cleared on its own
Add-Tally -Tag passed, 'run 42'
Get-Tally -Tag 'run 42'
Clear-Tally -Tag 'run 42'
Get-Tally

# 9
# 8
# 6
# 5
# 1
# 9
```

An add is an amount and a set of tags.
`Get-Tally` sums the adds that carry every tag it is given, whatever other tags they carry,
and with no tag it sums them all.
`Clear-Tally` removes the same adds, or every add when it is given no tag.
A tag nothing was added under reads as zero.
`-Tags` works as well as `-Tag`.

## Good to know

- A tag means whatever the caller says:
  a category, a file extension, the id of a run.
  Tags are dimensions to sum along, not identifiers:
  a tag that is different on every add makes every add its own entry in memory,
  and every read looks at every entry.
- The tags of an add are a set.
  Their order, their case, and a repeated tag do not matter.
- A tag is one line with no space at either end.
  A null, empty, or blank tag is refused,
  so a variable that turned out empty cannot read the total or clear everything.
- The counts are kept for the whole process and shared by all its runspaces,
  including those of `ForEach-Object -Parallel`.
  Removing or importing the module again keeps them.
  Only `Clear-Tally` resets them.
- Counts do not pass between processes.
  To carry one over, print it and add it in the other process.
- An add that would take a count past what a `[long]` holds is refused,
  and so is a read whose sum does not fit.
  The count stays as it was.
- None of the commands takes input from the pipeline.

Every function ships full comment-based help -
run `Get-Help <FunctionName> -Full` for its parameters and examples.

## Name collisions

Another module may export a command with the same name as one of this module's,
and the last one imported wins.
Call it module-qualified (`TaffarelJr.Tally\<Command>`)
or import this module with `-Prefix`.

<!-- Public URIs (alphabetical) -->

[powershell-modules]: https://github.com/TaffarelJr/powershell-modules
