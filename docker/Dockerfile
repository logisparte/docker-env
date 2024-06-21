# syntax=docker/dockerfile:1
FROM ubuntu:24.04 AS base

LABEL org.opencontainers.image.authors="@logisparte"
LABEL org.opencontainers.image.source="https://github.com/logisparte/docker-env"

RUN <<EOF
  DEBIAN_FRONTEND=noninteractive \
    apt-get update && apt-get install --yes --quiet --no-install-recommends \
      apt-transport-https \
      bash \
      ca-certificates \
      curl \
      git \
      gnupg2 \
      software-properties-common \
      ssh-client \
      sudo \
      vim \
      wget \
      zsh
  apt-get clean
  rm -rf /var/lib/apt/lists/*
EOF

ENV EDITOR="/usr/bin/vim"

FROM base AS project

RUN <<EOF
  curl --silent --fail --show-error --location https://deb.nodesource.com/setup_lts.x \
    | bash -
  DEBIAN_FRONTEND=noninteractive \
    apt-get update && apt-get install --yes --quiet --no-install-recommends \
      nodejs \
      shellcheck \
      shfmt
  npm config --location=global set update-notifier=false fund=false
  npm install --location=global --omit=dev --omit=optional \
    markdownlint-cli \
    prettier \
    @commitlint/cli
  npm cache clean --force
  apt-get clean
  rm -rf /var/lib/apt/lists/*
EOF
