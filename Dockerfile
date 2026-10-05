# MatrixEQTL 2.4 — tag must match conda: quay.io/bioinfortools/matrixeqtl:2.4
# Prefer docker.1ms.run mirror when Docker Hub is unreachable; override:
#   docker build --build-arg BASE=rocker/r-ver:4.4.2 ...
ARG BASE=docker.1ms.run/rocker/r-ver:4.4.2
FROM ${BASE}

LABEL org.opencontainers.image.title="matrixeqtl" \
      org.opencontainers.image.version="2.4" \
      org.opencontainers.image.description="MatrixEQTL 2.4 with CLI wrapper and plink2" \
      org.opencontainers.image.source="https://github.com/SiYangming/MatrixEQTL"

ENV DEBIAN_FRONTEND=noninteractive

USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        wget \
        unzip \
        python3 \
        zlib1g \
        libgomp1 \
    && rm -rf /var/lib/apt/lists/*

COPY upstream/MatrixEQTL_2.4.tar.gz /tmp/MatrixEQTL_2.4.tar.gz
RUN R -e "install.packages(c('optparse','RhpcBLASctl'), repos='https://cloud.r-project.org', quiet=TRUE)" \
    && R -e "install.packages('/tmp/MatrixEQTL_2.4.tar.gz', repos=NULL, type='source')" \
    && rm -f /tmp/MatrixEQTL_2.4.tar.gz \
    && R -e "stopifnot(packageVersion('MatrixEQTL') >= '2.4')"

ARG PLINK2_URL=https://s3.amazonaws.com/plink2-assets/plink2_linux_avx2_20241114.zip
RUN wget -q "${PLINK2_URL}" -O /tmp/plink2.zip \
    && unzip -j /tmp/plink2.zip plink2 -d /usr/local/bin \
    && chmod +x /usr/local/bin/plink2 \
    && rm -f /tmp/plink2.zip

COPY scripts/matrixeqtl.R /usr/local/bin/matrixeqtl
RUN chmod +x /usr/local/bin/matrixeqtl

WORKDIR /data
CMD ["matrixeqtl", "--help"]
