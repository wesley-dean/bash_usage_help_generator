#!/usr/bin/awk -f
#
# generate_usage_help.awk
#
# Build-time documentation extractor for Bash scripts.
#
# This script reads a Bash source file and emits simple Markdown usage
# documentation derived from:
#
#   1. The first contiguous Doxygen-style comment block
#   2. Literal getopts optstrings
#   3. Inline option comments marked with ##-
#
# The generated output is intended for inclusion in runtime help text
# and/or project documentation such as README.md files.
#

function trim(s) {
  sub(/^[[:space:]]+/, "", s)
  sub(/[[:space:]]+$/, "", s)
  return s
}

function rtrim(s) {
  sub(/[[:space:]]+$/, "", s)
  return s
}

function add_section(kind, title,    idx) {
  idx = ++section_count
  section_kind[idx] = kind
  section_title[idx] = title
  section_body[idx] = ""
  section_item_count[idx] = 0
  return idx
}

function ensure_group_section(group_key, title,    idx) {
  idx = group_section_index[group_key]
  if (!idx) {
    idx = add_section("group", title)
    group_section_index[group_key] = idx
  }
  return idx
}

function append_section_text(idx, text) {
  if (section_body[idx] == "") {
    section_body[idx] = text
  } else {
    section_body[idx] = section_body[idx] "\n" text
  }
}

function append_group_item(idx, text) {
  section_item_count[idx]++
  section_item[idx, section_item_count[idx]] = text
}

function start_text_section(title, initial_text) {
  current_section = add_section("text", title)
  if (trim(initial_text) != "") {
    append_section_text(current_section, trim(initial_text))
  }
  in_code = 0
}

function begin_code_block() {
  current_section = add_section("code", "")
  in_code = 1
}

function add_paragraph_line(text) {
  text = rtrim(text)

  if (!current_section) {
    current_section = add_section("text", "")
  }

  if (section_kind[current_section] != "text") {
    current_section = add_section("text", "")
  }

  append_section_text(current_section, text)
  in_code = 0
}

function split_name_desc(text,    name, desc) {
  text = trim(text)
  name = text
  desc = ""

  if (match(text, /^[^[:space:]]+/)) {
    name = substr(text, RSTART, RLENGTH)
    desc = substr(text, RLENGTH + 1)
    desc = trim(desc)
  }

  split_result_name = name
  split_result_desc = desc
}

function add_short_option(opt, takes_arg) {
  if (!(opt in short_option_seen)) {
    short_option_seen[opt] = 1
    short_option_count++
    short_option_list[short_option_count] = opt
  }
  short_option_takes_arg[opt] = takes_arg
}

function parse_optstring(optstring,    i, ch, nextch) {
  optstring = trim(optstring)

  if (substr(optstring, 1, 1) == ":") {
    optstring = substr(optstring, 2)
  }

  i = 1
  while (i <= length(optstring)) {
    ch = substr(optstring, i, 1)

    if (ch == ":") {
      i++
      continue
    }

    nextch = substr(optstring, i + 1, 1)

    if (nextch == ":") {
      add_short_option(ch, 1)
      i += 2
    } else {
      add_short_option(ch, 0)
      i++
    }
  }
}

function unquote(s,    first, last) {
  s = trim(s)
  first = substr(s, 1, 1)
  last  = substr(s, length(s), 1)

  if ((first == "'" && last == "'") || (first == "\"" && last == "\"")) {
    s = substr(s, 2, length(s) - 2)
  }

  return s
}

function normalize_option(opt) {
  opt = unquote(opt)

  if (opt ~ /^--/) {
    return opt
  }

  if (opt ~ /^-[^-]/) {
    return opt
  }

  if (opt ~ /^[[:alnum:]]$/) {
    return "-" opt
  }

  return opt
}

function option_sort_key(opt,    key) {
  key = opt
  sub(/^-+/, "", key)
  return key
}

function add_documented_option(display, desc,    key) {
  if (display == "" || desc == "") {
    return
  }

  key = display SUBSEP desc
  if (!(key in documented_option_seen)) {
    documented_option_seen[key] = 1
    documented_option_count++
    documented_option_display[documented_option_count] = display
    documented_option_desc[documented_option_count] = desc
    documented_option_key[documented_option_count] = option_sort_key(display)
  }
}

function sort_short_options(    i, j, tmp) {
  for (i = 1; i <= short_option_count; i++) {
    for (j = i + 1; j <= short_option_count; j++) {
      if (short_option_list[i] > short_option_list[j]) {
        tmp = short_option_list[i]
        short_option_list[i] = short_option_list[j]
        short_option_list[j] = tmp
      }
    }
  }
}

