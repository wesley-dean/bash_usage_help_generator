#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

main() {
  local tool_dir
  tool_dir="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

  local makefile
  makefile="${tool_dir}/Makefile"

  if [ ! -f "${makefile}" ] ; then
    printf "Error: Makefile not found at '%s'\n" "${makefile}" >&2
    return 1
  fi

  if [ "$#" -eq 0 ] ; then
    printf "Usage: %s FILE.src.bash [MORE.src.bash ...]\n" "$(basename "$0")" >&2
    printf "       %s - < input.src.bash > output.bash\n" "$(basename "$0")" >&2
    return 1
  fi

  if [ "$#" -eq 1 ] && [ "$1" = "-" ] ; then
    run_stdin_mode "${makefile}"
    return $?
  fi

  run_file_mode "${makefile}" "$@"
}

run_stdin_mode() {
  local makefile="${1?Error: no Makefile provided}"
  local temp_dir

  temp_dir="$(mktemp -d)" || return 1

  cleanup_stdin_mode() {
    rm -rf -- "${temp_dir}"
  }

  trap cleanup_stdin_mode EXIT HUP INT TERM

  cat > "${temp_dir}/stdin.src.bash"

  (
    cd -- "${temp_dir}"
    make -f "${makefile}" FILES="stdin.src.bash"
  ) >/dev/null

  cat "${temp_dir}/stdin.bash"

  trap - EXIT HUP INT TERM
  cleanup_stdin_mode
}

run_file_mode() {
  local makefile="${1?Error: no Makefile provided}"
  shift

  local arg
  local abs_path
  local dir
  local base
  local build_dir
  local stem

  local -a ordered_dirs=()
  local -A seen_dirs=()
  local -A files_by_dir=()

  for arg in "$@" ; do
    if [ ! -e "$arg" ] ; then
      printf "Error: file does not exist: %s\n" "$arg" >&2
      return 1
    fi

    if [ ! -f "$arg" ] ; then
      printf "Error: not a regular file: %s\n" "$arg" >&2
      return 1
    fi

    case "$arg" in
      *.src.bash) ;;
      *)
        printf "Error: expected a '.src.bash' file: %s\n" "$arg" >&2
        return 1
        ;;
    esac

    abs_path="$(CDPATH='' cd -- "$(dirname -- "$arg")" && pwd -P)/$(basename -- "$arg")"
    dir="$(dirname -- "$abs_path")"
    base="$(basename -- "$abs_path")"

    if [ -z "${seen_dirs[$dir]+x}" ] ; then
      ordered_dirs+=("$dir")
      seen_dirs["$dir"]=1
    fi

    if [ -n "${files_by_dir[$dir]:-}" ] ; then
      files_by_dir["$dir"]="${files_by_dir[$dir]} $base"
    else
      files_by_dir["$dir"]="$base"
    fi
  done

  for dir in "${ordered_dirs[@]}" ; do
    (
      cd -- "$dir"
      make -f "$makefile" FILES="${files_by_dir[$dir]}"
    )

    for base in ${files_by_dir[$dir]} ; do
      stem="${base%.src.bash}"
      build_dir="${dir}/build"
      printf "%s\n" "${dir}/${stem}.bash"
    done
  done
}

main "$@"
