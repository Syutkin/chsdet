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
