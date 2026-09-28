#!/usr/bin/env bash

set -euo pipefail

: "${FPC_WIN64_ROOT:?Set FPC_WIN64_ROOT to the Windows cross-toolchain directory}"
repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_directory="$repository_root/examples/.build/win64"
unit_directory="$build_directory/lib"
mkdir -p "$unit_directory"

for program in text_detect file_detect legacy_detect; do
  "$FPC_WIN64_ROOT/lib/fpc/3.2.2/ppcrossx64" -n \
    @"$FPC_WIN64_ROOT/etc/fpc.cfg" -Twin64 -Px86_64 \
    -FD"${FPC_WIN64_BINUTILS:-/usr/bin}" \
    -XP"${FPC_WIN64_PREFIX:-x86_64-w64-mingw32-}" \
    -MObjFPC -Scaghi -O1 -vewnhibq \
    -Fu"$repository_root/src" -Fu"$repository_root/src/sbseq" \
    -Fu"$repository_root/examples" -FU"$unit_directory" \
    -FE"$build_directory" -o"$build_directory/$program.exe" \
    "$repository_root/examples/$program.pas" >/dev/null
done

check_line() {
  local output="$1"
  local expected="$2"
  if ! grep -Fqx "$expected" <<< "$output"; then
    printf 'Missing expected line: %s\nOutput:\n%s\n' "$expected" "$output" >&2
    exit 1
  fi
}

for case_name in empty ascii utf8 short unknown ambiguous; do
  output="$(wine "$build_directory/text_detect.exe" "$case_name" | tr -d '\r')"
  case "$case_name" in
    empty|short) check_line "$output" 'Status: dsInsufficientData' ;;
    ascii|utf8) check_line "$output" 'Status: dsDetected' ;;
    unknown) check_line "$output" 'Status: dsUnknown' ;;
    ambiguous) check_line "$output" 'Status: dsAmbiguous' ;;
  esac
done

bom_file="$(winepath -w "$repository_root/tests/fixtures/encodings/utf-8-ru-bom-lf.txt" | tr -d '\r')"
output="$(wine "$build_directory/file_detect.exe" "$bom_file" windows-1251 | tr -d '\r')"
check_line "$output" 'Status: dsExcludedByProfile'
check_line "$output" 'BOM: BOM_UTF8 (3 bytes)'
[[ "$(grep -Fc 'Status: dsExcludedByProfile' <<< "$output")" = 2 ]]

cyrillic_file="$(winepath -w "$repository_root/tests/fixtures/encodings/windows-1251-long-lf.txt" | tr -d '\r')"
output="$(wine "$build_directory/file_detect.exe" "$cyrillic_file" \
  UTF-8 UTF-16LE UTF-16BE windows-1251 | tr -d '\r')"
check_line "$output" 'Charset: windows-1251'
[[ "$(grep -Fc 'Status: dsDetected' <<< "$output")" = 2 ]]

ascii_file="$(winepath -w "$repository_root/tests/fixtures/encodings/ascii-lf.txt" | tr -d '\r')"
output="$(wine "$build_directory/legacy_detect.exe" "$ascii_file" | tr -d '\r')"
check_line "$output" 'Charset: ASCII'
output="$(wine "$build_directory/legacy_detect.exe" "$cyrillic_file" | tr -d '\r')"
check_line "$output" 'Charset: windows-1251'
output="$(wine "$build_directory/legacy_detect.exe" "$cyrillic_file" 1251 | tr -d '\r')"
if grep -Fqx 'Charset: windows-1251' <<< "$output"; then
  echo 'Disabled legacy code page was selected' >&2
  exit 1
fi

if wine "$build_directory/file_detect.exe" 'Z:\missing-chsdet-example-file' \
  >/dev/null 2>&1; then
  echo 'Missing file unexpectedly succeeded' >&2
  exit 1
fi

echo 'Win64 examples: build and checks passed'
