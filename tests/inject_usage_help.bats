#!/usr/bin/env bats

setup() {
  TEST_TMPDIR="$(mktemp -d)"
  PROJECT_ROOT="${BATS_TEST_DIRNAME%/tests}"
  GENERATOR_AWK="${PROJECT_ROOT}/generate_usage_help.awk"
  INJECTOR_AWK="${PROJECT_ROOT}/inject_usage_help.awk"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

make_file() {
  local path="$1"
  cat > "$path"
}

line_number_of() {
  local needle="$1"
  local haystack="$2"

  printf '%s\n' "$haystack" | awk -v needle="$needle" '
    index($0, needle) {
      print NR
      exit
    }
  '
}

@test "injector inserts generated usage_help block after shebang when sentinel is absent" {
  make_file "$TEST_TMPDIR/help.md" <<'EOF'
## Usage

`example.bash` [-h]

## Options

* `-h`: display usage help
EOF

  make_file "$TEST_TMPDIR/script.bash" <<'EOF'
#!/usr/bin/env bash
printf 'hello\n'
EOF

  run awk -v help_file="$TEST_TMPDIR/help.md" -f "$INJECTOR_AWK" "$TEST_TMPDIR/script.bash"

  [ "$status" -eq 0 ]

  shebang_line="$(line_number_of '#!/usr/bin/env bash' "$output")"
  cond_line="$(line_number_of '## @cond GENERATED_USAGE_HELP' "$output")"
  function_line="$(line_number_of 'usage_help() {' "$output")"
  delimiter_line="$(line_number_of '__BASHLIB_USAGE_HELP__' "$output")"
  printf_line="$(line_number_of 'printf ' "$output")"

  [ -n "$shebang_line" ]
  [ -n "$cond_line" ]
  [ -n "$function_line" ]
  [ -n "$delimiter_line" ]
  [ -n "$printf_line" ]

  [ "$shebang_line" -lt "$cond_line" ]
  [ "$cond_line" -lt "$printf_line" ]

  [[ "$output" == *'## Usage'* ]]
  [[ "$output" == *'`example.bash` [-h]'* ]]
}

@test "injector inserts generated block before script content when no shebang exists" {
  make_file "$TEST_TMPDIR/help.md" <<'EOF'
Hello from help text.
EOF

  make_file "$TEST_TMPDIR/script.bash" <<'EOF'
printf 'hello\n'
EOF

  run awk -v help_file="$TEST_TMPDIR/help.md" -f "$INJECTOR_AWK" "$TEST_TMPDIR/script.bash"

  [ "$status" -eq 0 ]

  cond_line="$(line_number_of '## @cond GENERATED_USAGE_HELP' "$output")"
  function_line="$(line_number_of 'usage_help() {' "$output")"
  printf_line="$(line_number_of 'printf ' "$output")"

  [ -n "$cond_line" ]
  [ -n "$function_line" ]
  [ -n "$printf_line" ]

  [ "$cond_line" -lt "$printf_line" ]

  [[ "$output" == *"Hello from help text."* ]]
}

@test "injector replaces existing generated usage help block" {
  make_file "$TEST_TMPDIR/help.md" <<'EOF'
New generated help text.
EOF

  make_file "$TEST_TMPDIR/script.bash" <<'EOF'
#!/usr/bin/env bash
## @cond GENERATED_USAGE_HELP
usage_help() {
  printf '%s\n' 'old help'
}
## @endcond
printf 'hello\n'
EOF

  run awk -v help_file="$TEST_TMPDIR/help.md" -f "$INJECTOR_AWK" "$TEST_TMPDIR/script.bash"

  [ "$status" -eq 0 ]

  [[ "$output" == *"New generated help text."* ]]
  [[ "$output" != *"old help"* ]]
  [[ "$output" == *"printf "* ]]

  count_begin="$(printf '%s\n' "$output" | grep -c '^## @cond GENERATED_USAGE_HELP$')"
  count_end="$(printf '%s\n' "$output" | grep -c '^## @endcond$')"

  [ "$count_begin" -eq 1 ]
  [ "$count_end" -eq 1 ]
}

@test "injector preserves shebang before generated block when replacing existing block" {
  make_file "$TEST_TMPDIR/help.md" <<'EOF'
Injected help text.
EOF

  make_file "$TEST_TMPDIR/script.bash" <<'EOF'
#!/usr/bin/env bash
## @cond GENERATED_USAGE_HELP
usage_help() {
  printf '%s\n' 'placeholder'
}
## @endcond
:
EOF

  run awk -v help_file="$TEST_TMPDIR/help.md" -f "$INJECTOR_AWK" "$TEST_TMPDIR/script.bash"

  [ "$status" -eq 0 ]

  shebang_line="$(line_number_of '#!/usr/bin/env bash' "$output")"
  cond_line="$(line_number_of '## @cond GENERATED_USAGE_HELP' "$output")"

  [ -n "$shebang_line" ]
  [ -n "$cond_line" ]
  [ "$shebang_line" -lt "$cond_line" ]
}

@test "injector handles an empty script by emitting a generated block" {
  : > "$TEST_TMPDIR/script.bash"

  make_file "$TEST_TMPDIR/help.md" <<'EOF'
Standalone help text.
EOF

  run awk -v help_file="$TEST_TMPDIR/help.md" -f "$INJECTOR_AWK" "$TEST_TMPDIR/script.bash"

  [ "$status" -eq 0 ]

  cond_line="$(line_number_of '## @cond GENERATED_USAGE_HELP' "$output")"
  function_line="$(line_number_of 'usage_help() {' "$output")"

  [ -n "$cond_line" ]
  [ -n "$function_line" ]

  [[ "$output" == *"Standalone help text."* ]]
}

@test "injector output defines a working usage_help function" {
  make_file "$TEST_TMPDIR/help.md" <<'EOF'
## Usage

`example.bash` [-h]

## Options

* `-h`: display usage help
EOF

  make_file "$TEST_TMPDIR/script.bash" <<'EOF'
#!/usr/bin/env bash
printf 'before\n'
EOF

  run awk -v help_file="$TEST_TMPDIR/help.md" -f "$INJECTOR_AWK" "$TEST_TMPDIR/script.bash"

  [ "$status" -eq 0 ]

  printf '%s\n' "$output" > "$TEST_TMPDIR/generated.bash"

  run bash -lc "source '$TEST_TMPDIR/generated.bash'; usage_help"

  [ "$status" -eq 0 ]
  [[ "$output" == *'## Usage'* ]]
  [[ "$output" == *'`example.bash` [-h]'* ]]
  [[ "$output" == *'* `-h`: display usage help'* ]]
}

@test "generator and injector work together end to end" {
  make_file "$TEST_TMPDIR/example.src.bash" <<'EOF'
#!/usr/bin/env bash

## @file example.src.bash
## @brief Example CLI tool
## @details
## Demonstrates full pipeline behavior.
##
while getopts "h" option ; do
  case "$option" in
    h) usage_help ; exit 0 ;; ##- display usage help
  esac
done

printf 'done\n'
EOF

  run awk -f "$GENERATOR_AWK" "$TEST_TMPDIR/example.src.bash"
  [ "$status" -eq 0 ]

  printf '%s\n' "$output" > "$TEST_TMPDIR/help.md"

  run awk -v help_file="$TEST_TMPDIR/help.md" -f "$INJECTOR_AWK" "$TEST_TMPDIR/example.src.bash"
  [ "$status" -eq 0 ]

  printf '%s\n' "$output" > "$TEST_TMPDIR/generated.bash"

  run bash -lc "source '$TEST_TMPDIR/generated.bash'; usage_help"

  [ "$status" -eq 0 ]
  [[ "$output" == *'## Usage'* ]]
  [[ "$output" == *'`example.src.bash` [-h]'* ]]
  [[ "$output" == *'# file example.src.bash'* ]]
  [[ "$output" == *'## Brief'* ]]
  [[ "$output" == *'Example CLI tool'* ]]
  [[ "$output" == *'## Details'* ]]
  [[ "$output" == *'Demonstrates full pipeline behavior.'* ]]
  [[ "$output" == *'## Options'* ]]
  [[ "$output" == *'* `-h`: display usage help'* ]]
}