function sort_documented_options(    i, j, tmp) {
  for (i = 1; i <= documented_option_count; i++) {
    for (j = i + 1; j <= documented_option_count; j++) {
      if (documented_option_key[i] > documented_option_key[j] ||
         (documented_option_key[i] == documented_option_key[j] &&
          documented_option_display[i] > documented_option_display[j])) {

        tmp = documented_option_key[i]
        documented_option_key[i] = documented_option_key[j]
        documented_option_key[j] = tmp

        tmp = documented_option_display[i]
        documented_option_display[i] = documented_option_display[j]
        documented_option_display[j] = tmp

        tmp = documented_option_desc[i]
        documented_option_desc[i] = documented_option_desc[j]
        documented_option_desc[j] = tmp
      }
    }
  }
}

function render_usage_markdown(    i, opt) {
  if (short_option_count == 0) {
    return
  }

  sort_short_options()

  print "## Usage"
  print ""

  printf "`%s`", script_name
  for (i = 1; i <= short_option_count; i++) {
    opt = short_option_list[i]
    if (short_option_takes_arg[opt]) {
      printf " [-%s VALUE]", opt
    } else {
      printf " [-%s]", opt
    }
  }

  printf "\n\n"
}

function render_title_markdown() {
  if (doc_title != "") {
    print "# " doc_kind " " doc_title
    print ""
  }
}

function render_section_markdown(idx,    i, j, n, lines) {
  if (section_title[idx] != "") {
    print "## " section_title[idx]
    print ""
  }

  if (section_kind[idx] == "group") {
    for (i = 1; i <= section_item_count[idx]; i++) {
      print section_item[idx, i]
      print ""
    }
    return
  }

  if (section_kind[idx] == "code") {
    print "```"
    if (section_body[idx] != "") {
      n = split(section_body[idx], lines, /\n/)
      for (j = 1; j <= n; j++) {
        print lines[j]
      }
    }
    print "```"
    print ""
    return
  }

  if (section_body[idx] != "") {
    n = split(section_body[idx], lines, /\n/)
    for (j = 1; j <= n; j++) {
      print lines[j]
    }
    print ""
  }
}

function render_documentation_markdown(    i) {
  if (doc_title == "" && section_count == 0) {
    return
  }

  render_title_markdown()

  for (i = 1; i <= section_count; i++) {
    render_section_markdown(i)
  }
}

function render_options_markdown(    i) {
  if (documented_option_count == 0) {
    return
  }

  sort_documented_options()

  print "## Options"
  print ""

  for (i = 1; i <= documented_option_count; i++) {
    printf "* `%s`: %s\n", documented_option_display[i], documented_option_desc[i]
  }

  print ""
}

