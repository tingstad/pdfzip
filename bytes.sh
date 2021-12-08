#!/bin/sh
set -e

main() {
od -v -A n -t x1 | tr -s ' ' '\n' | awk '
BEGIN {
    for (i = 1; i < ARGC; i++) {
        str = ARGV[i]
        gsub("_", " ", str)
        split(str, arg, "=")
        if (! length(arg[2])) {
            print "Invalid argument: " ARGV[i]
            exit 1
        }
        if (arg[1] ~ /[ a-f0-9]+/)
            replace(arg[1], arg[2])
    }

    if (!buffer_size) buffer_size = 2000

    offset = 0
    out_buffer_count = 0
    out = ""
}
/./ {
    input[offset++] = $1

    handle_byte()

    if (offset >= buffer_size) {
        oct_byte = sprintf("\\%o", "0x" input[offset - buffer_size])
        out = out "\\" oct_byte
        out_buffer_count++
        delete input[offset - buffer_size]
    }
    if (out_buffer_count >= buffer_size) {
        system("printf \"" out "\"")
        out_buffer_count = 0
        out = ""
    }
}
function replace(from, to) {
    op[commands++] = from "," to
    if (commands == 1) {
        counter = 0
        find = from
        write = to
    }
}
function handle_byte() {
    if (!finished && update(find, write)) {
        if (++counter < commands) {
            split(op[counter], arr, ",")
            find = arr[1]
            write = arr[2]
        } else {
            finished = 1
        }
    }
}
function update(pattern, replace) {
    len = split(pattern, src)
    start = (offset >= buffer_size) ? offset - buffer_size : offset - len
    if (start < 0) return
    idx = start
    miss = 0
    for (j = 1; j <= len; j++) {
        if (input[idx++] != src[j]) {
            miss = 1
            break
        }
    }
    if (!miss) {
        split(replace, dst)
        idx = start
        for (j = 1; j <= len; j++) {
            input[idx++] = dst[j]
        }
    }
    return !miss;
}
END {
    starti = (offset >= buffer_size) ? offset - buffer_size + 1 : 0
    while (--buffer_size >= 0) {
        handle_byte()
    }
    for (i = starti; i < offset && i >= 0; i++) {
        oct_byte = sprintf("\\%o", "0x" input[i])
        out = out "\\" oct_byte
    }
    system("printf \"" out "\"")
}
function max(a, b) {
    return (a > b) ? a : b;
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

    assert "$(printf '123' | main _31=33 _33=31)" \
                     '321'

    assert "$(printf '%2345d' 0 | main)" \
           "$(printf '%2345d' 0)"

    assert "$(printf '%2345d' 0 | main _20_20_30=30_30_39 | cut -c 2340-)" \
                     '   009'

    echo OK
}
assert() {
    if [ "$1" != "$2" ]; then
        >&2 printf 'FAIL:\n%s\n%s\n' "$1" "$2"
        exit 1
    fi
}

if [ "$1" = "test" ]; then
    test
else
    main "$@"
fi

