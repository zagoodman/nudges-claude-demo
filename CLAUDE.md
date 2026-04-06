# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Replication package for "When Do 'Nudges' Increase Welfare" by Allcott, Cohen, Morrison, and Taubinsky (2025), published in the American Economic Review. The codebase is primarily **Stata** (`.do` files) and processes data from two randomized experiments: a **cars** experiment (fuel economy labels) and a **sugar-sweetened beverages (SSB)** experiment (calorie/sugar labels).

## Running the Project

### Prerequisites
- **Stata 18** (versions 17 specified for `pre_build.do` but 18 everywhere else, set as a global in `SetGlobals.do`)
- Java runtime (required by `hash_pii_java.ado` for SHA-256 hashing of PII)
- Stata packages listed in `setup/CheckRequirements.do`: outreg5, unique, estout, tabout, outreg2, outreg, binscatter, ftools, distinct, moss, coefplot, ietoolkit, reghdfe

### Setup
1. Copy `setup/SetGlobals.do.example` to `setup/SetGlobals.do` and set `$rootdir` to your local path (this file is gitignored)
2. Run `setup/CheckRequirements.do` to auto-install missing Stata packages

### Build & Analysis
Run the master file `make.do` in Stata. It executes:
1. `ssb/make.do` — builds SSB dataset, then runs SSB analysis
2. `cars/make.do` — builds cars dataset, then runs cars analysis

Each experiment's `make.do` follows the same pattern:
- Creates output directories (`intermediate_data/`, `output/`, `output/welfare/`)
- Runs `clean_build.do` (data cleaning/processing)
- Runs `analysis.do` (tables, figures, and LaTeX scalar exports)

The `pre_build.do` files (PII de-identification) are commented out — they require raw PII data not included in the replication package.

## Architecture

```
make.do                    # Master entry point
setup/
  SetGlobals.do            # Set $rootdir global (must be configured per user)
  CheckRequirements.do     # Auto-install Stata package dependencies
lib/ado/                   # Custom ado files (iebaltab)
cars/                      # Cars experiment
  make.do                  # Orchestrates cars build + analysis
  code/
    pre_build.do           # PII removal (not runnable without raw data)
    clean_build.do         # Data cleaning → intermediate_data/ and merged.dta
    analysis.do            # Thin orchestrator — delegates to sub-files below
    _setup.do              # Load data, define latex export programs, set globals
    _sample_descriptives.do
    _ate_plots.do
    _demand_curves.do
    _welfare.do
    _welfare_sensitivity.do
    _histograms_regtable.do
    hash_pii_java.ado      # Java-based SHA-256 hashing for Amerispeak IDs
  input/                   # De-identified input data (.dta, .json, .txt)
ssb/                       # SSB experiment (similar structure to cars/)
  make.do
  code/
    pre_build.do
    clean_build.do
    analysis.do            # Thin orchestrator — delegates to sub-files
    _setup.do
    _sample_descriptives.do
    _label_avoidance.do    # SSB-specific
    _beliefs_satisfaction.do # SSB-specific
    _ate_plots.do
    _demand_curves.do
    _welfare.do
    _welfare_sensitivity.do
    hash_pii_java.ado
  input/
docs/surveys/              # Qualtrics survey instruments (.qsf)
```

## Key Patterns

- **LaTeX scalar export**: Both experiments define `latex`, `latex_rounded`, and `latex_precision` Stata programs that append `\newcommand` entries to `output/numbers*Analysis.tex` files. These are consumed by a LyX/LaTeX document to embed computed values in the paper.
- **Input data**: De-identified `.dta` files in `input/` directories. External data comes in paired `.json` and `.txt` formats.
- **Modular analysis**: Each experiment's `analysis.do` is a thin orchestrator that `do`s a sequence of `_*.do` sub-files. Each sub-file is self-contained and produces a specific set of tables/figures. The `_setup.do` sub-file runs first and defines shared programs and globals.
- **Output**: Tables and figures go to `output/` subdirectories; scalar values go to `.tex` files.
