#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_directory="$repository_root/tests/.test_build"
unit_directory="$build_directory/lib"

mkdir -p "$unit_directory"

fpc \
  -MObjFPC \
  -Scaghi \
  -Ciro \
  -O1 \
  -vewnhibq \
  -Fu"$repository_root/src" \
  -Fu"$repository_root/src/sbseq" \
  -Fu"$repository_root/tests" \
  -FU"$unit_directory" \
  -FE"$build_directory" \
  -o"$build_directory/chsdettests" \
  -B \
  "$repository_root/tests/runtests.pas"

"$build_directory/chsdettests" "$@"
