---
name: setup
description: Sets up the local environment to run the Stata replication pipeline — configures SetGlobals.do, verifies Stata/Java, checks input data
---

# Environment Setup Agent

Set up the local environment so the replication pipeline (`make.do`) can run successfully.

## Step 1: Configure `setup/SetGlobals.do`

- Check if `setup/SetGlobals.do` already exists.
- If it exists, read it and check whether `$rootdir` is still set to the placeholder `/path/to/nudges-claude-demo`. If it's already configured with a real path, skip to Step 2.
- If it doesn't exist (or has the placeholder), create it by copying `setup/SetGlobals.do.example` and setting `$rootdir` to the absolute path of this repository's root directory. Detect the repo root from the current working directory.

The file should look like:
```stata
/* Copy this file to SetGlobals.do and set rootdir to your local path */
global rootdir "/absolute/path/to/nudges-claude-demo"
```

## Step 2: Verify Stata Installation

- Search for a Stata binary. Common locations:
  - macOS: `/Applications/Stata*/Stata*.app/Contents/MacOS/stata*`, `/usr/local/bin/stata*`
  - Linux: `/usr/local/stata*/stata*`
- Try running `which stata-se || which stata-mp || which stata` as a fallback.
- If found, run it briefly to confirm the version (needs version 18+).
- If Stata is **not found**, report this clearly and stop — the rest of the pipeline won't work without it. Do not attempt to install Stata.

## Step 3: Check Java Runtime (Optional)

- Run `java -version` to check if Java is available.
- Java is only needed for `hash_pii_java.ado` (PII de-identification in `pre_build.do`), which is commented out in the replication package.
- If missing, note it as optional — it won't block the main pipeline.

## Step 4: Install Stata Package Dependencies

- Using the Stata binary found in Step 2, run `CheckRequirements.do` in batch mode:
  ```
  <stata-binary> -b do setup/CheckRequirements.do
  ```
  Run this from the repo root directory.
- This will auto-install any missing packages from SSC (outreg5, unique, estout, tabout, outreg2, outreg, binscatter, ftools, distinct, moss, coefplot, ietoolkit, reghdfe).
- Check the Stata log output for errors. If any package fails to install, report it.

## Step 5: Verify Input Data Files

Confirm these files exist relative to the repo root:
- `cars/input/surveys_combined.dta`
- `cars/input/client_demos.dta`
- `cars/input/external_data.json`
- `cars/input/external_data.txt`
- `ssb/input/survey1.dta`
- `ssb/input/survey2.dta`
- `ssb/input/external_data.json`
- `ssb/input/external_data.txt`

Report any missing files. These are required for the pipeline to run.

## Step 6: Report Summary

Print a summary table:

```
Environment Setup Results
=========================
[DONE/SKIP] SetGlobals.do: <created / already configured>
[PASS/FAIL] Stata: <version and flavor, or not found>
[PASS/WARN] Java: <version, or not found (optional)>
[DONE/FAIL] Stata packages: <installed / errors>
[PASS/FAIL] Input data: <all present / list missing>

Next step: Open Stata and run `do make.do` from the setup/ directory.
```
