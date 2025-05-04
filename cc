#!/bin/bash
set -euo pipefail

create_checkpoint_meta_files() {
  readonly -- TIMESTAMP_PATTERN='20[0-9][0-9][0-1][0-9][0-3][0-9]_[0-2][0-9][0-5][0-9][0-5][0-9]*'

  local -- ROOT_DIR DIR_TIME LAST_DIR

  local -- basedir date time

  local -a BackupFiles=()
  readarray -t BackupFiles < <(find /var/backups/ -maxdepth 1 -type d | sort)

  for ROOT_DIR in "${BackupFiles[@]}"; do
    ROOT_DIR=$(readlink -fn -- "$ROOT_DIR")

    LAST_DIR=$(find "$ROOT_DIR" -maxdepth 1 -type d -name "$TIMESTAMP_PATTERN" -printf '%T@ %p\n' \
      | sort -nr \
      | head -n 1 \
      | cut -d' ' -f2-)
    [[ -z $LAST_DIR ]] && continue

    # checkpoint backup dir has been identified
    basedir=$(basename -- "$LAST_DIR")
    IFS='_' read -r date time <<<"$basedir"
    date="${date:0:4}-${date:4:2}-${date:6:2}"
    time="${time:0:2}:${time:2:2}:${time:4:2}"
    DIR_TIME="${date} ${time}"

    { declare -p LAST_DIR |cut -d ' ' -f3-
      declare -p DIR_TIME |cut -d ' ' -f3-
    } >"$ROOT_DIR"/.checkpoint

    touch -d "$DIR_TIME" "$ROOT_DIR"/.checkpoint "$LAST_DIR"
  done
}

create_checkpoint_meta_files "$@"
#fin
