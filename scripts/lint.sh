#!/bin/sh -e

. ./scripts/utils/colorize.sh
. ./scripts/utils/git/list_all_files.sh
. ./scripts/utils/git/list_dirty_files.sh
. ./scripts/utils/git/list_staged_files.sh
. ./scripts/utils/report.sh

FILTER="${1:-dirty}"

case "$FILTER" in
  dirty)
    report --info "[lint] Linting dirty files only"
    FILES="$(list_dirty_files)"
    ;;

  staged)
    report --info "[lint] Linting staged files only"
    FILES=$(list_staged_files)
    ;;

  all)
    report --info "[lint] Linting all files"
    FILES="$(list_all_files)"
    ;;

  *)
    report --error "[lint] Unknown filter: '$FILTER'"
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

MARKDOWN_FILES="$(echo "$FILES" | grep -e "\.md$" || true)"
if [ -n "$MARKDOWN_FILES" ]; then
  report --info "Markdown files >>"
  report "$(colorize --gray "$MARKDOWN_FILES")"
  echo "$MARKDOWN_FILES" | xargs markdownlint
fi

SHELLCHECK_FILES="$(echo "$FILES" | grep -e "\.sh$" || true)"
if [ -n "$SHELLCHECK_FILES" ]; then
  report --info "Shell files >>"
  report "$(colorize --gray "$SHELLCHECK_FILES")"
  echo "$SHELLCHECK_FILES" | xargs shellcheck
fi

report --success "[lint] Done"
