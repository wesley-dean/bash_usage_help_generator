#!/usr/bin/env bats

setup() {
  TEST_TMPDIR="$(mktemp -d)"
  AWK_SCRIPT="${BATS_TEST_DIRNAME%/tests}/generate_usage_help.awk"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

make_script() {
  local path="$1"
  cat > "$path"
}

@test "renders usage section from literal getopts optstring" {
  make_script "$TEST_TMPDIR/example.src.bash" <<'EOF'
#!/usr/bin/env bash

while getopts "w:h" option ; do
  case "$option" in
    w) word="$OPTARG" ;;
    h) usage_help ; exit 0 ;;
  esac
done
EOF

  run awk -f "$AWK_SCRIPT" "$TEST_TMPDIR/example.src.bash"

  [ "$status" -eq 0 ]
  [[ "$output" == *"## Usage"* ]]
  [[ "$output" == *'`example.src.bash` [-h] [-w VALUE]'* ]]
}

@test "renders file header and core sections from first doxygen block" {
  make_script "$TEST_TMPDIR/example.src.bash" <<'EOF'
#!/usr/bin/env bash

## @file example.src.bash
## @brief Example CLI tool
## @details
## This script demonstrates generated usage help.
##
printf 'hello\n'
EOF

  run awk -f "$AWK_SCRIPT" "$TEST_TMPDIR/example.src.bash"

  [ "$status" -eq 0 ]
  [[ "$output" == *"# file example.src.bash"* ]]
  [[ "$output" == *"## Brief"* ]]
  [[ "$output" == *"Example CLI tool"* ]]
  [[ "$output" == *"## Details"* ]]
  [[ "$output" == *"This script demonstrates generated usage help."* ]]
}

@test "groups parameters and return values" {
  make_script "$TEST_TMPDIR/example.src.bash" <<'EOF'
#!/usr/bin/env bash

## @fn usage_help()
## @brief Render usage help.
## @param format output format
## @param file source file
## @retval 0 success
## @retval 1 failure
##
:
EOF

  run awk -f "$AWK_SCRIPT" "$TEST_TMPDIR/example.src.bash"

  [ "$status" -eq 0 ]
  [[ "$output" == *"# function usage_help()"* ]]
  [[ "$output" == *"## Parameters"* ]]
  [[ "$output" == *"**format** output format"* ]]
  [[ "$output" == *"**file** source file"* ]]
  [[ "$output" == *"## Return values"* ]]
  [[ "$output" == *"**0** success"* ]]
  [[ "$output" == *"**1** failure"* ]]
}

@test "renders @par as a second-level markdown header" {
  make_script "$TEST_TMPDIR/example.src.bash" <<'EOF'
#!/usr/bin/env bash

## @fn demo()
## @par Examples
## Example paragraph text.
##
:
EOF

  run awk -f "$AWK_SCRIPT" "$TEST_TMPDIR/example.src.bash"

  [ "$status" -eq 0 ]
  [[ "$output" == *"## Examples"* ]]
  [[ "$output" == *"Example paragraph text."* ]]
}

@test "renders @code and @endcode as fenced code blocks" {
  make_script "$TEST_TMPDIR/example.src.bash" <<'EOF'
#!/usr/bin/env bash

## @fn demo()
## @par Examples
## @code
## foo
## bar
## @endcode
##
:
EOF

  run awk -f "$AWK_SCRIPT" "$TEST_TMPDIR/example.src.bash"

  [ "$status" -eq 0 ]
  [[ "$output" == *"## Examples"* ]]
  [[ "$output" == *'```'* ]]
  [[ "$output" == *$'foo\nbar'* ]]
}

@test "extracts documented options from ##- comments" {
  make_script "$TEST_TMPDIR/example.src.bash" <<'EOF'
#!/usr/bin/env bash

h) usage_help ; exit 0 ;; ##- display usage help
'--help') usage_help ; exit 0 ;; ##- display usage help
v) verbose='true' ;; ##- enable verbose mode
EOF

  run awk -f "$AWK_SCRIPT" "$TEST_TMPDIR/example.src.bash"

  [ "$status" -eq 0 ]
  [[ "$output" == *"## Options"* ]]
  [[ "$output" == *'* `-h`: display usage help'* ]]
  [[ "$output" == *'* `--help`: display usage help'* ]]
  [[ "$output" == *'* `-v`: enable verbose mode'* ]]
}

