# TaffarelJr.Tally

Tagged counters for PowerShell scripts:
add to the count of each tag you choose,
read every count as a name and a value
to sort, total, show, or hand to another process,
or clear them.

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

# Name       Value
# ----       -----
# (untagged)     0
# A              8
# B              6

# A second dimension goes in the tag
Add-Tally -Tag 'run 42:passed', 'run 42:failed'
Add-Tally 2 -Tag 'run 42:passed'
$run = Get-Tally -Tag 'run 42:passed', 'run 42:failed'

[long]$total = 0
foreach ($pair in $run) { $total += $pair.Value }
$total

# 4
```

Every tag is a counter of its own,
so `Add-Tally 5 -Tag A, B` adds 5 to A and 5 to B.
An add with no tag goes to the default counter, `(untagged)`.
`Get-Tally` returns one object for each counter, with a `Name` and a `Value`:
all of them, the default counter first and the rest sorted,
or only the tags you name, in the order you name them.
A tag nothing was added under is left out.
`-Tags` works as well as `-Tag`.

The results are plain data,
so what to do with them is up to the caller.
With `TaffarelJr.ConsoleOutput` loaded, `Get-Tally | Show-FieldList`
prints them as aligned `name: value` lines.
To ask for A and B together, or for one run,
name the tag that way when adding it, as `run 42:passed` does above.

To hand counts to another process,
print them as JSON in one and merge them in the other:

```powershell
Get-Tally | ConvertTo-Json -Compress
# [{"Name":"(untagged)","Value":0},{"Name":"A","Value":8},{"Name":"B","Value":6}]

$json | ConvertFrom-Json | Add-Tally
```

`Add-Tally` also takes a dictionary of counts,
`Add-Tally -Counts @{ A = 2; B = 3 }`,
or pairs from the pipeline,
such as dictionary entries and the output of `Group-Object -NoElement`.
Each count is added to its counter.

## Good to know

- A tag means whatever the caller says:
  a category, a file extension, the id of a run.
  Tags are dimensions to count along, not identifiers:
  a tag that is different on every add
  makes every add its own counter in memory.
- Names are not case-sensitive,
  and a counter keeps the spelling it was first added with.
  A tag repeated in one call is added to once.
- A tag is one line with no space at either end.
  A null, empty, or blank tag is refused,
  so a variable that turned out empty
  cannot read every counter or clear them all.
- The default counter has the name `(untagged)`,
  and a tag of that name reaches it.
- Counters are independent.
  Clearing a tag does not lower another,
  and no grand total is kept:
  add up the pairs, or add a tag for the total.
- Add up counts as `[long]` values, as the example does.
  `Measure-Object -Sum` returns a `[double]`,
  which loses digits near the top of a `[long]`.
- The counts are kept for the whole process and shared by all its runspaces,
  including those of `ForEach-Object -Parallel`.
  Removing or importing the module again keeps them.
  Only `Clear-Tally` resets them.
- Counts do not pass between processes except by being merged in,
  as above.
- A count is a `[long]`.
  An add that would take any of its counts past that is refused
  and changes none of them.
- A merge takes whole numbers only:
  a fraction, a number written as text,
  or one too big for a `[long]` is refused.
  A dictionary is merged all or nothing;
  pairs piped in are merged one at a time,
  so a bad one stops the merge with the pairs before it already added.
- `Get-Tally -Tag A` returns nothing for a tag that was never added,
  so `@(Get-Tally -Tag A).Count` tells whether it was.
- `Get-Tally | ConvertTo-Json` writes an object, not an array, for one counter,
  and `ConvertFrom-Json | Add-Tally` reads either.

Every function ships full comment-based help -
run `Get-Help <FunctionName> -Full` for its parameters and examples.

## Name collisions

Another module may export a command with the same name as one of this module's,
and the last one imported wins.
Call it module-qualified (`TaffarelJr.Tally\<Command>`)
or import this module with `-Prefix`.

<!-- Public URIs (alphabetical) -->

[powershell-modules]: https://github.com/TaffarelJr/powershell-modules
