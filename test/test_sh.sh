#!/usr/bin/env bash

run_tests() {
    output="$(./test/test.sh.bat 2>&1)"
    assert_equal "$output" "$(cat <<-EOF
		0 Hello shell
		EOF
    )"
}

assert_equal() {
    [ "$1" == "$2" ] || {
        printf "> Expected:\n%s\n> to equal:\n%s\n" "$1" "$2" >&2
        exit 1
    }
}

run_tests

echo OK

