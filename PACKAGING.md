# MatrixEQTL packaging (conda + Docker)

Packaging of [CRAN MatrixEQTL 2.4](https://CRAN.R-project.org/package=MatrixEQTL) for reproducible builds used by [SiYangming/variant2qtl](https://github.com/SiYangming/variant2qtl).

| Field | Value |
| --- | --- |
| Package version | `2.4` |
| Upstream | [MatrixEQTL_2.4.tar.gz](https://cran.r-project.org/src/contrib/MatrixEQTL_2.4.tar.gz) |
| Conda | `YangmingSi::matrixeqtl=2.4` |
| Docker | `quay.io/bioinfortools/matrixeqtl:2.4` |

**Version rule:** conda package version and Docker image tag are the **same string** (`2.4`).

## Contents

- `upstream/MatrixEQTL_2.4.tar.gz` — CRAN source tarball
- `upstream/SHA256SUMS` — checksum
- `recipe/` — conda-build / rattler-build recipe (noarch)
- `scripts/matrixeqtl.R` — CLI wrapper installed as `matrixeqtl`
- `Dockerfile` — linux/amd64 image with MatrixEQTL 2.4, CLI, and `plink2`

## License / attribution

Upstream is LGPL-3. Cite:

> Shabalin AA (2012) Matrix eQTL: ultra fast eQTL analysis via large matrix operations. *Bioinformatics* 28(10):1353–1358.

## Build (maintainers)

```bash
conda activate conda_build

# Docker (linux/amd64)
docker build --platform linux/amd64 -t quay.io/bioinfortools/matrixeqtl:2.4 .
docker push quay.io/bioinfortools/matrixeqtl:2.4

# Conda (noarch)
rattler-build build -r recipe
anaconda upload --user YangmingSi output/noarch/matrixeqtl-*.conda
# or: conda-build recipe && anaconda upload --user YangmingSi ...
```

## CLI

```bash
matrixeqtl \
  --SNP_file SNP.txt \
  --exp_file GE.txt \
  --covariates_file Covariates.txt \
  --snps_loc snpsloc.txt \
  --gene_loc geneloc.txt \
  --output_prefix out/prefix \
  --cis_window 1000000 \
  --pv_cis 1e-4 \
  --pv_trans 0 \
  --threads 4
```

Outputs: `{prefix}_eQTL_cis.txt.gz` and optionally `{prefix}_eQTL_trans.txt.gz`.
