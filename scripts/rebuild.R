# Rebuild corrected exports in clean R sessions and check them against this release.
args <- commandArgs(trailingOnly = TRUE)
script_arg <- grep("^--file=", commandArgs(), value = TRUE)
script <- normalizePath(sub("^--file=", "", script_arg[[1L]]))
scripts_dir <- dirname(script)
repo <- dirname(scripts_dir)
catalog <- read.csv(file.path(scripts_dir, "rebuild_importers.csv"))
if (length(args)) {
  unknown <- setdiff(args, catalog$importer)
  if (length(unknown)) stop("Unknown importer: ", paste(unknown, collapse = ", "))
  catalog <- catalog[catalog$importer %in% args, ]
}
logs <- file.path(repo, "output/rebuild")
dir.create(logs, recursive = TRUE, showWarnings = FALSE)
exports <- list.files(file.path(repo, "data/imported"), "[.]RData$", recursive = TRUE, full.names = TRUE)
before <- file.path(tempdir(), "release_exports")
dir.create(before, showWarnings = FALSE)
stopifnot(all(file.copy(exports, file.path(before, basename(exports)))))
worker <- tempfile(fileext = ".R")
writeLines(c(
  'args <- commandArgs(trailingOnly = TRUE)',
  'options(width = 140, device = function(...) grDevices::pdf(file = NULL))',
  'if (requireNamespace("data.table", quietly = TRUE)) data.table::setDTthreads(1L)',
  'input <- normalizePath(args[[1L]])',
  'code <- tempfile(fileext = ".R")',
  'knitr::purl(input, output = code, documentation = 0, quiet = TRUE)',
  'eval(parse(code), envir = .GlobalEnv)',
  'capture.output(sessionInfo(), file = args[[2L]])'
), worker)
statuses <- integer(nrow(catalog))
for (i in seq_len(nrow(catalog))) {
  importer <- catalog$importer[[i]]
  message("Rebuilding ", importer)
  # Existing Quarto paths are relative to the report's scripts directory.
  statuses[[i]] <- withr::with_dir(scripts_dir, system2(
    file.path(R.home("bin"), "Rscript"),
    c("--vanilla", shQuote(worker), shQuote(catalog$file[[i]]),
      shQuote(file.path(logs, paste0(importer, "_session.txt")))),
    stdout = file.path(logs, paste0(importer, ".log")),
    stderr = file.path(logs, paste0(importer, ".log"))
  ))
}
checks <- lapply(exports, function(path) {
  prior <- file.path(before, basename(path))
  if (identical(unname(tools::md5sum(prior)), unname(tools::md5sum(path)))) {
    return(data.frame(file = substring(path, nchar(repo) + 2L), matches_release = TRUE))
  }
  old <- new.env(parent = emptyenv())
  new <- new.env(parent = emptyenv())
  old_names <- load(prior, old)
  new_names <- load(path, new)
  same <- identical(old_names, new_names) && all(vapply(old_names, function(name) {
    isTRUE(all.equal(old[[name]], new[[name]], tolerance = 0, check.attributes = TRUE))
  }, logical(1)))
  data.frame(file = substring(path, nchar(repo) + 2L), matches_release = same)
})
checks <- do.call(rbind, checks)
write.csv(checks, file.path(logs, "export_checks.csv"), row.names = FALSE)
write.csv(data.frame(importer = catalog$importer, status = statuses),
          file.path(logs, "execution.csv"), row.names = FALSE)
if (any(statuses != 0L) || !all(checks$matches_release)) {
  stop("Rebuild or comparison failed. Inspect output/rebuild; generated exports were retained for diagnosis.")
}
message("All selected importers passed; all exports match the release at zero numeric tolerance.")
