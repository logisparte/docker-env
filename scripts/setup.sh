#!/bin/sh -e

#
# Install git hooks
#

. ./scripts/utils/report.sh

report --info "[setup] -"

if [ -z "$CI" ]; then
  report --info "[setup] Installing git hooks"
  git config --local core.hooksPath scripts/hooks
fi

report --success "[setup] Done"
