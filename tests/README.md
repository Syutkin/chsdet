# ChsDet tests

Run the FPCUnit suite and example checks from the repository root:

```sh
./tests/run-tests.sh --format=plain --sparse
```

On Windows use `tests\run-tests.cmd --format=plain --sparse`. Standard FPCUnit
options such as `--suite` and `--list` are forwarded to the runner.

## Fixtures

All 224 encoding fixtures require an exact charset label and BOM result.
Local `tests/baseline/` reports are ignored by Git.

## Reports and audits

Set `CHSDET_FIXTURE_REPORT` to a TSV path whose parent exists. The runner
overwrites the file and records expected and actual labels, code page, BOM,
`Done`, version and pass/fail:

```sh
CHSDET_FIXTURE_REPORT=tests/.test_build/fixtures.tsv \
  ./tests/run-tests.sh --all --format=plain --sparse
```

Audit fixture bytes, hashes and line endings with Python 3 and `iconv`:

```sh
python3 tests/audit-fixtures.py --output tests/.test_build/fixture-audit.tsv
```

Regenerate the confusion tables with:

```sh
python3 tests/generate-confusion-tables.py
```

## Win64 cross-build

The cross-runner requires FPC 3.2.2 for Win64, MinGW binutils and Wine:

```sh
FPC_WIN64_ROOT=/path/to/fpc-win64-3.2.2 \
  ./tests/run-tests-win64.sh --format=plain --sparse
```

`FPC_WIN64_BINUTILS` defaults to `/usr/bin` and `FPC_WIN64_PREFIX` to
`x86_64-w64-mingw32-`. Outputs are kept in `tests/.test_build/`.
