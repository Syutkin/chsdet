# ChsDet tests

The test suite is built with FPC and uses FPCUnit from the Free Component
Library.

Run all tests from the repository root:

```sh
./tests/run-tests.sh --format=plain
```

On Windows, run the command script from `cmd.exe`:

```bat
tests\run-tests.cmd --format=plain
```

Pass normal FPCUnit console runner options to the script, for example:

```sh
./tests/run-tests.sh --suite=TChsDetTests --format=plain
```

The runner executes all registered tests by default. Use `--suite` or `--list`
to select a suite or inspect the registered tests.

`TCharsetDetectionResult.Candidates` remains sorted by the original model
confidence. When `Source = csConfusionResolution`, the result's `Charset` is
selected by the distinguishing-byte context check and can be the second
candidate. Its `Confidence` is that candidate's unchanged model score.

## Fixture policy and research mode

The required suite contains 160 exact-label tests and four shared-Hebrew
tests. The latter contain only ASCII and Hebrew letters in bytes E0..FA,
which decode identically under ISO-8859-8 and Windows-1255. Either name is
accepted for these four inputs by the legacy API; BOM must still match.
The test also checks that the input stays within this shared repertoire.
This is an explicit ambiguity policy, not a general list of fallback answers.
The four exact-label ISO-8859-8 fixtures contain byte DF, which is undefined
in Windows-1255; the fixture audit requires Windows-1255 decoding to fail.

Keep exact-label expectations for all 164 fixtures available for research:

```sh
CHSDET_STRICT_FIXTURES=1 ./tests/run-tests.sh --all --format=plain --sparse
```

On Windows, set `CHSDET_STRICT_FIXTURES=1` before running the command script.
Research failures remain visible and return a nonzero exit code. No tests
are ignored or marked as expected failures. The four shared fixtures retain
their original bytes under new names; the stage-0 baseline keeps the original
names and hashes. The required suite must eventually pass in full for 0.3.0;
the current baseline is not an allowance for future failures.

## Per-fixture report

Set `CHSDET_FIXTURE_REPORT` to a writable TSV path (parent directory must
exist). The report records original expected label, actual label, code page,
expected/actual BOM, `Done`, version, policy and pass/fail before assertions:

```sh
CHSDET_FIXTURE_REPORT=tests/.test_build/fixtures.tsv \
  ./tests/run-tests.sh --all --format=plain --sparse
```

The file is overwritten at runner startup, including `--list` invocations.
On Windows use a Windows path. Confidence is `unavailable` because the
current public API does not expose it. The reporter does not call internal
confidence getters, which can change state in the current implementation.

Audit fixture validity, hashes, LF/CRLF text equivalence and the shared
Hebrew interpretation independently with Python 3 (standard library only):

```sh
python3 tests/audit-fixtures.py --output tests/.test_build/fixture-audit.tsv
```

Regenerate the single-byte Unicode categories and distinguishing-byte maps
used by the Greek and Cyrillic confusion check with:

```sh
python3 tests/generate-confusion-tables.py
```

## Windows cross-build on Linux

The optional script uses an existing FPC 3.2.2 Windows cross-toolchain,
MinGW binutils and Wine. Native Windows users continue to use `run-tests.cmd`.

```sh
export FPC_WIN64_ROOT=/path/to/fpc-win64-3.2.2
# Optional: an existing writable Wine prefix dedicated to testing.
export WINEPREFIX=/path/to/wine-prefix
bash tests/run-tests-win64.sh --all --format=plain --sparse
```

`FPC_WIN64_BINUTILS` defaults to `/usr/bin`; `FPC_WIN64_PREFIX` defaults to
`x86_64-w64-mingw32-`. The executable is `tests/.test_build/chsdettests.exe`;
cross-compiled units are kept in `tests/.test_build/lib/win64`.
Compiler and test failures propagate as the script exit code.
