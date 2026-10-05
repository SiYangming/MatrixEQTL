#!/usr/bin/env Rscript
# CLI wrapper for MatrixEQTL 2.4 (cis + optional trans).
# Installed as /usr/local/bin/matrixeqtl in the Docker/conda package.

suppressPackageStartupMessages({
  library(MatrixEQTL)
  library(optparse)
})

option_list <- list(
  make_option("--SNP_file", type = "character", help = "Genotype matrix (SNP x sample)"),
  make_option("--exp_file", type = "character", help = "Expression matrix (gene x sample)"),
  make_option("--covariates_file", type = "character", default = NULL,
              help = "Optional covariates matrix (cov x sample)"),
  make_option("--snps_loc", type = "character", help = "SNP location table (snp, chr, pos)"),
  make_option("--gene_loc", type = "character", help = "Gene location table (geneid, chr, s1, s2)"),
  make_option("--output_prefix", type = "character", help = "Output prefix"),
  make_option("--cis_window", type = "integer", default = 1000000L, help = "Cis distance [default %default]"),
  make_option("--pv_cis", type = "double", default = 1e-4, help = "Cis p-value threshold [default %default]"),
  make_option("--pv_trans", type = "double", default = 0, help = "Trans p-value threshold; 0 disables trans [default %default]"),
  make_option("--model", type = "character", default = "linear",
              help = "Model: linear|anova|linear_cross [default %default]"),
  make_option("--slice_size", type = "integer", default = 2000L, help = "SlicedData slice size [default %default]"),
  make_option("--threads", type = "integer", default = 1L, help = "BLAS threads [default %default]")
)

opt <- parse_args(OptionParser(option_list = option_list, add_help_option = TRUE))

required <- c("SNP_file", "exp_file", "snps_loc", "gene_loc", "output_prefix")
missing <- required[vapply(required, function(k) is.null(opt[[k]]) || !nzchar(opt[[k]]), logical(1))]
if (length(missing)) {
  stop("Missing required options: ", paste(missing, collapse = ", "), call. = FALSE)
}

for (path in c(opt$SNP_file, opt$exp_file, opt$snps_loc, opt$gene_loc)) {
  if (!file.exists(path)) stop("File not found: ", path, call. = FALSE)
}
if (!is.null(opt$covariates_file) && nzchar(opt$covariates_file) && !file.exists(opt$covariates_file)) {
  stop("Covariates file not found: ", opt$covariates_file, call. = FALSE)
}

out_dir <- dirname(opt$output_prefix)
if (!dir.exists(out_dir) && out_dir != ".") {
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
}

nthreads <- max(1L, as.integer(opt$threads))
Sys.setenv(
  OPENBLAS_NUM_THREADS = nthreads,
  OMP_NUM_THREADS = nthreads,
  MKL_NUM_THREADS = nthreads
)
if (requireNamespace("RhpcBLASctl", quietly = TRUE)) {
  RhpcBLASctl::blas_set_num_threads(nthreads)
}

useModel <- switch(
  tolower(opt$model),
  linear = modelLINEAR,
  anova = modelANOVA,
  linear_cross = modelLINEAR_CROSS,
  stop("Unsupported --model: ", opt$model, call. = FALSE)
)

load_sliced <- function(path, slice_size) {
  sd <- SlicedData$new()
  sd$fileDelimiter <- "\t"
  sd$fileOmitCharacters <- "NA"
  sd$fileSkipRows <- 1
  sd$fileSkipColumns <- 1
  sd$fileSliceSize <- as.integer(slice_size)
  sd$LoadFile(path)
  sd
}

snps <- load_sliced(opt$SNP_file, opt$slice_size)
gene <- load_sliced(opt$exp_file, opt$slice_size)
cvrt <- SlicedData$new()
cvrt$fileDelimiter <- "\t"
cvrt$fileOmitCharacters <- "NA"
cvrt$fileSkipRows <- 1
cvrt$fileSkipColumns <- 1
if (!is.null(opt$covariates_file) && nzchar(opt$covariates_file)) {
  cvrt$fileSliceSize <- as.integer(opt$slice_size)
  cvrt$LoadFile(opt$covariates_file)
}

snpspos <- read.table(opt$snps_loc, header = TRUE, stringsAsFactors = FALSE, sep = "\t", check.names = FALSE)
genepos <- read.table(opt$gene_loc, header = TRUE, stringsAsFactors = FALSE, sep = "\t", check.names = FALSE)

# Accept common column aliases
colnames(snpspos) <- tolower(colnames(snpspos))
colnames(genepos) <- tolower(colnames(genepos))
if (!all(c("snp", "chr", "pos") %in% colnames(snpspos))) {
  # try snps / snp_id
  if ("snps" %in% colnames(snpspos)) colnames(snpspos)[colnames(snpspos) == "snps"] <- "snp"
  if ("snp_id" %in% colnames(snpspos)) colnames(snpspos)[colnames(snpspos) == "snp_id"] <- "snp"
}
if (!all(c("geneid", "chr", "s1", "s2") %in% colnames(genepos))) {
  if ("gene" %in% colnames(genepos)) colnames(genepos)[colnames(genepos) == "gene"] <- "geneid"
  if ("gene_id" %in% colnames(genepos)) colnames(genepos)[colnames(genepos) == "gene_id"] <- "geneid"
  if ("start" %in% colnames(genepos)) colnames(genepos)[colnames(genepos) == "start"] <- "s1"
  if ("end" %in% colnames(genepos)) colnames(genepos)[colnames(genepos) == "end"] <- "s2"
}

pv_trans <- as.numeric(opt$pv_trans)
cis_only <- !is.finite(pv_trans) || pv_trans <= 0
output_cis <- paste0(opt$output_prefix, "_eQTL_cis.txt")
output_trans <- paste0(opt$output_prefix, "_eQTL_trans.txt")

options(MatrixEQTL.dont.preserve.gene.object = TRUE)

me <- Matrix_eQTL_main(
  snps = snps,
  gene = gene,
  cvrt = cvrt,
  output_file_name = if (cis_only) NULL else output_trans,
  pvOutputThreshold = if (cis_only) 0 else pv_trans,
  useModel = useModel,
  errorCovariance = numeric(),
  verbose = TRUE,
  output_file_name.cis = output_cis,
  pvOutputThreshold.cis = as.numeric(opt$pv_cis),
  snpspos = snpspos[, c("snp", "chr", "pos")],
  genepos = genepos[, c("geneid", "chr", "s1", "s2")],
  cisDist = as.numeric(opt$cis_window),
  pvalue.hist = FALSE,
  min.pv.by.genesnp = FALSE,
  noFDRsaveMemory = TRUE
)

if (file.exists(output_cis)) {
  system2("gzip", args = c("-f", output_cis))
}
if (!cis_only && file.exists(output_trans)) {
  system2("gzip", args = c("-f", output_trans))
}

cat("MatrixEQTL finished.\n")
invisible(me)
