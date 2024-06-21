# syntax=docker/dockerfile:1
FROM ubuntu:24.04 AS base

RUN <<EOF
  DEBIAN_FRONTEND=noninteractive \
    apt-get update && apt-get install --yes --quiet --no-install-recommends \
      sudo \
  apt-get clean
  rm -rf /var/lib/apt/lists/*
EOF
