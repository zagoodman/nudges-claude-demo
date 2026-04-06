# nudges-claude-demo

This repo is forked from the [replication package](https://www.openicpsr.org/openicpsr/project/208345/version/V2/view) to [When Do "Nudges" Increase Welfare](https://www.aeaweb.org/articles?id=10.1257/aer.20231304) by Allcott, Cohen, Morrison, and Taubinsky (2025).

## Setup

### Requirements
- **Stata 18** (SE, MP, or IC)
- **Java** (optional — only needed for PII hashing in `pre_build.do`, which is commented out)

### Configuration
1. Copy the template config file:
   ```
   cp setup/SetGlobals.do.example setup/SetGlobals.do
   ```
2. Edit `setup/SetGlobals.do` and set `rootdir` to your local path to this repository.
3. Open Stata and run `setup/CheckRequirements.do` to auto-install required packages.

### Running
Run `make.do` in Stata. This executes the full pipeline for both experiments (SSB and cars).
