# Reproducing this release

The authoritative outputs are the files in `data/imported/`. The current
`scripts/import_*.qmd` files produce those outputs from the source data and
reviewed translations. Each importer uses the bundled `metadata/` helpers and
codebooks by default. Do not set `MELIDOS_METADATA_ROOT` when reproducing a release.

## Rebuild and check the corrected modalities

From the repository root, in a clean shell:

```sh
Rscript --vanilla scripts/rebuild.R
```

This runs the importers listed in `scripts/rebuild_importers.csv`, each in a
clean R session. All data preparation and export calls execute. Report-only
chunks marked `purl: false` are skipped; full Quarto rendering still executes
them. The command compares the resulting exports with the release files at
zero numeric tolerance, including attributes, labels, factor levels, time
zones and column order. A failed check exits with an error and retains the
generated export and logs for inspection. Run from a fresh release checkout
when validating against the archived release rather than later local changes.

Logs, execution status and comparison results are written to the ignored
`output/rebuild/` directory. To rebuild only selected listed modalities, pass
their names, for example:

```sh
Rscript --vanilla scripts/rebuild.R VLSQ8 experiencelog wellbeingdiary
```

## Render a full report

For a report and its summary PNG, use Quarto from the repository root:

```sh
quarto render scripts/import_VLSQ8.qmd --to html
```

The same command applies to the other current importers. Rendering table images
requires Chrome or Chromium for `gt`/`webshot2`. Generated HTML reports are
ignored to avoid distributing stale copies; the source QMD and current summary
images are retained. `README.md` is generated from `README.Rmd` using
`rmarkdown::render("README.Rmd")`.

## Verification and dependencies

`output/data_quality/release_verification.csv` records the release rebuild
checks. `output/data_quality/software_versions.txt` records the R session used
for verification. The build used R 4.6.1 and Quarto 1.9.37. Use the recorded
package versions for a strict reproduction; this repository does not install
or upgrade packages automatically. The shared metadata source commit and file
checksums are recorded in `metadata/README.md` and `metadata/checksums.csv`.

Raw records are retained for provenance. Approved corrections are implemented
in the importers, rather than applied manually to the exports. Legacy importer
versions and removed HTML reports remain available in Git history. Separate
exploratory scripts, where present, are not part of the export rebuild command.
