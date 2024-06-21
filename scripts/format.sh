#!/bin/sh -e

. ./scripts/utils/colorize.sh
. ./scripts/utils/git/list_all_files.sh
. ./scripts/utils/git/list_dirty_files.sh
. ./scripts/utils/git/list_staged_files.sh
. ./scripts/utils/report.sh

FILTER="${1:-dirty}"

case "$FILTER" in
  dirty)
    report --info "[format] Formatting dirty files only"
    FILES="$(list_dirty_files)"
    ;;

  staged)
    report --info "[format] Formatting staged files only"
    FILES=$(list_staged_files)
    ;;

  all)
    report --info "[format] Formatting all files"
    FILES="$(list_all_files)"
    ;;

  *)
    report --error "[format] Unknown filter: '$FILTER'"
    exit 1
    ;;
esac

# Skip symbolic links
FILES="$({
  for FILE in $FILES; do
    [ -L "$FILE" ] && continue
    echo "$FILE"
  done
})"

PRETTIER_FILES="$(echo "$FILES" | grep -e "\.md$" -e "\.yml$" -e "\.yaml$" || true)"
if [ -n "$PRETTIER_FILES" ]; then
  report --info "Markdown and yaml files >>"
  echo "$PRETTIER_FILES" | xargs prettier --write
fi

SHFMT_FILES="$(echo "$FILES" | grep -e "\.sh$" || true)"
if [ -n "$SHFMT_FILES" ]; then
  report --info "Shell files >>"
  report "$(colorize --gray "$SHFMT_FILES")"
  echo "$SHFMT_FILES" | xargs shfmt -p -w -bn -ci -sr -kp -i 2
fi

report --success "[format] Done"
