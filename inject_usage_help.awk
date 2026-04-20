#!/usr/bin/awk -f
#
# inject_usage_help.awk
#
# Inject rendered usage help into a Bash script by replacing or inserting
# a GENERATED_USAGE_HELP conditional block.
#
# Usage:
#   awk -v help_file="path/to/help.md" -f inject_usage_help.awk script.bash
#

function load_help_text(    line) {
  if (help_file == "") {
    print "inject_usage_help.awk: missing -v help_file=..." > "/dev/stderr"
    exit 1
  }

  help_count = 0
  while ((getline line < help_file) > 0) {
    help_lines[++help_count] = line
  }
  close(help_file)
}

function print_generated_block(    i) {
  print "## @cond GENERATED_USAGE_HELP"
  print "usage_help() {"
  print "  cat <<'\''__BASHLIB_USAGE_HELP__'\''"
  for (i = 1; i <= help_count; i++) {
    print help_lines[i]
  }
  print "__BASHLIB_USAGE_HELP__"
  print "}"
  print "## @endcond"
}

BEGIN {
  load_help_text()

  line_count = 0
  found_generated_block = 0
  replaced_generated_block = 0
  in_generated_block = 0
}

{
  lines[++line_count] = $0

  if ($0 ~ /^[[:space:]]*##[[:space:]]*@cond[[:space:]]*GENERATED_USAGE_HELP([[:space:]]|$)/) {
    found_generated_block = 1
  }
}

END {
  if (line_count == 0) {
    print_generated_block()
    exit 0
  }

  #
  # If a generated block already exists, replace it in place.
  #
  if (found_generated_block) {
    for (i = 1; i <= line_count; i++) {
      if (!in_generated_block &&
          lines[i] ~ /^[[:space:]]*##[[:space:]]*@cond[[:space:]]*GENERATED_USAGE_HELP([[:space:]]|$)/) {
        if (!replaced_generated_block) {
          print_generated_block()
          replaced_generated_block = 1
        }
        in_generated_block = 1
        continue
      }

      if (in_generated_block) {
        if (lines[i] ~ /^[[:space:]]*##[[:space:]]*@endcond([[:space:]]|$)/) {
          in_generated_block = 0
        }
        continue
      }

      print lines[i]
    }

    exit 0
  }

  #
  # Otherwise inject after shebang, or at top if no shebang exists.
  #
  if (lines[1] ~ /^#!/) {
    print lines[1]
    print_generated_block()
    for (i = 2; i <= line_count; i++) {
      print lines[i]
    }
  } else {
    print_generated_block()
    for (i = 1; i <= line_count; i++) {
      print lines[i]
    }
  }
}
