# Design: dir

## Overview

`main()` passes `runtime.args()` to `cli.app.run`, which parses them with
the shared switch parser, handles `/?` and `--version`, and calls
`commands.dir.run_dir`. `run_dir` asks `render` for the whole listing as a
list of lines (each marked for standard output or standard error) and an
exit status, prints the lines in order and returns the status.

## Modules

| Module | Contents |
|---|---|
| `source/main.loup` | entry point: `run(runtime.args())` |
| `source/appinfo.loup` | name, version, summary, exit statuses (0 and 1) |
| `source/cli/args.loup` | `Options`, `dir_switches()`, `valid_letters`, `parse_args` |
| `source/cli/usage.loup` | `usage()` (a short help text), `version_line()` |
| `source/cli/app.loup` | `run()`: parse, help/version, run, exceptions to status 1 |
| `source/commands/entries.loup` | `Entry`, `make_entry`, `attr_matches`, `extension_of`, `compare_entries`, `sort_entries` (stable merge sort) |
| `source/commands/format.loup` | `group_digits`, `long_line`, `wide_lines`, `header_lines`, `files_line`, `dirs_line`, `total_header_lines` |
| `source/commands/dir.loup` | `plan_groups`, `absolute_dir`, `collect`, `render`, `current_dir`, `screen_width`, `run_dir` |
| `source/win/` | the shared Windows code: switches, wildcards, paths, messages |

### Switches

`/A`, `/O` and `/T` are declared with `optional_value` and the letters each
accepts, so `/ad` is `/A` with `D` while `/apps` and `/tmp` stay paths.
Values are checked with `valid_letters` (letters, each optionally preceded
by one `-`). The switches are applied in command-line order, so the last
`/A`, `/O`, `/C` or `/-C` wins.

### Planning

`plan_groups` turns operands into groups (directory, patterns, error): an
existing directory gives (dir, `*`); anything else is split at its last
separator into (parent, name). A missing parent is a "path not found"
group; a wildcard in a directory component an "invalid name" group.
Consecutive operands with the same directory share a group, so
`dir *.bin README` is one block.

### Listing

`collect` lists one directory: the names matching any pattern, files and
directories only (dangling symlinks and special files are skipped), through
the `/A` filter, sorted with the shared NTFS order and then by the `/O` keys
(stable), with `.` and `..` in front when they match (not in bare format,
not in `/`). File sizes are read with `readBytes(path).len()`; in bare
format they are only read for `/OS`.

`render` walks the groups (with `/S`, every directory from
`win.wildcard.walk_dirs`), adds a block per directory with entries, counts
files, directories and bytes, and appends the summary: the `Dir(s)` line
after a single block, or `Total Files Listed:` with both lines after
several blocks or with `/S`.

The "Directory of" path is absolute: `$PWD` when its listing equals that of
`.` (Loup has no `getcwd`), else the output of `pwd`; `normalize_absolute`
resolves `.` and `..`.

The wide format follows the classic cmd algorithm: column width = longest
name (directories with brackets) + 1, columns = width / longest, one fewer
if the separating spaces would not fit, every name padded.

## Differences from the original

- No dates or times (no `stat()` in Loup 1.26.0): the date and time columns
  are blank, `/T` and `/OD` have no effect, `/4` has nothing to change.
- No free space: the `Dir(s)` line has no `bytes free` figure.
- No volume lines (` Volume in drive C ...`): there are no drive letters;
  the output starts with the blank line before ` Directory of`.
- Attributes: only `D` can be known. No entry is hidden, system, read-only,
  archive, ... so the default listing shows dot-files and `/AH` finds
  nothing. Symlinks are listed as what they point to (no `<SYMLINK>`,
  `<JUNCTION>`).
- Sizes come from reading each file: slow for very large files, and an
  unreadable file stops dir with the toolchain's `IoError` message.
- Names match without regard to case, also literal ones (`dir A.TXT` lists
  `a.txt`), as Windows does; a directory operand must be spelled exactly.
- `/P`, `/Q`, `/R`, `/X`, `/N` are accepted and ignored; `DIRCMD` is not
  read; `/-W` style negations other than `/-C` do not exist.
- Unknown switches are paths (shared convention): `dir /z` looks for `z` in
  `/` instead of printing `Invalid switch - "z".`
- Messages end with LF; paths are printed with `\`.
- `/?` prints this recreation's own short help text.

## Error handling

Every failure is reported per operand and processing continues; the exit
status is 1 if any operand failed. Bad switch values stop before any
output. An unexpected exception is printed on standard error and gives
status 1.

## Testing

- `tests/args_test.loup`: switch values, last one wins, `/-C`, bad values,
  paths that look like switches, `/?`, `--`.
- `tests/entries_test.loup`: the attribute filter and every sort key.
- `tests/format_test.loup`: digit grouping, column layout, summary lines,
  the wide formats.
- `tests/dir_test.loup`: groups, absolute paths, `collect`, `render` for a
  listing, `/S /B` and the errors.
- `tests/app_test.loup`: exit statuses through `run()`.
- `tests/win_*_test.loup`: the shared Windows code.
- `tests/e2e.sh`: the native binary in a fixture tree under `$TMP`: stdout
  byte for byte, stderr exactly, exit statuses.
