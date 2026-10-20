# Requirements: dir

## Introduction

`dir` is the cmd.exe built-in that lists the files and subdirectories of a
directory. This repository recreates it in Loup for Linux, keeping Windows'
listing layout, switches, operand syntax (`\` separators, `*` and `?`
wildcards expanded by the command itself), messages and ERRORLEVELs. It
uses the shared Windows code in `source/win/` (copied from loup-cmd-type).

Loup 1.26.0 has no `stat()` (roadmap constraint T1): there are no dates or
times, sizes come from reading the files, and the only attribute that can
be known is "directory".

## Requirements

### Requirement 1: The listing

**User Story:** As a cmd user, I want `dir` to show a directory the way
Windows does, so that what I read and what scripts parse looks familiar.

#### Acceptance Criteria

1. WHEN dir is run without operands, THE program SHALL list the current
   directory: a blank line, ` Directory of PATH`, a blank line, one line
   per entry, a `File(s)` line and a `Dir(s)` line, and exit 0.
2. THE program SHALL print PATH as the absolute directory with `\`
   separators (`\home\me\demo`).
3. THE program SHALL lay entry lines out in Windows' columns: the date and
   time columns (20 characters) left blank, four spaces, `<DIR>` padded to
   14 characters or the size right-aligned in 14, a space and the name.
4. THE program SHALL list `.` and `..` first (except in the root directory),
   then the entries in NTFS name order (case-insensitive).
5. THE `File(s)` line SHALL be `%16s File(s) %14s bytes` and the `Dir(s)`
   line `%16s Dir(s)`, with numbers grouped by `,` (thousands).
6. WHEN an operand is a directory, THE program SHALL list its contents; WHEN
   it is a file or a pattern, THE program SHALL list the matching entries of
   its directory.
7. WHEN consecutive operands name the same directory, THE program SHALL list
   them in one block; WHEN more than one block is listed, THE program SHALL
   end with `     Total Files Listed:`, the total `File(s)` line and the
   `Dir(s)` line.

### Requirement 2: Wildcards and names

**User Story:** As a cmd user, I want `dir *.txt` to work, since cmd does
not expand wildcards for me.

#### Acceptance Criteria

1. THE program SHALL match names with Windows rules (shared `wild_match`),
   ignoring case, for wildcard and literal names alike.
2. THE program SHALL accept `\` and `/` as separators in operands.

### Requirement 3: Switches

**User Story:** As a cmd user, I want dir's switches.

#### Acceptance Criteria

1. `/B` SHALL print names only (no `.`, `..`, header or summary); with `/S`,
   full paths.
2. `/S` SHALL list the directory and every subdirectory (pre-order, sorted),
   showing only directories with matching entries, and end with the
   `Total Files Listed:` summary.
3. `/A[[:]attrs]` SHALL filter by attributes: `D` directories, `-D` files;
   the letters `R H A S I L O` SHALL be accepted, and no entry has them.
   `/A` alone SHALL show every entry.
4. `/O[[:]order]` SHALL sort by `N` name, `E` extension, `S` size, `G`
   directories first, each reversible with `-`; `D` SHALL be accepted and
   have no effect. `/O` alone SHALL mean `GN`. Ties keep name order.
5. `/W` SHALL print names in columns, directories in brackets; `/D` SHALL
   do the same sorted down the columns. The width SHALL be `$COLUMNS` or 80.
6. `/L` SHALL print names in lower case.
7. `/-C` SHALL turn off the thousands separator; `/C` turns it back on.
8. `/N`, `/P`, `/Q`, `/R`, `/T[[:]field]`, `/X`, `/4` SHALL be accepted and
   have no effect.
9. A `/X` that is not one of these switches SHALL be an operand (a path).
10. WHEN `/?` appears, THE program SHALL print a short help text (in its own words) and exit 0;
    `--help` and `--version` alone SHALL print the help and
    `dir (loup-cmd-dir) 0.1.0`.

### Requirement 4: Errors

**User Story:** As a script author, I want Windows' messages and
ERRORLEVELs.

#### Acceptance Criteria

1. WHEN nothing matches in a block, THE program SHALL print the header and
   `File Not Found` (on standard error) and exit 1; with `/S`, only
   `File Not Found` when nothing matches in the whole tree; with `/B`, no
   header.
2. WHEN the directory of an operand does not exist, THE program SHALL print
   `The system cannot find the path specified.` and exit 1.
3. WHEN a wildcard appears in a directory component, THE program SHALL print
   `The filename, directory name, or volume label syntax is incorrect.`
4. WHEN an `/A`, `/O` or `/T` value is not valid, THE program SHALL print
   `Parameter format not correct - "VALUE".` and exit 1.
5. THE program SHALL go on with the next operand after an error.
