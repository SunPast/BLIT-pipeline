library(blit)
library(yaml)

cfg <- yaml::read_yaml("input.yml")

pipeline_dir <- cfg$data$pipeline_dir
outdir       <- cfg$data$result_dir
fqfile       <- cfg$data$sample_list
aggr_dir     <- file.path(outdir, "aggr")
dir.create(aggr_dir, showWarnings = FALSE, recursive = TRUE)

sample_anno <- fqfile

Sys.setenv(
  GTF_PATH  = cfg$reference$gtf,
  COMMON_PY = file.path(pipeline_dir, "common/common.py")
)

run_aggr_log <- file.path(outdir, "RUN_AGGR.log")
log_con <- file(run_aggr_log, open = "at")
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)

sink(log_con, split = TRUE)
sink(log_con, type = "message")

cat("========== BLIT AGGR START ==========\n")
cat("Time :", format(Sys.time()), "\n")
cat("Log  :", run_aggr_log, "\n\n")

# ============================================================
# CHECK
# ============================================================

cat("Checking if all tools have completed...\n")

check_completion <- function() {
  methods <- c("CIRI", "find_circ", "circexplorer2", "circRNA_finder")
  samples <- readLines(fqfile)
  all_complete <- TRUE
  for (sample in samples) {
    for (method in methods) {
      bed_file <- file.path(outdir, paste0(sample, ".", method, ".bed"))
      if (!file.exists(bed_file) || file.info(bed_file)$size == 0) {
        cat("Missing or empty:", basename(bed_file), "\n")
        all_complete <- FALSE
      }
    }
  }
  all_complete
}

if (!check_completion()) stop("Missing BED files")

# ============================================================
# STEP 1
# ============================================================

cat("[STEP 1] aggr_beds\n")

cmd1 <- exec(
  "Rscript",
  file.path(pipeline_dir, "aggr/aggr_beds.R"),
  outdir,
  aggr_dir
) |> cmd_condaenv("aggr")

cmd_run(cmd1, stdout = log_con, stderr = log_con)

# ============================================================
# STEP 2
# ============================================================

cat("[STEP 2] aggr_dataset\n")

cmd2 <- exec(
  "Rscript",
  file.path(pipeline_dir, "aggr/aggr_dataset.R"),
  aggr_dir,
  aggr_dir,
  sample_anno
) |> cmd_condaenv("aggr")

cmd_run(cmd2, stdout = log_con, stderr = log_con)

cat("\n========== BLIT AGGR END ==========\n")
cat("Full log:", run_aggr_log, "\n")

sink(type = "message")
sink()

close(log_con)
