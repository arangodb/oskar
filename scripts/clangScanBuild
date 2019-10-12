#!/bin/bash
script_dir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
. "$script_dir/lib/oskar.bash"

oskar_dir="${script_dir%/*}"
[[ -n $oskar_dir ]] || ferr "no source dir given"

cmd=( docker
      run
      -e "ARANGO_SPIN=true"
      --user $UID
      -v "$oskar_dir:/oskar"
      -t "buster_clang:v1"
      --
      "$@"
    )

echo "calling ${cmd[@]}"
"${cmd[@]}"
