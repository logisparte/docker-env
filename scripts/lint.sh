#!/bin/sh -e

#
# Lint files
#

. ./scripts/utils/report.sh

lint() {
  EXTENSION="$1"

  report --info "[lint] Linting ${EXTENSION:-all} files"
  case "$EXTENSION" in
    "")
      _lint_sh
      _lint_md
      ;;

    sh | md)
      "_lint_$EXTENSION"
      ;;

    *)
      report --error "[lint] Unknown file extension: $EXTENSION"
      exit 1
      ;;

  esac

  report --success "[lint] Done"
}

_lint_sh() {
  find scripts -name "*.sh" -type f -exec shellcheck {} \;
}

_lint_md() {
  markdownlint --ignore-path .gitignore .
}

lint "$@"