BEGIN {
  script_name = ARGV[1]
  sub(/^.*\//, "", script_name)

  doc_kind = ""
  doc_title = ""

  section_count = 0
  current_section = 0
  in_code = 0

  short_option_count = 0
  documented_option_count = 0

  in_doxygen_header = 0
  doxygen_header_done = 0
  in_generated_cond = 0
}

{
  raw_line = $0

  #
  # Always ignore the shebang line for parsing purposes.
  #
  if (FNR == 1 && raw_line ~ /^#!/) {
    next
  }

  #
  # Extract literal getopts optstrings.
  #
  if (raw_line ~ /getopts[[:space:]]+"/) {
    if (match(raw_line, /getopts[[:space:]]+"[^"]*"/)) {
      token = substr(raw_line, RSTART, RLENGTH)
      sub(/^.*getopts[[:space:]]+"/, "", token)
      sub(/"$/, "", token)
      parse_optstring(token)
    }
  }

  #
  # Extract documented options from case labels with ##- comments.
  #
  if (index(raw_line, "##-") > 0) {
    split(raw_line, parts, /##-/)
    left = parts[1]
    desc = trim(parts[2])

    if (desc != "" &&
        match(left, /^[[:space:]]*('\''[^'\'']*'\''|"[^"]*"|[^[:space:])]+)[[:space:]]*\)/)) {
      opt = substr(left, RSTART, RLENGTH)
      sub(/^[[:space:]]*/, "", opt)
      sub(/[[:space:]]*\)$/, "", opt)

      display = normalize_option(opt)
      add_documented_option(display, desc)
    }
  }

  #
  # Extract only the first contiguous Doxygen block.
  #
  if (!doxygen_header_done) {
    if (!in_doxygen_header && raw_line ~ /^[[:space:]]*##/) {
      in_doxygen_header = 1
    }

    if (in_doxygen_header && raw_line ~ /^[[:space:]]*##/) {
      line = raw_line
      sub(/^[[:space:]]*##[[:space:]]?/, "", line)

      #
      # Ignore the generated usage help placeholder block.
      #
      if (line ~ /^@cond[[:space:]]+GENERATED_USAGE_HELP([[:space:]]|$)/) {
        in_generated_cond = 1
        next
      }

      if (in_generated_cond) {
        if (line ~ /^@endcond([[:space:]]|$)/) {
          in_generated_cond = 0
        }
        next
      }

      #
      # Code block handling.
      #
      if (in_code) {
        if (line == "@endcode") {
          in_code = 0
          next
        }
        append_section_text(current_section, line)
        next
      }

      if (line == "@code") {
        begin_code_block()
        next
      }

      #
      # Identity tags.
      #
      if (line ~ /^@fn[[:space:]]+/) {
        sub(/^@fn[[:space:]]+/, "", line)
        doc_kind = "function"
        doc_title = trim(line)
        current_section = 0
        next
      }

      if (line ~ /^@file[[:space:]]+/) {
        sub(/^@file[[:space:]]+/, "", line)
        doc_kind = "file"
        doc_title = trim(line)
        current_section = 0
        next
      }

      #
      # Section tags.
      #
      if (line ~ /^@brief([[:space:]]+|$)/) {
        sub(/^@brief[[:space:]]*/, "", line)
        start_text_section("Brief", line)
        next
      }

      if (line ~ /^@details([[:space:]]+|$)/) {
        sub(/^@details[[:space:]]*/, "", line)
        start_text_section("Details", line)
        next
      }

      if (line ~ /^@example([[:space:]]+|$)/) {
        sub(/^@example[[:space:]]*/, "", line)
        start_text_section("Example", line)
        next
      }

      if (line ~ /^@note([[:space:]]+|$)/) {
        sub(/^@note[[:space:]]*/, "", line)
        start_text_section("Note", line)
        next
      }

      if (line ~ /^@warning([[:space:]]+|$)/) {
        sub(/^@warning[[:space:]]*/, "", line)
        start_text_section("Warning", line)
        next
      }

      if (line ~ /^@see([[:space:]]+|$)/) {
        sub(/^@see[[:space:]]*/, "", line)
        start_text_section("See also", line)
        next
      }

      if (line ~ /^@author([[:space:]]+|$)/) {
        sub(/^@author[[:space:]]*/, "", line)
        start_text_section("Author", line)
        next
      }

      if (line ~ /^@deprecated([[:space:]]+|$)/) {
        sub(/^@deprecated[[:space:]]*/, "", line)
        start_text_section("Deprecated", line)
        next
      }

      if (line ~ /^@since([[:space:]]+|$)/) {
        sub(/^@since[[:space:]]*/, "", line)
        start_text_section("Since", line)
        next
      }

      if (line ~ /^@par[[:space:]]+/) {
        sub(/^@par[[:space:]]+/, "", line)
        start_text_section(trim(line), "")
        next
      }

      #
      # Grouped tags.
      #
      if (line ~ /^@param[[:space:]]+/) {
        sub(/^@param[[:space:]]+/, "", line)
        split_name_desc(line)
        idx = ensure_group_section("param", "Parameters")

        if (split_result_desc != "") {
          append_group_item(idx, "**" split_result_name "** " split_result_desc)
        } else {
          append_group_item(idx, "**" split_result_name "**")
        }

        current_section = idx
        next
      }

      if (line ~ /^@retval[[:space:]]+/) {
        sub(/^@retval[[:space:]]+/, "", line)
        split_name_desc(line)
        idx = ensure_group_section("retval", "Return values")

        if (split_result_desc != "") {
          append_group_item(idx, "**" split_result_name "** " split_result_desc)
        } else {
          append_group_item(idx, "**" split_result_name "**")
        }

        current_section = idx
        next
      }

      if (line ~ /^@return([[:space:]]+|$)/) {
        sub(/^@return[[:space:]]*/, "", line)
        idx = ensure_group_section("return", "Returns")

        if (trim(line) != "") {
          append_group_item(idx, trim(line))
        }

        current_section = idx
        next
      }

      #
      # Blank Doxygen content lines are ignored.
      #
      if (line ~ /^$/) {
        next
      }

      #
      # Fallback paragraph content.
      #
      add_paragraph_line(line)
      next
    }

    if (in_doxygen_header) {
      doxygen_header_done = 1
      in_doxygen_header = 0
    }
  }
}

END {
  render_usage_markdown()
  render_documentation_markdown()
  render_options_markdown()
}
