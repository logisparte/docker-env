#!/bin/sh -e

#
# Format files
#

. ./scripts/utils/colorize.sh
. ./scripts/utils/report.sh

format() {
  EXTENSION="$1"

  report --info "[format] Formatting ${EXTENSION:-all} files"
  case "$EXTENSION" in
    "")
      _format_sh
      _format_prettier
      ;;

    sh)
      "_format_sh"
      ;;

    yaml | md)
      _format_prettier "$EXTENSION"
      ;;

    *)
      report --error "[format] Unknown file extension: $EXTENSION"
      exit 1
      ;;

  esac

  report --success "[format] Done"
}

_format_sh() {
  SHELL_FILES="$(find scripts -name "*.sh" -type f)"
  report "$(colorize --gray "$SHELL_FILES")"
  echo "$SHELL_FILES" | xargs shfmt -p -w -bn -ci -sr -i 2
}

_format_prettier() {
  EXTENSION="$1"

  if [ -n "$EXTENSION" ]; then
    prettier --ignore-unknown --write "./**/*.$EXTENSION"
  else
    prettier --ignore-unknown --write .
  fi
}

format "$@"
