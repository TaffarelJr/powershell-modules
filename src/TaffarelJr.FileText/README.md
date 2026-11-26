# TaffarelJr.FileText

Reads and writes text files,
for scripts that rewrite text without disturbing it:
the line ending a piece of text uses,
the encoding a file is in, from its byte order mark,
a file's content, encoding, and line ending together,
text written back the way the file already was,
a token replaced in a file's content,
and a token replaced across a folder's contents and names.

Part of the [powershell-modules] collection.

## Install

```powershell
Install-PSResource -Name TaffarelJr.FileText
```

Requires PowerShell 7.6 or later.

## Usage

```powershell
Import-Module TaffarelJr.FileText

(Get-LineEnding -Content "one`r`ntwo`r`n") -eq "`r`n"
(Get-FileEncoding -Path ./README.md).WebName

Get-ChildItem -File -Filter *.cs | Get-FileEncoding | ForEach-Object WebName

$file = Read-TextFile -Path ./README.md
$file.Content.Length
$file.Encoding.WebName
$file.LineEnding -eq "`r`n"

Write-TextFile -Path ./README.md -Content ($file.Content -replace 'hi', 'bye')
(Read-TextFile -Path ./README.md).Content.Length
(Get-FileEncoding -Path ./README.md).GetPreamble().Length

Update-FileToken -Path ./README.md -From 'bye' -To 'hello'
(Read-TextFile -Path ./README.md).Content.Length

# True
# utf-8
# utf-16
# utf-8
# 4
# utf-8
# True
# 5
# 3
# True
# 7
```

`Get-LineEnding` returns the line ending a piece of text already uses,
so a rewrite can keep it.
It returns `"`r`n"` or `"`n"`, whichever the text has more of,
and `"`r`n"` when the two are equal.
Text with no line ending at all gets this process's own default.

`Get-FileEncoding` returns the encoding a file is written in,
read from the byte order mark it starts with,
as a `System.Text.Encoding` object.
UTF-8, UTF-16, and UTF-32 marks are recognized,
in both byte orders where there is a choice.
A file with no mark is UTF-8 without one.

`Read-TextFile` returns an object with the file's `Content`,
its `Encoding`, and its `LineEnding`.
The content comes back without the byte order mark,
so what is read can be put back the way it was read.
A file with no mark that is not valid UTF-8,
such as one in Windows-1252, is refused;
`-Encoding` says what to read it as:

```powershell
$windows1252 = [Text.Encoding]::GetEncoding(1252)
$file = Read-TextFile -Path ./legacy.txt -Encoding $windows1252
```

`Write-TextFile` writes text over a file
in the encoding the file already has, byte order mark included.
`-Content` is written exactly as given.
`-Line` takes lines,
joins them with the line ending the file already uses,
and ends the file with one:

```powershell
Write-TextFile -Path ./notes.txt -Line 'first', 'second'
Write-TextFile -Path ./notes.txt -Content $file.Content -Encoding $file.Encoding
```

A file that does not exist yet is UTF-8 without a mark,
with this process's line ending,
unless `-LikeFilePath` names a sibling to copy both from.
`-CreateDirectory` makes the folders on the way,
and `-Encoding` writes in an encoding of its own choosing.

`Update-FileToken` replaces a token in one file's content,
in the encoding and with the line endings the file already has,
and returns whether it rewrote the file:

```powershell
Update-FileToken -Path ./Program.cs -From 'OldName' -To 'NewName'

Get-ChildItem -File -Filter *.cs -Recurse |
    Update-FileToken -From 'OldName' -To 'NewName'
```

The match is literal and case-sensitive,
and every occurrence is replaced.
A file without the token is left alone, whatever it holds.

`Rename-Token` does the same for a whole folder:
it replaces a token in the content of every file under it,
then in every file and folder name.
It returns how many files it edited and how many names it renamed:

```powershell
$result = Rename-Token -Path ./MyProject -From 'Placeholder' -To 'MyProject'
$result.FilesEdited
$result.PathsRenamed
$result.Warning.Count

Rename-Token -Path ./MyProject -From 'Placeholder' -To 'MyProject' -WhatIf
```

It skips `.git`, `bin`, `node_modules`, and `obj` unless `-Exclude` says otherwise,
and does not read the content of files with extensions such as `.png`,
`.zip`, and `.exe`, which `-SkipExtension` lists.
The folder given keeps its own name.

## Good to know

- `Get-FileEncoding` reads only the first few bytes of a file,
  so a large file costs no more than a small one.
  `Read-TextFile` reads the whole file once.
