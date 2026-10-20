# loup-cmd-dir

The Windows `dir` command recreated in [Loup](https://code-craft.ai/references/loup):
list directory contents in the Windows format, with cmd's switches,
wildcards, `\` paths, messages and ERRORLEVELs, on Linux.

Part of the **loup-cmd** series of example applications: classic Linux and
Windows commands, and projects for each Loup execution mode, each in its own
repository under [myronccai](https://github.com/myronccai?tab=repositories&q=loup-cmd).
This one is `host.dual` Loup built as a native binary. It uses the shared
Windows code in [`source/win/`](source/win/) (switch parser, wildcard
matcher, path helpers, messages), copied from
[loup-cmd-type](https://github.com/myronccai/loup-cmd-type).

## Requirements

- Loup 1.26.0 or later:

  ```sh
  curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.sh | sh
  ```

- `make`, and `clang` 17 or later for the native build.

## Usage

```sh
make build                     # native binary: build/dir
make ci                        # check, unit tests, build, end-to-end tests
make run ARGS="/W source"      # run from source with loup run
```

Quote operands that contain `\`, `*` or `?` so that the Linux shell passes
them through: cmd does not expand wildcards, the command does.

```text
$ build/dir demo

 Directory of \home\myron\repos\ccai-examples\loup-cmd-dir\build\demo

                        <DIR>          .
                        <DIR>          ..
                                    16 hello.txt
                        <DIR>          logs
                                    11 Makefile
                                    13 notes.txt
                                48,213 photo.jpg
                        <DIR>          src
               4 File(s)         48,253 bytes
               4 Dir(s)
$ build/dir /W demo

 Directory of \home\myron\repos\ccai-examples\loup-cmd-dir\build\demo

[.]       [..]      hello.txt [logs]    Makefile  notes.txt photo.jpg 
[src]     
               4 File(s)         48,253 bytes
               4 Dir(s)
$ build/dir /B /O-S demo
photo.jpg
hello.txt
notes.txt
Makefile
logs
src
$ build/dir /S /B 'demo\*.log'
\home\myron\repos\ccai-examples\loup-cmd-dir\build\demo\logs\app.log
\home\myron\repos\ccai-examples\loup-cmd-dir\build\demo\logs\old.LOG
$ build/dir /S 'demo\*.txt' 'demo\*.c'

 Directory of \home\myron\repos\ccai-examples\loup-cmd-dir\build\demo

                                    16 hello.txt
                                    13 notes.txt
               2 File(s)             29 bytes

 Directory of \home\myron\repos\ccai-examples\loup-cmd-dir\build\demo\src

                                    29 main.c
               1 File(s)             29 bytes

     Total Files Listed:
               3 File(s)             58 bytes
               0 Dir(s)
$ build/dir /AD /OE demo

 Directory of \home\myron\repos\ccai-examples\loup-cmd-dir\build\demo

                        <DIR>          .
                        <DIR>          ..
                        <DIR>          logs
                        <DIR>          src
               0 File(s)              0 bytes
               4 Dir(s)
$ build/dir 'demo\*.none'; echo "ERRORLEVEL $?"

 Directory of \home\myron\repos\ccai-examples\loup-cmd-dir\build\demo

File Not Found
ERRORLEVEL 1
$ build/dir 'demo\nodir\x.txt'
The system cannot find the path specified.
$ build/dir /A:Z demo
Parameter format not correct - "Z".
$ build/dir --version
dir (loup-cmd-dir) 0.1.0
```

The date and time columns are blank: Loup 1.26.0 has no `stat()` (see
below). Everything else keeps Windows' columns: sizes end in column 38,
names start in column 40, and the summary numbers end in column 39.

## Switches

| Switch | Effect |
|---|---|
| `/A[[:]attrs]` | only entries with these attributes: `D` directories, `-D` files (`R H A S I L O` are accepted; no entry has them). `/A` alone: everything |
| `/B` | bare format: names only; with `/S`, full paths |
| `/C`, `/-C` | thousands separator in sizes and counts (default on) |
| `/D` | wide format sorted down the columns |
| `/L` | lower-case names |
| `/O[[:]order]` | sort: `N` name, `E` extension, `S` size, `G` directories first, `-` reverses the next key; `D` (date) has no effect. `/O` alone is `/OGN` |
| `/S` | this directory and every subdirectory, with a `Total Files Listed:` summary |
| `/W` | wide format: names in columns, `[directories]` in brackets; the width is `$COLUMNS` or 80 |
| `/N`, `/P`, `/Q`, `/R`, `/T[[:]C\|A\|W]`, `/X`, `/4` | accepted, no effect |
| `/?` | a short help text |

Switches start with `/` or `-`, in any case (`/s`, `-S`), anywhere on the
command line; values attach as `/A:D` or `/AD`, and `/S/B` is `/S /B`. A
`/X` that is not one of dir's switches is a path (`dir /tmp`), and `--`
ends switch parsing. `--help` and `--version` work as the only argument.

Operands: a directory lists its contents; a file name or a pattern lists
the matching entries of its directory. Wildcards `*` and `?` in the last
component follow Windows rules (`*.*` and `*` match everything, also `.`
and `..`; `*.` matches names without an extension), and names match without
regard to case. Consecutive operands in the same directory are listed in
one block; operands in different directories get a block each and a
`Total Files Listed:` summary.

Exit status (ERRORLEVEL): `0` if every operand listed something, `1` if any
found nothing, named a missing directory, or a switch value was invalid.

## Differences from the original

- **No dates or times**: Loup 1.26.0 has no `stat()`, so the date and time
  columns are blank, `/T` and `/OD` have no effect and `/4` has nothing to
  change.
- **No free space**: the `Dir(s)` line ends after `Dir(s)`; Windows adds
  `N bytes free`, which cannot be queried.
- **No volume lines** (` Volume in drive C has no label.`, the serial
  number): Linux has no drive letters. The output starts with the blank line
  that precedes ` Directory of`, and paths have no drive (`\home\me`).
- **Attributes**: only "directory" is known. Nothing is hidden or system, so
  the default listing shows dot-files and `/AH` finds nothing; `/A-H` shows
  everything. Symbolic links are listed as what they point to (no
  `<SYMLINK>`/`<JUNCTION>`), and dangling ones are skipped.
- **Sizes are read**: each file is read to learn its size (slow for huge
  files; skipped with `/B` unless sorting by size). An unreadable file
  stops dir with the toolchain's `IoError` message, which Loup 1.26.0
  cannot catch natively.
- `/P` (pause), `/Q` (owner), `/R` (streams), `/X` (short names) and `/N`
  are accepted and ignored; the `DIRCMD` variable is not read, and the only
  negated switch is `/-C`.
- An unknown switch is a path (the shared Windows convention), so `dir /z`
  lists `z` in `/` instead of printing `Invalid switch - "z".`
- `.` and `..` always come first, also with `/O-N`. Operands share a block
  only when they are consecutive and name the same directory.
- `/?` prints a short help text of this recreation, not Windows' own.
- Messages end with LF, not CRLF. `--help` and `--version` are series
  conventions.

## Layout

```text
source/main.loup               # entry point
source/appinfo.loup            # name, version, exit statuses
source/cli/args.loup           # dir's switches via win.switches; /A /O /T values
source/cli/usage.loup          # /? and --version text
source/cli/app.loup            # run(): parse, dispatch, exit status
source/commands/entries.loup   # Entry, the /A filter, the /O sort (stable merge sort)
source/commands/format.loup    # columns, wide format, header and summary lines
source/commands/dir.loup       # operands to blocks, collecting entries, render(), run_dir()
source/win/                    # shared Windows code: switches, wildcards, paths, messages
tests/*_test.loup              # unit tests (make test)
tests/e2e.sh                   # end-to-end tests of build/dir (make e2e)
specs/dir/                     # requirements, design, tasks
```

[AGENTS.md](AGENTS.md) has every build and test command and the conventions
for changing the code.
