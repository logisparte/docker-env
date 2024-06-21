#!/bin/sh

. ./scripts/utils/colorize.sh

report() {
  KIND="$1"

  case "$KIND" in
    --success)
      shift
      MESSAGE="$(colorize --lime "$*")"
      ;;

    --info)
      shift
      MESSAGE="$(colorize --aqua "$*")"
      ;;

    --warning)
      shift
      MESSAGE="$(colorize --yellow "$*")"
      ;;

    --error)
      shift
      MESSAGE="$(colorize --red "$*")"
      ;;

    *)
      MESSAGE="$*"
      ;;
  esac

  if [ "$KIND" = "--error" ]; then
    printf "%s\n" "$MESSAGE" >&2

  else
    printf "%s\n" "$MESSAGE"
  fi
}
