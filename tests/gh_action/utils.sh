#!/bin/bash

# ------------------------------
# UTILS
# ------------------------------
PROJECT_MOUNT_DIR="${PROJECT_MOUNT_DIR:-"tmp/project"}"
ACTION_SH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/src/gh_action/action.sh"

log() {
  printf '%b\n' "$*"
}

error() {
  log >&2 "\033[31m$*\033[0m"
}

run_test() {
    local test_name="${1:?Test name not provided}"
    test_name="${test_name//_/ }"
    test_name="$(tr "[:lower:]" "[:upper:]" <<< "${test_name:0:1}")${test_name:1}"

    # Set Defaults based on action.yml
    [ -z "${WITH_VAR_DIRECTORY:-}" ] && local WITH_VAR_DIRECTORY="."
    [ -z "${WITH_VAR_CONFIG_FILE:-}" ] && local WITH_VAR_CONFIG_FILE=""
    [ -z "${WITH_VAR_NO_OPERATION_MODE:-}" ] && local WITH_VAR_NO_OPERATION_MODE="false"
    [ -z "${WITH_VAR_VERBOSITY:-}" ] && local WITH_VAR_VERBOSITY="1"

    # Build the `env` invocation: map every WITH_VAR_* into INPUT_* for the action.sh process.
    local env_assignments=()
    local with_vars
    with_vars="$(compgen -A variable | grep "^WITH_VAR_")"
    while IFS= read -r var; do
        [ -z "$var" ] && continue
        env_assignments+=("INPUT_${var#WITH_VAR_}=${!var}")
    done <<< "$with_vars"

    # Give psr a writable GITHUB_OUTPUT so its action-output writer does not
    # choke, and so outputs do not leak between tests.
    local output_file
    output_file="$(mktemp)"
    env_assignments+=("GITHUB_OUTPUT=${output_file}")

    # Run the test
    log "\n$test_name"
    log "--------------------------------------------------------------------------------"
    local rc=0
    (
        cd "${PROJECT_MOUNT_DIR}" || exit 1
        env "${env_assignments[@]}" bash "${ACTION_SH}"
    ) || rc=$?
    rm -f "${output_file}"
    return "$rc"
}

export UTILS_LOADED="true"
