# syntax=docker/dockerfile:1
FROM ubuntu:24.04 AS base

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
