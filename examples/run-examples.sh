#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_directory="$repository_root/examples/.build"
unit_directory="$build_directory/lib"
mkdir -p "$unit_directory"

for program in text_detect file_detect legacy_detect; do
  fpc -MObjFPC -Scaghi -O1 -vewnhibq \
    -Fu"$repository_root/src" -Fu"$repository_root/src/sbseq" \
    -Fu"$repository_root/examples" -FU"$unit_directory" \
    -FE"$build_directory" -o"$build_directory/$program" \
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
  output="$($build_directory/text_detect "$case_name")"
  case "$case_name" in
    empty|short) check_line "$output" 'Status: dsInsufficientData' ;;
    ascii|utf8) check_line "$output" 'Status: dsDetected' ;;
    unknown) check_line "$output" 'Status: dsUnknown' ;;
    ambiguous) check_line "$output" 'Status: dsAmbiguous' ;;
  esac
done
check_line "$($build_directory/text_detect short)" \
  'No reliable choice; provide more data or external context.'
check_line "$($build_directory/text_detect utf8)" 'Source: csUTF8Validation'

output="$($build_directory/file_detect \
  "$repository_root/tests/fixtures/encodings/utf-8-ru-bom-lf.txt" windows-1251)"
check_line "$output" 'Status: dsExcludedByProfile'
check_line "$output" 'BOM: BOM_UTF8 (3 bytes)'
[[ "$(grep -Fc 'Status: dsExcludedByProfile' <<< "$output")" = 2 ]]

output="$($build_directory/file_detect \
  "$repository_root/tests/fixtures/encodings/windows-1251-long-lf.txt" \
  UTF-8 UTF-16LE UTF-16BE windows-1251)"
check_line "$output" 'Charset: windows-1251'
[[ "$(grep -Fc 'Status: dsDetected' <<< "$output")" = 2 ]]

output="$($build_directory/legacy_detect \
  "$repository_root/tests/fixtures/encodings/ascii-lf.txt")"
check_line "$output" 'Charset: ASCII'

if "$build_directory/file_detect" "$build_directory/missing-file" \
  >/dev/null 2>&1; then
  echo 'Missing file unexpectedly succeeded' >&2
  exit 1
fi

echo 'Examples: build and checks passed'
