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
    return 1
  fi

  local arg
  local abs_path
  local dir
  local base

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

  local build_dir
  local stem

  for dir in "${ordered_dirs[@]}" ; do
    (
      cd -- "$dir"
      make -f "$makefile" FILES="${files_by_dir[$dir]}"
    )

    for base in ${files_by_dir[$dir]} ; do
      stem="${base%.src.bash}"
      build_dir="${dir}/build"
      printf "%s\n" "${build_dir}/${stem}.bash"
    done
  done
}

main "$@"
