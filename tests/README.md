# ChsDet tests

Run the FPCUnit suite and example checks from the repository root:

```sh
./tests/run-tests.sh --format=plain --sparse
```

On Windows use `tests\run-tests.cmd --format=plain --sparse`. Standard FPCUnit
options such as `--suite` and `--list` are forwarded to the runner.

## Fixture policy

The required suite checks 160 exact-label fixtures and four shared-Hebrew
fixtures. The latter decode identically under ISO-8859-8 and Windows-1255;
either legacy API name is accepted while the BOM and shared-byte repertoire
are checked. The four distinguishing ISO-8859-8 fixtures contain byte `DF`,
which is undefined in Windows-1255.

Strict research mode requires every original label and therefore exits with
four failures:

```sh
CHSDET_STRICT_FIXTURES=1 ./tests/run-tests.sh --all --format=plain --sparse
```

See the [research report](../docs/research-fixtures-0.3.0.md). Local
`tests/baseline/` reports are ignored by Git.

## Reports and audits

Set `CHSDET_FIXTURE_REPORT` to a TSV path whose parent exists. The runner
overwrites the file and records expected and actual labels, code page, BOM,
`Done`, version, policy and pass/fail:

```sh
CHSDET_FIXTURE_REPORT=tests/.test_build/fixtures.tsv \
  ./tests/run-tests.sh --all --format=plain --sparse
```

Audit fixture bytes, hashes and line endings, or regenerate the confusion
tables, with Python 3:

```sh
python3 tests/audit-fixtures.py --output tests/.test_build/fixture-audit.tsv
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
