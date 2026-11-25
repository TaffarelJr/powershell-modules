# TaffarelJr.FileText

Reads what a text file is written in,
for scripts that rewrite text without disturbing it:
the line ending a piece of text uses,
and the encoding a file is in, from its byte order mark.

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

# True
# utf-8
# utf-16
# utf-8
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

## Good to know

- `Get-FileEncoding` reads only the first few bytes of a file,
  so a large file costs no more than a small one.
- A file in a legacy encoding such as Windows-1252 has no mark to read,
  so it is reported as UTF-8,
  and the encoding returned throws when it is asked to decode that file.
- The marks overlap in one place:
  `FF FE 00 00` starts both UTF-32 little endian text
  and UTF-16 little endian text whose first character is U+0000.
  It is read as UTF-32.
- The encoding returned throws on bytes or characters it cannot map,
  rather than substituting one.
- `Get-FileEncoding` takes path strings,
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
