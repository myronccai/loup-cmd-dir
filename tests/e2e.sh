#!/usr/bin/env bash
# End-to-end tests: run the built binary and compare its standard output
# (byte for byte), and where given its standard error, and exit status with
# the expected ones. The cases run inside a fixture tree built under $TMP.
#
# usage: tests/e2e.sh BINARY

set -u
BIN=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0
fail=0

# check_file NAME STATUS EXPECTED_FILE [ARGS...]
# Runs BINARY ARGS... with standard input from the file named by $IN
# (default: /dev/null) and compares standard output with EXPECTED_FILE.
# If $WANT_ERR is set, standard error must equal it too.
check_file() {
    local name=$1 want_status=$2 want_file=$3
    shift 3
    "$BIN" "$@" < "${IN:-/dev/null}" > "$TMP/out" 2> "$TMP/err"
    local status=$?
    local err_ok=1
    if [ -n "${WANT_ERR+set}" ]; then
        printf '%s' "$WANT_ERR" > "$TMP/want_err"
        cmp -s "$TMP/want_err" "$TMP/err" || err_ok=0
    fi
    if [ "$status" -eq "$want_status" ] && cmp -s "$want_file" "$TMP/out" && [ "$err_ok" -eq 1 ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        diff <(od -c "$want_file") <(od -c "$TMP/out") | sed 's/^/    /' | head -20
        if [ "$err_ok" -eq 0 ]; then
            diff <(od -c "$TMP/want_err") <(od -c "$TMP/err") | sed 's/^/    stderr /' | head -20
        fi
        sed 's/^/    stderr: /' "$TMP/err" | head -5
    fi
}

# check NAME STATUS EXPECTED_STDOUT [ARGS...]
# As check_file, with the expected output given as a string. Bash strings
# cannot hold NUL bytes; use check_file for output that contains them.
check() {
    local name=$1 want_status=$2
    printf '%s' "$3" > "$TMP/want"
    shift 3
    check_file "$name" "$want_status" "$TMP/want" "$@"
}

# check_both NAME STATUS EXPECTED_STDOUT EXPECTED_STDERR [ARGS...]
check_both() {
    local name=$1 want_status=$2 want_out=$3
    local WANT_ERR=$4
    shift 4
    check "$name" "$want_status" "$want_out" "$@"
}

# Line builders in Windows' dir layout: the date and time columns (20) are
# blank, then 4 spaces, `<DIR>` padded to 14 or the size right-aligned in
# 14, a space and the name. Summary numbers are right-aligned to column 39.
d()   { printf '%24s<DIR>          %s\n' '' "$1"; }
f()   { printf '%24s%14s %s\n' '' "$1" "$2"; }
fs()  { printf '%16s File(s) %14s bytes\n' "$1" "$2"; }
ds()  { printf '%16s Dir(s)\n' "$1"; }
# hdr: a blank line and ` Directory of X`; the blank line after it is written
# out in each case, since $(...) drops trailing newlines.
hdr() { printf '\n Directory of %s' "$1"; }
tot() { printf '\n     Total Files Listed:\n'; }

# The fixture tree.
W="$TMP/w"
mkdir -p "$W/sub/deep" "$W/empty"
printf 'alpha\n' > "$W/a.txt"
printf 'ab\n' > "$W/ab.txt"
head -c 1234567 /dev/zero > "$W/big.bin"
printf 'x' > "$W/C.TXT"
printf 'readme\n' > "$W/README"
printf 'sub c\n' > "$W/sub/c.txt"
printf 'deep\n' > "$W/sub/deep/d.log"
cd "$W"
unset COLUMNS
# The directory as dir prints it: \tmp\tmp.XXXX\w
WD=${W//\//\\}

nf='File Not Found'

# Help and version.
help_first='List the files and subdirectories of a directory.'
"$BIN" '/?' > "$TMP/help" 2>&1
if [ "$(head -1 "$TMP/help")" = "$help_first" ] && [ "$(wc -l < "$TMP/help")" -eq 16 ]; then
    pass=$((pass + 1))
else
    fail=$((fail + 1)); echo "FAIL: /? help"
fi
check      "--version"          0 $'dir (loup-cmd-dir) 0.1.0\n' --version

# The default listing, written out once in full.
check_both "default listing"    0 "
 Directory of $WD

                        <DIR>          .
                        <DIR>          ..
                                     6 a.txt
                                     3 ab.txt
                             1,234,567 big.bin
                                     1 C.TXT
                        <DIR>          empty
                                     7 README
                        <DIR>          sub
               5 File(s)      1,234,584 bytes
               4 Dir(s)
" ''

listing_sub="$(hdr "$WD\\sub")

$(d .)
$(d ..)
$(f 6 c.txt)
$(d deep)
$(fs 1 6)
$(ds 3)
"
check      "directory operand"  0 "$listing_sub"                sub
check      "trailing backslash" 0 "$listing_sub"                'sub\'
check      "absolute operand"   0 "$listing_sub"                "$W/sub"
check      "dot dot"            0 "$listing_sub"                'sub\deep\..'

# Patterns and files.
check_both "star dot txt"       0 "$(hdr "$WD")

$(f 6 a.txt)
$(f 3 ab.txt)
$(f 1 C.TXT)
$(fs 3 10)
$(ds 0)
" ''                                                            '*.txt'
check      "a file"             0 "$(hdr "$WD\\sub")

$(f 6 c.txt)
$(fs 1 6)
$(ds 0)
"                                                               'sub\c.txt'
check      "any case"           0 "$(hdr "$WD")

$(f 7 README)
$(fs 1 7)
$(ds 0)
"                                                               readme
check      "star dot"           0 "$(hdr "$WD")

$(d .)
$(d ..)
$(d empty)
$(f 7 README)
$(d sub)
$(fs 1 7)
$(ds 4)
"                                                               '*.'
check      "two patterns, one block" 0 "$(hdr "$WD")

$(f 1,234,567 big.bin)
$(f 7 README)
$(fs 2 1,234,574)
$(ds 0)
"                                                               '*.bin' README
check      "two directories"    0 "$(hdr "$WD")

$(f 6 a.txt)
$(fs 1 6)
$(hdr "$WD\\sub")

$(f 6 c.txt)
$(fs 1 6)
$(tot)
$(fs 2 12)
$(ds 0)
"                                                               a.txt 'sub\c.txt'

# Bare format.
check      "/B"                 0 $'a.txt\nab.txt\nbig.bin\nC.TXT\nempty\nREADME\nsub\n' /B
check      "/B lower case"      0 $'a.txt\nab.txt\nbig.bin\nc.txt\nempty\nreadme\nsub\n' /b /l
check      "/S /B"              0 "$WD\\a.txt
$WD\\ab.txt
$WD\\big.bin
$WD\\C.TXT
$WD\\empty
$WD\\README
$WD\\sub
$WD\\sub\\c.txt
$WD\\sub\\deep
$WD\\sub\\deep\\d.log
"                                                               /S /B
check      "/S /B pattern"      0 "$WD\\sub\\deep\\d.log
"                                                               /s/b '*.log'

# Attributes.
check      "/AD"                0 $'empty\nsub\n'               /AD /B
check      "/A:-D"              0 $'a.txt\nab.txt\nbig.bin\nC.TXT\nREADME\n' '/A:-D' /B
check      "/A-H is everything" 0 $'a.txt\nab.txt\nbig.bin\nC.TXT\nempty\nREADME\nsub\n' /A-H /B
check_both "/AH finds nothing"  1 '' "$nf"$'\n'                 /AH /B
check      "/AD listing"        0 "$(hdr "$WD")

$(d .)
$(d ..)
$(d empty)
$(d sub)
$(fs 0 0)
$(ds 4)
"                                                               /ad

# Sort orders.
check      "/O-N"               0 $'sub\nREADME\nempty\nC.TXT\nbig.bin\nab.txt\na.txt\n' /O-N /B
check      "/O is GN"           0 $'empty\nsub\na.txt\nab.txt\nbig.bin\nC.TXT\nREADME\n' /O /B
check      "/O:-G"              0 $'a.txt\nab.txt\nbig.bin\nC.TXT\nREADME\nempty\nsub\n' '/O:-G' /B
check      "/OE"                0 $'empty\nREADME\nsub\nbig.bin\na.txt\nab.txt\nC.TXT\n' /OE /B
check      "/OS"                0 $'empty\nsub\nC.TXT\nab.txt\na.txt\nREADME\nbig.bin\n' /OS /B
check      "/O-S"               0 $'big.bin\nREADME\na.txt\nab.txt\nC.TXT\nempty\nsub\n' /O-S /B
check      "/OG-S listing keeps dots first" 0 "$(hdr "$WD")

$(d .)
$(d ..)
$(d empty)
$(d sub)
$(f 1,234,567 big.bin)
$(f 7 README)
$(f 6 a.txt)
$(f 3 ab.txt)
$(f 1 C.TXT)
$(fs 5 1,234,584)
$(ds 4)
"                                                               /OG-S

# Separators.
check      "/-C"                0 "$(hdr "$WD")

$(f 1234567 big.bin)
$(fs 1 1234567)
$(ds 0)
"                                                               /-C big.bin

# Recursion.
check      "/S"                 0 "$(hdr "$WD")

$(f 6 a.txt)
$(f 3 ab.txt)
$(f 1 C.TXT)
$(fs 3 10)
$(hdr "$WD\\sub")

$(f 6 c.txt)
$(fs 1 6)
$(tot)
$(fs 4 16)
$(ds 0)
"                                                               /S '*.txt'
check      "/S everything"      0 "$(hdr "$WD\\sub")

$(d .)
$(d ..)
$(f 6 c.txt)
$(d deep)
$(fs 1 6)
$(hdr "$WD\\sub\\deep")

$(d .)
$(d ..)
$(f 5 d.log)
$(fs 1 5)
$(tot)
$(fs 2 11)
$(ds 5)
"                                                               /s sub

# Wide formats (80 columns unless $COLUMNS says otherwise).
check      "/W"                 0 "$(hdr "$WD")

[.]     [..]    a.txt   ab.txt  big.bin C.TXT   [empty] README  [sub]   
$(fs 5 1,234,584)
$(ds 4)
"                                                               /W
COLUMNS=40 check "/W in 40 columns" 0 "$(hdr "$WD")

[.]     [..]    a.txt   ab.txt  
big.bin C.TXT   [empty] README  
[sub]   
$(fs 5 1,234,584)
$(ds 4)
"                                                               /W
COLUMNS=40 check "/D in 40 columns" 0 "$(hdr "$WD")

[.]     ab.txt  [empty] 
[..]    big.bin README  
a.txt   C.TXT   [sub]   
$(fs 5 1,234,584)
$(ds 4)
"                                                               /D

# Errors (ERRORLEVEL 1).
check_both "no match"           1 "$(hdr "$WD")

" "$nf"$'\n'                                                    '*.none'
check_both "no match, bare"     1 '' "$nf"$'\n'                 /B nothing
check_both "no match, /S"       1 '' "$nf"$'\n'                 /S '*.none'
check_both "missing directory"  1 '' $'The system cannot find the path specified.\n' 'nodir\x'
check_both "wildcard in directory" 1 '' \
    $'The filename, directory name, or volume label syntax is incorrect.\n' 's*\c.txt'
check_both "bad attribute"      1 '' $'Parameter format not correct - "z".\n' '/a:z'
check_both "bad sort order"     1 '' $'Parameter format not correct - "Q".\n' '/O:Q'
check_both "unknown switch is a path" 1 "$(hdr '\')

" "$nf"$'\n'                                                    /z
check_both "one of two missing" 1 "$(hdr "$WD")

$(f 6 a.txt)
$(fs 1 6)
$(ds 0)
" $'The system cannot find the path specified.\n'               a.txt 'nodir\x'

# The current directory comes from $PWD when it is right, else from `pwd`.
PWD=/ check "wrong PWD"         0 "$(hdr "$WD\\sub\\deep")

$(f 5 d.log)
$(fs 1 5)
$(ds 0)
"                                                               'sub\deep\*.log'

# The root directory has no . and .. entries.
if "$BIN" '\' /AD | grep -q ' \.\.\?$'; then
    fail=$((fail + 1)); echo "FAIL: root without dots"
else
    pass=$((pass + 1))
fi

echo "e2e: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
