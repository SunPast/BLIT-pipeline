[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.18920618.svg)](https://doi.org/10.5281/zenodo.18920618)

# CircRNA Identification and Integration Pipeline (BLIT Version)

## Purpose

This project is a **BLIT-integrated refactor** of the original circRNA pipeline:   https://github.com/OncoHarmony-Network/circrna-pipeline

The **biological workflow is unchanged**, but the infrastructure has been modernized:

- All conda/mamba environment creation is handled by **BLIT (`appmamba`)**
- All shell orchestration is replaced with **BLIT functions** (`exec()`, `cmd_condaenv()`)
- The pipeline demonstrates how **BLIT manages a real multi-tool bioinformatics workflow**

The pipeline detects circRNAs from paired-end FASTQ files using four methods:

- **CIRIquant**
- **Circexplorer2**
- **find_circ**
- **circRNA_finder**

Results from all methods are integrated using an ensemble aggregation strategy.

------

## Step 1. Prepare References

You have to prepare genome reference files:

- Genome FASTA (e.g. `GRCh38.primary_assembly.genome.fa`)
- Gene annotation GTF (e.g. `gencode.v34.annotation.gtf`)

------

## Step 2. Install Required Environments

Install tool environments. Run in R:

```r
source("init_env.R")
```

This reproduces the original pipeline's `justfile` installations using BLIT.

|  Environment   |                           Software                           |
| :------------: | :----------------------------------------------------------: |
|     fastp      |                            fastp                             |
|    FindCirc    |               find_circ=1.2, bowtie2, samtools               |
| Circexplorer2  |             python=3.7, bwa, pip, circexplorer2              |
|   CIRIquant    | python=2.7, bwa=0.7.17, hisat2=2.2.0, stringtie=2.1.1, samtools=1.10, CIRIquant=1.1.2 |
| circRNA_finder |                circrna_finder, star, samtools                |
|      aggr      |               r-base=4.2, r-data.table, radian               |

------

## Step 3. ⚠️ Configure the Pipeline

This pipeline is **not plug-and-play** until you configure paths.

Hence you need to edit `input.yml`.

This file controls:

- FASTQ input location
- Output directory
- Reference paths
- CPU threads
- Environment locations

You do **NOT** need to edit scripts directly.

------

## Step 4. Preprocessing & Run circRNA Detection

Run in R:

```r
source("run_call.R")
```

This script:

1. Generates references and indexes if their directory has not been found
2. Processes fastp for raw files if fastp output directory has not been found
3. Generates the sample list automatically if it has not been found
4. Runs all four circRNA callers sequentially, and each tool executes inside its BLIT-managed environment
5. Logs are written to `RUN_CALL.log`

Output per sample:

```
sample.CIRI.bed
sample.circexplorer2.bed
sample.find_circ.bed
sample.circRNA_finder.bed
```

------

## Step 5. Aggregate Results

Run:

```r
source("run_aggr.R")
```

This step:

1. Checks that all tools completed
2. Merges circRNA predictions
3. Annotates circRNAs using GTF
4. Produces final integrated dataset

5. Logs are written to `RUN_AGGR.log`.

------

## Notes

1. CIRIquant

   CIRIquant only supports **Python 2**.  We installed it via:

   ```
   pip install CIRIquant==1.1.2
   ```

2. CIRCexplorer2

   The annotation for this tool relies on its internal script fetch_ucsc.py to download genome_ref.txt from the UCSC server. Therefore, the download may fail when your network connection is unstable.
   To address this, we have also provided hg38_ref.txt in the repository for emergency use. You can directly use it if you encounter issues during your own configuration.

   We recommend you refer to the [CIRCexplorer2 official documentation](https://circexplorer2.readthedocs.io/en/latest/) for more information.

3. Thread Control

   Threads are controlled in:

   ```
   input.yml → threads:
   ```

4. PATH to appmamba

   All conda environments are created under:

   ```
   ~/.local/share/R/blit/appmamba/envs/
   ```

------

  ## References

  - Original pipeline: [OncoHarmony-Network/circrna-pipeline](https://github.com/OncoHarmony-Network/circrna-pipeline)
  - Pipeline inspiration: [Yelab2020/ICBcircSig](https://github.com/Yelab2020/ICBcircSig), [nf-core/circrna](https://github.com/nf-core/circrna)
  - BLIT: [WangLabCSU/BLIT](https://github.com/WangLabCSU/BLIT)
