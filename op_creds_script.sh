#!/bin/bash

# 1Password Credentials Getter
# Retrieves username, password, and OTP from 1Password
#

set -euo pipefail


# Defaults
ITEM_NAME=""
SHOW_USERNAME=false
SHOW_PASSWORD=false
SHOW_OTP=false
SHOW_ALL=true
FORMAT="text"

my_name=$(basename "$0")


# Usage
usage() {
    cat << EOF
Usage: "${my_name}" [OPTIONS] <item_name>

Retrieve username, password, and OTP from 1Password

OPTIONS:
    --user         Output only the username
    --pass         Output only the password
    --otp          Output only the OTP code
    --format FMT   Output format: text (default), json, or sh
    -h, --help     Show this help message

ARGUMENTS:
    item_name      Name or ID of the 1Password item

FORMATS:
    text          text-readable formatted output (default)
    json           JSON object output
    sh             Shell variable assignments (suitable for sourcing)

EXAMPLES:
    "${my_name}"
    "${my_name}" --user "Git Site"             # Show only username
    "${my_name}" --pass "Git Site"             # Show only password
    "${my_name}" --user --otp "Git Site"       # Show username and OTP
    "${my_name}" --format json "Git Site"      # JSON output
    "${my_name}" --format sh "Git Site"        # Shell variables
    "${my_name}" --format JSON "Git Site"      # Case insensitive

NOTES:
    - Prints passwords on the console for all to see.
    - Stores passwords in non-exported nvironment variables.
    - In X11 and MacOS environments, password is automatically copied to
      clipboard.
    - Requires 1Password CLI (op) to be installed and authenticated
    - Requires jq to be installed:  jqlang.org
    - If no field options are specified, default fields are output
EOF
}


# Check external tooling
check_dependencies() {
    local missing_deps=()

    if ! command -v op >/dev/null 2>&1; then
        missing_deps+=("1Password CLI (op)")
    fi

    if ! command -v jq >/dev/null 2>&1; then
        missing_deps+=("jq")
    fi

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo "Error: Missing required dependencies:" >&2
        printf "  - %s\n" "${missing_deps[@]}" >&2
        echo "" >&2
        echo "Please install the missing dependencies and try again." >&2
        exit 1
    fi
}


