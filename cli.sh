#!/usr/bin/env bash

### SCRIPT SETUP ###
set -o errexit  # When a command fails, bash exits instead of continuing with the rest of the script.
set -o nounset  # Make the script fail when accessing an unset variable. To access a variable that may or may not have been set, use "${VARNAME-}".
set -o pipefail # Ensure that a pipeline command is treated as failed, even if one command in the pipeline fails.
if [[ "${TRACE-0}" == "1" ]]; then
    set -o xtrace # Enable debug mode when called with `TRACE=1`.
fi

### UTILITIES ###
function fmttxt {
    # ANSI text formatting: https://misc.flogisoft.com/bash/tip_colors_and_formatting.
    # E.g. to apply the 'bold' formatting to the 'Hello' text, we can output '\x1B[1mHello\x1B[22m' to the terminal.
    # E.g. to apply the 'bold' and 'underlined' formatting to the 'Hello' text, we can output '\x1B[1;4mHello\x1B[22;24m' to the terminal.

    local -a formatting_codes_start_arr=() # Create a local -to the function- indexed array.
    local -a formatting_codes_end_arr=()

    while [[ "${1}" =~ ^--?[a-z]+$ ]]; do # Loop over the args like '-f' or '--flag'.
        case "${1}" in
        --bold)
            formatting_codes_start_arr+=('1')
            formatting_codes_end_arr+=('22')
            ;;
        --underlined)
            formatting_codes_start_arr+=('4')
            formatting_codes_end_arr+=('24')
            ;;
        --red)
            formatting_codes_start_arr+=('31')
            formatting_codes_end_arr+=('39')
            ;;
        *)
            printf 'Invalid flag.\n' 1>&2
            exit 1
            ;;
        esac
        shift
    done

    local -r remaining_txt="${*}" # Join the remaining args with the default '$IFS' separator (i.e. ' ') as a local readonly string.
    local -r IFS=";"              # Temporarly override the default IFS string separator with the ANSI separator (i.e. ';').
    printf "\x1B[%sm%s\x1B[%sm\n" "${formatting_codes_start_arr[*]}" "${remaining_txt}" "${formatting_codes_end_arr[*]}"
}

### COMMANDS ###
function _usage {
    # Use 'heredoc' into 'cat' to show the usage message.
    cat <<EOF
This is a helper cli.

$(fmttxt --bold --underlined 'Usage:') $(fmttxt --bold './cli.sh') <COMMAND>

$(fmttxt --bold --underlined 'Commands:')
    $(fmttxt --bold 'help')         Print this message
    $(fmttxt --bold 'build')        Build the smart contracts
    $(fmttxt --bold 'check')        Check formatting and linting
    $(fmttxt --bold 'test')         Run the project's tests [aliases: t]

EOF
}

function _build {
    forge --version
    forge build --sizes
}

function _check {
    shellcheck --external-sources ./*.sh script/*.sh # Lint the sh scripts.
    forge fmt --check                                # Check the contracts formatting.
}

function _test {
    forge test --no-match-path '**/linea/*' "${@}"
    FOUNDRY_PROFILE=linea forge test --match-path '**/linea/*' "${@}"
}

### MAIN SCRIPT ###
# shellcheck disable=SC2317 # Disable the false positive unreachable code.
function cleanup {
    local -ir exit_code=${?} # When exitting the script, store the exit code as a local -to the function- readonly integer.

    # Cleanup code here.
    if [[ ${exit_code} -gt 0 ]]; then                                                            # If there is an error.
        printf '%s\n' "$(fmttxt --red "Something went wrong during the script execution.")" 1>&2 # Print the error message to stderr.
    fi

    exit "${exit_code}"
}

trap cleanup EXIT ERR # Exit trap to make the script more robust (e.g. similar to a try/catch/finally to run some cleanup code).

cd "$(dirname "${0}")" # Change to the directory containing this script.

function main {
    if [[ ${#} == 0 ]]; then # Print usage message if no args are provided.
        _usage
        exit 0
    fi

    local -r command="${1}"
    shift

    case "$command" in
    -h | --help | h | help)
        shift "${#}" # Remove all remaining arguments.
        _usage
        ;;
    build)
        shift "${#}"
        _build
        ;;
    check)
        shift "${#}"
        _check
        ;;
    t | test)
        _test "${@}"
        ;;
    *)
        printf '%s\n\n' "$(fmttxt --red "Invalid command: ${command} ${*}")" 1>&2
        _usage
        exit 1
        ;;
    esac
}

main "${@}"
exit 0
