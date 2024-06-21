#!/bin/sh -e

. ./scripts/utils/report.sh

report --info "[postclone] Configuring git hooks"
git config --local core.hooksPath "$PWD/hooks"
report --success "[postclone] Done"