# Retrieve data from 1Password and parse
get_1password_creds() {
    local item_name="$1"
    local format="$2"
    local show_all="$3"
    local show_username="$4"
    local show_password="$5"
    local show_otp="$6"
    local json_data


    # progress for console output
    if [[ "$format" == "text" ]]; then
        echo "Connecting to 1Password..." >&2
    fi

    # retrieve from 1Password instance
    if ! printf -v json_data '%s' \
        "$(op item get "${item_name}" --format json 2>/dev/null)"
    then
        echo "Error: Could not retrieve item ${item_name}" >&2
        echo "Check: 1) 1Password is running"
        echo "       2) CLI is enabled in 1Password settings"
        echo "       3) the item exists"
        return 1
    fi

    # Check if json_data is empty
    if [[ -z "$json_data" ]]; then
        echo "Error: Could not retrieve item '$item_name'" >&2
        echo "Make sure you're signed in to 1Password CLI and the item \
              exists." >&2
        return 1
    fi

    # Parse JSON with jq
    USERNAME=$(echo "$json_data" | \
        jq -r '(.fields[] | select(.purpose=="USERNAME") | .value) // ""')
    PASSWORD=$(echo "$json_data" | \
        jq -r '(.fields[] | select(.purpose=="PASSWORD") | .value) // ""')
    OTP=$(echo "$json_data" | \
        jq -r '(.fields[] | select(.type=="OTP") | .totp) // ""')

    if [[ -z "$USERNAME" && -z "$PASSWORD" && -z "$OTP" ]]; then
        echo "Error: Fields not found in item '$item_name'" >&2
        return 1
    fi

    # Handle clipboard operations in X environment
    if [[ -n "$DISPLAY" && -n "$PASSWORD" && "$format" == "text" && \
          ("$show_all" == "true" || "$show_password" == "true") ]]
    then
        if command -v xclip >/dev/null 2>&1; then
            echo -n "$PASSWORD" | xclip -selection clipboard 2>/dev/null
            echo -n "$PASSWORD" | xclip -selection primary 2>/dev/null
            echo "✓ Password copied to clipboard and primary selection" >&2
        elif command -v xsel >/dev/null 2>&1; then
            echo -n "$PASSWORD" | xsel --clipboard 2>/dev/null
            echo -n "$PASSWORD" | xsel --primary 2>/dev/null
            echo "✓ Password copied to clipboard and primary selection" >&2
        else
            echo "ℹ No clipboard tool found (install xclip or xsel for \
                  clipboard support)" >&2
        fi
    fi

    # Determine which fields to output
    local output_username=""
    local output_password=""
    local output_otp=""

    if [[ "$show_all" == "true" ]]; then
        output_username="$USERNAME"
        output_password="$PASSWORD"
        output_otp="$OTP"
    else
        [[ "$show_username" == "true" ]] && output_username="$USERNAME"
        [[ "$show_password" == "true" ]] && output_password="$PASSWORD"
        [[ "$show_otp" == "true" ]] && output_otp="$OTP"
    fi

    # Output based on format
    case "$format" in
        json)
            # Build JSON output
            local json_output="{"
            local first=true

            if [[ -n "$output_username" || "$show_username" == "true" ]]; then
                json_output+="\"username\":\"${output_username:-}\""
                first=false
            fi

            if [[ -n "$output_password" || "$show_password" == "true" ]]; then
                [[ "$first" == "false" ]] && json_output+=","
                json_output+="\"password\":\"${output_password:-}\""
                first=false
            fi

            if [[ -n "$output_otp" || "$show_otp" == "true" ]]; then
                [[ "$first" == "false" ]] && json_output+=","
                json_output+="\"otp\":\"${output_otp:-}\""
                first=false
            fi

            json_output+="}"
            echo "$json_output"
            ;;

        sh)
            # Shell variable assignments with proper quoting
            if [[ -n "$output_username" || "$show_username" == "true" ]]; then
                printf "USERNAME=%q\n" "${output_username:-}"
            fi

            if [[ -n "$output_password" || "$show_password" == "true" ]]; then
                printf "PASSWORD=%q\n" "${output_password:-}"
            fi

            if [[ -n "$output_otp" || "$show_otp" == "true" ]]; then
                printf "OTP=%q\n" "${output_otp:-}"
            fi
            ;;

        text)
            if [[ "$show_all" == "true" ]]; then
                # Show all fields (formatted output)
                echo ""
                echo "=== Credentials for: $item_name ==="
                echo "Username: ${USERNAME:-[not found]}"
                echo "Password: ${PASSWORD:-[not found]}"
                echo "OTP:      ${OTP:-[not found]}"
                echo ""
            else
                # Show only requested fields (simple output)
                local output_count=0

                if [[ "$show_username" == "true" ]]; then
                    echo "${USERNAME:-[username not found]}"
                    ((output_count++))
                fi

                if [[ "$show_password" == "true" ]]; then
                    echo "${PASSWORD:-[password not found]}"
                    ((output_count++))
                fi

                if [[ "$show_otp" == "true" ]]; then
                    echo "${OTP:-[otp not found]}"
                    ((output_count++))
                fi

                # If no fields were found, show an error
                if [[ $output_count -eq 0 ]]; then
                    echo "Error: No requested fields found in item '$item_name'" >&2
                    return 1
                fi
            fi
            ;;
    esac
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --user)
                SHOW_USERNAME=true
                SHOW_ALL=false
                shift
                ;;
            --pass)
                SHOW_PASSWORD=true
                SHOW_ALL=false
                shift
                ;;
            --otp)
                SHOW_OTP=true
                SHOW_ALL=false
                shift
                ;;
            --format)
                if [[ $# -lt 2 ]]; then
                    echo "Error: --format requires a value" >&2
                    echo "Use --help for usage information." >&2
                    exit 1
                fi
                FORMAT=$(echo "$2" | tr '[:upper:]' '[:lower:]')
                case "$FORMAT" in
                    text|json|sh)
                        # Valid format
                        ;;
                    *)
                        echo "Error: Invalid format '$2'. Must be one of: \
                              text, json, sh" >&2
                        exit 1
                        ;;
                esac
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -*)
                echo "Error: Unknown option '$1'" >&2
                echo "Use --help for usage information." >&2
                exit 1
                ;;
            *)
                if [[ -z "$ITEM_NAME" ]]; then
                    ITEM_NAME="$1"
                else
                    echo "Error: Multiple item names specified" >&2
                    echo "Use --help for usage information." >&2
                    exit 1
                fi
                shift
                ;;
        esac
    done

    # Validate required arguments
    if [[ -z "$ITEM_NAME" ]]; then
        echo "Error: Item name is required" >&2
        echo "Use --help for usage information." >&2
        exit 1
    fi
}


# Main function
main() {
    # Parse command line arguments
    parse_args "$@"

    # Check dependencies
    check_dependencies

    # Get credentials
    get_1password_creds "$ITEM_NAME" "$FORMAT" "$SHOW_ALL" "$SHOW_USERNAME" \
                        "$SHOW_PASSWORD" "$SHOW_OTP"
}


# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
