#!/bin/sh

list_dirty_files() {
  git status --porcelain | grep '^\s*[AMR]' | awk '{print $NF}' 2> /dev/null
}
