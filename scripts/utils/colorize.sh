#!/bin/sh

colorize() {
  COLOR="$1"

  DEFAULT_COLOR_CODE=15

  case "$COLOR" in
    --black)
      shift
      COLOR_CODE=0
      ;;

    --maroon)
      shift
      COLOR_CODE=1
      ;;

    --green)
      shift
      COLOR_CODE=2
      ;;

    --olive)
      shift
      COLOR_CODE=3
      ;;

    --navy)
      shift
      COLOR_CODE=4
      ;;

    --purple)
      shift
      COLOR_CODE=5
      ;;

    --teal)
      shift
      COLOR_CODE=6
      ;;

    --silver)
      shift
      COLOR_CODE=7
      ;;

    --gray)
      shift
      COLOR_CODE=8
      ;;

    --red)
      shift
      COLOR_CODE=9
      ;;

    --lime)
      shift
      COLOR_CODE=10
      ;;

    --yellow)
      shift
      COLOR_CODE=11
      ;;

    --blue)
      shift
      COLOR_CODE=12
      ;;

    --fuchsia)
      shift
      COLOR_CODE=13
      ;;

    --aqua)
      shift
      COLOR_CODE=14
      ;;

    --white)
      shift
      COLOR_CODE=15
      ;;

    --bold-white)
      shift
      COLOR_MODIFIER=1
      COLOR_CODE=15
      ;;

    --xterm)
      shift
      MAYBE_COLOR_CODE=$1
      case "$MAYBE_COLOR_CODE" in
        [0-9] | [1-9][0-9] | 1[0-9][0-9] | [2][0-5][0-5])
          shift
          COLOR_CODE=$MAYBE_COLOR_CODE
          ;;

        *)
          COLOR_CODE=$DEFAULT_COLOR_CODE
          ;;
      esac
      ;;

    --*)
      shift
      COLOR_CODE=$DEFAULT_COLOR_CODE
      ;;

    *)
      COLOR_CODE=$DEFAULT_COLOR_CODE
      ;;
  esac

  if [ $# -eq 0 ] || [ "$NO_COLOR" = true ] || [ "$NO_COLOR" = 1 ]; then
    printf "%s" "$*"

  else
    printf "\033[38;${COLOR_MODIFIER:-5};${COLOR_CODE}m%s\033[0m" "$*"
  fi
}