@test "sorts documented options alphabetically while ignoring leading dashes" {
  make_script "$TEST_TMPDIR/example.src.bash" <<'EOF'
#!/usr/bin/env bash

'--verbose') : ;; ##- enable verbose mode
a) : ;; ##- use mode a
'--help') : ;; ##- display usage help
h) : ;; ##- display usage help
EOF

  run awk -f "$AWK_SCRIPT" "$TEST_TMPDIR/example.src.bash"

  [ "$status" -eq 0 ]

  help_short_line="$(printf '%s\n' "$output" | grep -nF '* `-h`: display usage help' | cut -d: -f1)"
  help_long_line="$(printf '%s\n' "$output" | grep -nF '* `--help`: display usage help' | cut -d: -f1)"
  verbose_line="$(printf '%s\n' "$output" | grep -nF '* `--verbose`: enable verbose mode' | cut -d: -f1)"
  a_line="$(printf '%s\n' "$output" | grep -nF '* `-a`: use mode a' | cut -d: -f1)"

  [ -n "$a_line" ]
  [ -n "$help_short_line" ]
  [ -n "$help_long_line" ]
  [ -n "$verbose_line" ]

  [ "$a_line" -lt "$help_short_line" ]
  [ "$help_short_line" -lt "$verbose_line" ]
  [ "$help_long_line" -lt "$verbose_line" ]
}

@test "suppresses usage section when no getopts call exists" {
  make_script "$TEST_TMPDIR/example.src.bash" <<'EOF'
#!/usr/bin/env bash

## @file example.src.bash
## @brief No options here
##
printf 'hello\n'
EOF

  run awk -f "$AWK_SCRIPT" "$TEST_TMPDIR/example.src.bash"

  [ "$status" -eq 0 ]
  [[ "$output" != *"## Usage"* ]]
}

@test "suppresses options section when no ##- option comments exist" {
  make_script "$TEST_TMPDIR/example.src.bash" <<'EOF'
#!/usr/bin/env bash

while getopts "h" option ; do
  case "$option" in
    h) usage_help ; exit 0 ;;
  esac
done
EOF

  run awk -f "$AWK_SCRIPT" "$TEST_TMPDIR/example.src.bash"

  [ "$status" -eq 0 ]
  [[ "$output" == *"## Usage"* ]]
  [[ "$output" != *"## Options"* ]]
}

@test "ignores generated usage help cond block inside doxygen header" {
  make_script "$TEST_TMPDIR/example.src.bash" <<'EOF'
#!/usr/bin/env bash

## @file example.src.bash
## @brief Example CLI tool
## @cond GENERATED_USAGE_HELP
## this should not appear
## @endcond
## @details
## Real details remain visible.
##
:
EOF

  run awk -f "$AWK_SCRIPT" "$TEST_TMPDIR/example.src.bash"

  [ "$status" -eq 0 ]
  [[ "$output" == *"# file example.src.bash"* ]]
  [[ "$output" == *"Real details remain visible."* ]]
  [[ "$output" != *"this should not appear"* ]]
  [[ "$output" != *"GENERATED_USAGE_HELP"* ]]
}

@test "only uses the first contiguous doxygen block" {
  make_script "$TEST_TMPDIR/example.src.bash" <<'EOF'
#!/usr/bin/env bash

## @file example.src.bash
## @brief First block
:
## @brief Second block
EOF

  run awk -f "$AWK_SCRIPT" "$TEST_TMPDIR/example.src.bash"

  [ "$status" -eq 0 ]
  [[ "$output" == *"First block"* ]]
  [[ "$output" != *"Second block"* ]]
}

@test "deduplicates identical documented options" {
  make_script "$TEST_TMPDIR/example.src.bash" <<'EOF'
#!/usr/bin/env bash

h) usage_help ; exit 0 ;; ##- display usage help
h) usage_help ; exit 0 ;; ##- display usage help
EOF

  run awk -f "$AWK_SCRIPT" "$TEST_TMPDIR/example.src.bash"

  [ "$status" -eq 0 ]

  count="$(printf '%s\n' "$output" | grep -cF '* `-h`: display usage help')"
  [ "$count" -eq 1 ]
}

@test "renders a combined document with usage docs and options" {
  make_script "$TEST_TMPDIR/example.src.bash" <<'EOF'
#!/usr/bin/env bash

## @file example.src.bash
## @brief Example CLI tool
## @details
## This exists for testing.

while getopts "h" option ; do
  case "$option" in
    h) usage_help ; exit 0 ;; ##- display usage help
    '--help') usage_help ; exit 0 ;; ##- display usage help
  esac
done
EOF

  run awk -f "$AWK_SCRIPT" "$TEST_TMPDIR/example.src.bash"

  [ "$status" -eq 0 ]
  [[ "$output" == *"## Usage"* ]]
  [[ "$output" == *'`example.src.bash` [-h]'* ]]
  [[ "$output" == *"# file example.src.bash"* ]]
  [[ "$output" == *"## Brief"* ]]
  [[ "$output" == *"Example CLI tool"* ]]
  [[ "$output" == *"## Details"* ]]
  [[ "$output" == *"This exists for testing."* ]]
  [[ "$output" == *"## Options"* ]]
  [[ "$output" == *'* `-h`: display usage help'* ]]
  [[ "$output" == *'* `--help`: display usage help'* ]]
}
