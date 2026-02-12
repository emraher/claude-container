FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# ── System packages ──────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        apt-utils git curl ca-certificates sudo wget gnupg \
        build-essential \
        python3 python3-dev python3-venv \
        locales \
    && sed -i 's/^# *\(en_US.UTF-8\)/\1/' /etc/locale.gen \
    && locale-gen \
    && rm -rf /var/lib/apt/lists/*

# ── R (latest from CRAN) + r2u (CRAN packages as Ubuntu binaries) ─
RUN curl -fsSL https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc \
        | tee -a /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc > /dev/null \
    && echo "deb https://cloud.r-project.org/bin/linux/ubuntu noble-cran40/" \
        > /etc/apt/sources.list.d/cran-ubuntu.list \
    && curl -fsSL https://eddelbuettel.github.io/r2u/assets/dirk_eddelbuettel_key.asc \
        | tee -a /etc/apt/trusted.gpg.d/cranapt_key.asc > /dev/null \
    && echo "deb https://r2u.stat.illinois.edu/ubuntu noble main" \
        > /etc/apt/sources.list.d/cranapt.list \
    && echo "Package: *"                       >  /etc/apt/preferences.d/99cranapt \
    && echo "Pin: release o=CRAN-Apt Project"  >> /etc/apt/preferences.d/99cranapt \
    && echo "Pin: release l=CRAN-Apt Packages" >> /etc/apt/preferences.d/99cranapt \
    && echo "Pin-Priority: 700"                >> /etc/apt/preferences.d/99cranapt \
    && apt-get update && apt-get install -y --no-install-recommends r-base \
    && rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# ── Node.js 22 via NodeSource ────────────────────────────────────
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# ── DuckDB CLI (architecture-aware) ─────────────────────────────
ARG DUCKDB_VERSION=1.4.3
RUN ARCH=$(dpkg --print-architecture) \
    && curl -fsSL "https://github.com/duckdb/duckdb/releases/download/v${DUCKDB_VERSION}/duckdb_cli-linux-${ARCH}.zip" -o /tmp/duckdb.zip \
    && apt-get update && apt-get install -y --no-install-recommends unzip \
    && unzip /tmp/duckdb.zip -d /usr/local/bin \
    && chmod +x /usr/local/bin/duckdb \
    && rm /tmp/duckdb.zip \
    && apt-get purge -y unzip && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# ── just ─────────────────────────────────────────────────────────
RUN curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to /usr/local/bin

# ── Non-root user with passwordless sudo ─────────────────────────
RUN userdel -r ubuntu 2>/dev/null || true \
    && useradd -m -s /bin/bash -u 1000 coder \
    && echo "coder ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/coder

USER coder
WORKDIR /home/coder

# ── uv (Python package manager) ─────────────────────────────────
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/home/coder/.local/bin:${PATH}"

# ── Claude Code CLI ──────────────────────────────────────────────
RUN curl -fsSL https://claude.ai/install.sh | bash

# ── Config files ─────────────────────────────────────────────────
RUN mkdir -p /home/coder/.claude
COPY --chown=coder:coder config/claude-settings.json /home/coder/.claude/settings.json
COPY --chown=coder:coder config/CLAUDE.md /home/coder/.claude/CLAUDE.md

WORKDIR /workspace
