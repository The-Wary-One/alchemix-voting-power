#!/usr/bin/env bash

### SCRIPT SETUP ###
set -o errexit  # When a command fails, bash exits instead of continuing with the rest of the script.
set -o nounset  # Make the script fail when accessing an unset variable. To access a variable that may or may not have been set, use "${VARNAME-}".
set -o pipefail # Ensure that a pipeline command is treated as failed, even if one command in the pipeline fails.
if [[ "${TRACE-0}" == "1" ]]; then
    set -o xtrace # Enable debug mode when called with `TRACE=1`.
fi

cd "$(dirname "$0")" # Change to the directory containing this script.

### UTILITIES ###
function fmttxt {
    # ANSI text formatting: https://misc.flogisoft.com/bash/tip_colors_and_formatting.

    local -a formatting_codes_start_arr=() # Create a local -to the function- indexed array.
    local -a formatting_codes_end_arr=()

    while [[ "$1" =~ ^--?[a-z]+$ ]]; do # Loop over the args like '-f' or '--flag'.
        case "$1" in
        --bold)
            formatting_codes_start_arr+=('1')
            formatting_codes_end_arr+=('22')
            ;;
        --underlined)
            formatting_codes_start_arr+=('4')
            formatting_codes_end_arr+=('24')
            ;;
        *)
            echo 'Invalid flag.' >&2
            exit 1
            ;;
        esac
        shift
    done

    local -r remaining_txt="$*" # Join the remaining args with the default '$IFS' separator (i.e. ' ') as a local readonly string.
    local -r IFS=";"            # Temporarly override the default IFS string separator with the ANSI separator (i.e. ';').
    echo -e "\x1B[${formatting_codes_start_arr[*]}m$remaining_txt\x1B[${formatting_codes_end_arr[*]}m"
}

### COMMANDS ###
function testcommand {
    forge test \
        --fork-url "${RPC_MAINNET}" \
        --fork-block-number "${BLOCK_NUMBER_MAINNET}"
}

### MAIN SCRIPT ###
function main {
    if [[ -e ./.env ]]; then # Source .env only if it exists.
        source .env          # Add all global variables and functions to the current shell.
    fi

    case "${1-}" in
    test | t)
        shift "$#" # Remove all remaining arguments.
        testcommand
        ;;

    *)
        echo "This is a helper cli.

$(fmttxt --bold --underlined 'Usage:') $(fmttxt --bold './cli.sh') <COMMAND>

$(fmttxt --bold --underlined 'Commands:')
    $(fmttxt --bold 'help')         Print this message
    $(fmttxt --bold 'test')         Run the project's tests [aliases: t]
"
        exit 0
        ;;
    esac
}

main "$@"