- `Read-TextFile` decodes strictly.
  Text that is not valid in its encoding throws,
  naming the file,
  rather than coming back with replacement characters
  that a rewrite would make permanent.
  A byte order mark still decides over `-Encoding`.
- `-Encoding` takes a `System.Text.Encoding` object,
  such as `[Text.Encoding]::GetEncoding(1252)`,
  not a name such as `utf8`.
  The `Encoding` that comes back has no mark of its own
  when the file had none.
- `Write-TextFile` encodes all the text before it opens the file,
  so text the encoding cannot hold throws
  and leaves an existing file as it was.
  It writes in place,
  so a hidden file can be written and stays hidden.
  A file another program holds open,
  a read-only file,
  and a folder that is missing are named in the error with the reason.
- Writing over a file with no byte order mark that is not valid UTF-8
  throws unless `-Encoding` says what to write,
  rather than turning the file into UTF-8.
- `-Line` ends the file with one line ending,
  turns every break inside a line into that ending,
  and writes nothing at all for no lines.
- `-WhatIf` and `-Confirm` apply to `Write-TextFile`,
  also when it is called from a function in another module
  that was run with them.
  `-Verbose` names the file, its size, and its encoding, never its text.
- `Update-FileToken` declines binary content.
  A file whose first 8 KB hold a NUL is never decoded as text:
  its bytes are searched for the token as UTF-8, UTF-16, and UTF-32,
  and a file that holds it is left as it was, with a warning.
  UTF-16 or UTF-32 text with no byte order mark looks the same,
  and is declined the same way.
- `Update-FileToken` throws for text that holds the token
  but is not valid in its encoding,
  naming the file and leaving it as it was.
  Text without the token is never read that closely.
- `Update-FileToken` returns one answer for each file,
  and nothing under `-WhatIf` or for a file declined at a `-Confirm` prompt.
  `-WhatIf` and `-Confirm` name a file only once it is known to hold the token.
  A failing file stops the pipeline,
  so files after it are not touched and files before it stay updated.
- The token appears in the warning
  and in `-WhatIf`, `-Confirm`, and `-Verbose` text,
  so a secret should not be given as the token
  where that output is kept.
  The replacement is never shown.
- `Rename-Token` changes contents first, then names, longest path first,
  so renaming a folder never makes the path of something inside it stale.
  It does not stop at the first failure:
  it finishes the tree, then throws once,
  naming every file and every rename it could not do,
  so a tree is never left half one name and half the other without saying so.
- `Rename-Token` refuses before it changes anything
  a replacement that no file name can hold,
  and one that contains the token, such as `Foo` to `FooBar`,
  because running it again would rename the result once more;
  `-Force` goes ahead anyway.
  On Windows it also refuses a replacement that would make a name
  older Windows and many Windows tools treat as a device, such as `CON`,
  or end in a dot or a space.
- `Rename-Token` never follows a symbolic link or a junction:
  the link's own name is renamed,
  but nothing behind it is read, written, or listed.
  A link whose target holds the token is named in `Warning`
  to be re-pointed by hand,
  as is a folder that could not be listed and a file with binary content
  that holds the token.
  A hard link is an ordinary file and is edited.
- `Rename-Token` and `Update-FileToken` decline binary content the same way.
- The token and the new names appear in `Rename-Token`'s
  `-WhatIf`, `-Confirm`, and `-Verbose` text and in its errors,
  so a secret should not be given where that output is kept.
- A file in a legacy encoding such as Windows-1252 has no mark to read,
  so it is reported as UTF-8,
  and the encoding returned throws when it is asked to decode that file.
- The marks overlap in one place:
  `FF FE 00 00` starts both UTF-32 little endian text
  and UTF-16 little endian text whose first character is U+0000.
  It is read as UTF-32.
- The encoding returned throws on bytes or characters it cannot map,
  rather than substituting one.
- `Get-FileEncoding` and `Read-TextFile` take path strings,
  `Resolve-Path` output,
  and files from `Get-ChildItem` piped in.
  A relative path is relative to PowerShell's location,
  not the process's.
  A folder in the pipeline throws and stops it,
  so list with `Get-ChildItem -File`.
- A path on a drive that is not the file system,
  such as `Env:` or `Variable:`, is refused.
- A bare CR, the classic Mac OS ending, is not counted by `Get-LineEnding`.

Every function ships full comment-based help -
run `Get-Help <FunctionName> -Full` for its parameters and examples.

## Name collisions

Another module may export a command with the same name as one of this module's,
and the last one imported wins.
Call it module-qualified (`TaffarelJr.FileText\<Command>`)
or import this module with `-Prefix`.

<!-- Public URIs (alphabetical) -->

[powershell-modules]: https://github.com/TaffarelJr/powershell-modules
