#!/bin/sh

list_staged_files() {
  git diff --cached --name-only --diff-filter=ACMR | awk '{print $NF}' 2> /dev/null
}
