library(blit)
library(yaml)

# ============================================================
# CONFIG GENERATION
# ============================================================

generate_ciriquant_yaml <- function(cfg, outfile) {
  dir.create(dirname(outfile), showWarnings = FALSE, recursive = TRUE)

  env_bin <- file.path(cfg$environments$env_CIRIquant, "bin")

  ciri_cfg <- list(
    name = "auto_build",
    tools = list(
      bwa       = file.path(env_bin, "bwa"),
      hisat2    = file.path(env_bin, "hisat2"),
      samtools  = file.path(env_bin, "samtools"),
      stringtie = file.path(env_bin, "stringtie")
    ),
    reference = list(
      fasta       = cfg$reference$fasta,
      gtf         = cfg$reference$gtf,
      bwa_index   = cfg$reference$fasta,
      hisat_index = cfg$reference$fasta
    )
  )

  yaml::write_yaml(ciri_cfg, outfile)
}

generate_config_sh <- function(cfg, outfile, ciri_yaml) {
  dir.create(dirname(outfile), showWarnings = FALSE, recursive = TRUE)

  lines <- c(
    paste0("fasta=", cfg$reference$fasta),
    paste0("gtf=", cfg$reference$gtf),
    paste0("ann_ref=", cfg$reference$ann_ref),
    paste0("gdir=", cfg$reference$star_index),
    paste0("bt2_INDEX=", cfg$reference$bt2_INDEX),
    paste0("CIRI_config=", ciri_yaml)
  )
  writeLines(lines, outfile)
}

cfg <- yaml::read_yaml("input.yml")

ciri_yaml <- file.path(cfg$data$pipeline_dir, "CIRIquant/hg38.yml")
generate_ciriquant_yaml(cfg, ciri_yaml)
generate_config_sh(cfg, file.path(cfg$data$pipeline_dir, "config.sh"), ciri_yaml)

# ============================================================
# ENV
# ============================================================

Sys.setenv(
  RAW_FASTQ_DIR = cfg$data$raw_fastq_dir,
  FASTP_OUTDIR = cfg$data$fastp_dir,
  REF_BASE = cfg$reference$base_dir,
  GENOME = cfg$reference$genome,
  REF_FASTA = cfg$reference$fasta,
  REF_GTF = cfg$reference$gtf,
  STAR_INDEX = cfg$reference$star_index,
  BT2_PREFIX = cfg$reference$bt2_INDEX,
  ENV_CIRCRNA_FINDER = cfg$environments$env_circRNA_finder,
  ENV_CIRIQUANT = cfg$environments$env_CIRIquant,
  ENV_FINDCIRC = cfg$environments$env_FindCirc,
  ENV_CE2 = cfg$environments$env_CE2,
  CIRI_CONFIG = ciri_yaml,
  THREADS = cfg$threads,
  MICROMAMBA = cfg$environments$micromamba
)

pipeline_dir  <- cfg$data$pipeline_dir
fqfile        <- cfg$data$sample_list
indir         <- cfg$data$fastp_dir
outdir        <- cfg$data$result_dir
config        <- file.path(pipeline_dir, "config.sh")
nthreads_prog <- cfg$threads

# ============================================================
# LOG SYSTEM
# ============================================================

run_call_log <- file.path(outdir, "RUN_CALL.log")
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)

sink(log_con, split = TRUE)
sink(log_con, type = "message")

cat("========== BLIT CALL START ==========\n")
cat("Time :", format(Sys.time()), "\n")
cat("Log  :", run_call_log, "\n\n")

log_con <- file(run_call_log, open = "at")

# ============================================================
# STEP 0
# ============================================================

cat("[Step 0] Prepare reference & tools...\n")

cmd0 <- exec("bash", file.path(pipeline_dir, "prepare/prepare_index.sh"))
cmd_run(cmd0, stdout = log_con, stderr = log_con)

if (!dir.exists(indir)) {
  cat("fastp output directory not found, running fastp prepare...\n")
  cmd_fastp <- exec("bash", file.path(pipeline_dir, "prepare/prepare_fastp.sh")) |>
    cmd_condaenv("fastp")
  cmd_run(cmd_fastp, stdout = log_con, stderr = log_con)
} else {
  cat("fastp output directory exists, skipping fastp prepare.\n")
}

# ============================================================
# STEP 1
# ============================================================

cat("[Step 1] Generate sample list...\n")

cmd_llfq <- exec(
  "python",
  file.path(pipeline_dir, "common/ll_fq.py"),
  indir,
  "--output", fqfile
)
cmd_run(cmd_llfq, stdout = log_con, stderr = log_con)

samples <- readLines(fqfile)
cat("Total samples:", length(samples), "\n\n")

# ============================================================
# STEP 2
# ============================================================

tools <- list(
  CIRIquant = list(script = "CIRIquant/CIRIquant.sh", env = "CIRIquant"),
  FindCirc = list(script = "FindCirc/FindCirc.sh", env = "FindCirc"),
  Circexplorer2 = list(script = "Circexplorer2/Circexplorer2.sh", env = "Circexplorer2"),
  circRNA_finder = list(script = "circRNA_finder/circRNA_finder.sh", env = "circRNA_finder")
)

cat("[Step 2] circRNA analysis (sequential)\n\n")

for (sample in samples) {
  cat("===> Processing sample:", sample, "\n")

  for (tool_name in names(tools)) {
    tool <- tools[[tool_name]]
    cat("----> Running", tool_name, "\n")

    cmd_tool <- exec(
      "bash",
      file.path(pipeline_dir, tool$script),
      sample,
      indir,
      outdir,
      as.character(nthreads_prog),
      config
    ) |> cmd_condaenv(tool$env)

    cmd_run(cmd_tool, stdout = log_con, stderr = log_con)
  }

  cat("===> Sample finished:", sample, "\n\n")
}

# ============================================================
cat("\n========== BLIT CALL END ==========\n")
cat("RUN_CALL.log:", run_call_log, "\n")
cat("Next step: run_aggr.R\n")

sink(type = "message")
sink()

close(log_con)