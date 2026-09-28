#!/usr/bin/env bash

# Cross-build with FPC 3.2.2 and execute the Windows runner through Wine.
set -euo pipefail

: "${FPC_WIN64_ROOT:?Set FPC_WIN64_ROOT to the Windows cross-toolchain directory}"
repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_directory="$repository_root/tests/.test_build"
unit_directory="$build_directory/lib/win64"
mkdir -p "$unit_directory"

"$FPC_WIN64_ROOT/lib/fpc/3.2.2/ppcrossx64" \
  -n \
  @"$FPC_WIN64_ROOT/etc/fpc.cfg" \
  -Twin64 -Px86_64 \
  -FD"${FPC_WIN64_BINUTILS:-/usr/bin}" \
  -XP"${FPC_WIN64_PREFIX:-x86_64-w64-mingw32-}" \
  -MObjFPC -Scaghi -Ciro -O1 -vewnhibq \
  -Fu"$repository_root/src" \
  -Fu"$repository_root/src/sbseq" \
  -Fu"$repository_root/tests" \
  -FU"$unit_directory" \
  -FE"$build_directory" \
  -o"$build_directory/chsdettests.exe" \
  -B "$repository_root/tests/runtests.pas"

wine "$build_directory/chsdettests.exe" "$@"
"$repository_root/examples/run-examples-win64.sh"
