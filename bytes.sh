#!/bin/sh
# Richard H. Tingstad
#
# bytes.sh uses POSIX shell utils to be a sort of "sed for binary".
#
# Using `xxd | sed/awk | xxd -r` is cool, but not flexible about byte positions.
#
# Currently, bytes.sh aims at doing a linear pass through the data, replacing matching byte sequences.
#
# It expects buffer_size to be >= any given byte pattern length, and will handle byte patterns one after the other.
# Overlapping or repeating byte patterns is thus not a priority at the moment.
#
# buffer_size is set to 2000 for both input and output.
#
# (Scipt arguments and output buffer size could be restricted by {ARG_MAX}, "Maximum length of argument to the exec functions including environment data"; Minimum Acceptable Value: {_POSIX_ARG_MAX} Value: 4 096 )
set -e

main() {
od -v -A n -t x1 | tr -s ' ' '\n' | awk '
BEGIN {
    for (i = 1; i < ARGC; i++) {
        str = ARGV[i]
        gsub("_", " ", str)
        len = split(str, arg, "=")
        if (len != 2 || ! length(arg[2])) {
            print "Invalid argument: " ARGV[i]
            exit 1
        }
        if (arg[1] ~ /[ a-f0-9]+/)
            replace(arg[1], arg[2])
    }
    for (i = 0; i < 256; i++)
        hex_to_oct[sprintf("%02x", i)] = sprintf("%o", i)

    if (!buffer_size) buffer_size = 2000

    offset = 0
    out_buffer_count = 0
    out = ""
}
/./ {
    input[offset++] = $1

    handle_byte()

    if (offset >= buffer_size) {
        out = out append(input[offset - buffer_size])
        out_buffer_count++
        delete input[offset - buffer_size]
    }
    if (out_buffer_count >= buffer_size) {
        system("printf \"" out "\"")
        out_buffer_count = 0
        out = ""
    }
}
function replace(pattern, replacement) {
    op[commands++] = pattern "," replacement
    if (commands == 1) {
        counter = 0
        pattern_len = split(pattern, src)
        replace_len = split(replacement, dst)
        if (pattern_len != replace_len) {
            printf("ERROR! Lengths differ:\n%s\n%s\n", pattern, replacement)
            finished = 1
            exit 1
        }
    }
}
function handle_byte() {
    if (!finished && update()) {
        if (++counter < commands) {
            split(op[counter], arr, ",")
            pattern_len = split(arr[1], src)
            split(arr[2], dst)
        } else {
            finished = 1
        }
    }
}
function update() {
    start = (offset >= buffer_size) ? offset - buffer_size : offset - pattern_len
    if (start < 0) return 0
    idx = start
    miss = 0
    for (j = 1; j <= pattern_len; j++) {
        if (input[idx++] != src[j] && src[j] != "xx") {
            miss = 1
            break
        }
    }
    if (!miss) {
        idx = start
        for (j = 1; j <= pattern_len; j++) {
            input[idx++] = dst[j]
        }
    }
    return !miss;
}
function append(hex_byte) {
    return "\\" hex_to_oct[hex_byte]
}
END {
    starti = (offset >= buffer_size) ? offset - buffer_size + 1 : 0
    while (--buffer_size >= 0) {
        handle_byte()
    }
    for (i = starti; i < offset && i >= 0; i++) {
        out = out append(input[i])
    }
    system("printf \"" out "\"")
}
' "$@"
}

test() {
    echo "Run tests"

    assert "$(printf 'hello,\nworld!' | main)" \
           "$(printf 'hello,\nworld!')"

    assert "$(printf 'hello, world' | main _65_6c_6c_6f=_6f_77_64_79)" \
                     'howdy, world'

    assert "$(printf '123' | main _31=34)" \
                     '423'

    assert "$(printf '11122233311' | main _31=33 _33=31)" \
                     '31122213311' # only first match replaced

    assert "$(printf '11122233311' | main _32=32 _31=30)" \
                     '11122233301' # "seek"

    assert "$(printf '%2345d' 0 | main)" \
           "$(printf '%2345d' 0)"

    assert "$(printf '%2345d' 0 | main _20_20_30=30_30_39 | cut -c 2340-)" \
                     '   009'

    assert "$(printf '123' | main _xx_32_33=_31_30_33)" \
                     '103' # wildcard

    assert "$(seq 1050 3960 | main _32_30_30_30=_32_6f_6f_6f \
                                   _33_30_30_30=_33_6f_6f_6f)" \
           "$(seq 1050 1999 ; echo 2ooo ; \
              seq 2001 2999 ; echo 3ooo ; seq 3001 3960)"

    echo OK
}
seq() { # [first] last
    last=${2:-$1}
    if [ $# -gt 1 ]; then i=$1; else i=1; fi
    while [ $i -le $last ]; do
        printf '%d\n' $i
        i=$((i + 1))
    done
}
assert() {
    if [ "$1" != "$2" ]; then
        >&2 printf 'ERROR! Expected:\n%s\nbut got:\n%s\n' "$2" "$1"
        exit 1
    fi
}

if [ "$1" = "test" ]; then
    test
else
    main "$@"
fi

