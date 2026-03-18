#!/bin/bash
set -euo pipefail

# ============================================================
# User Management for sish tunnel server
# Manage SSH public keys for tunnel authentication
# ============================================================

# Load .env if exists
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
if [ -f "$PROJECT_DIR/.env" ]; then
    source "$PROJECT_DIR/.env"
fi

PUBKEYS_DIR="${PUBKEYS_DIR:-./data/pubkeys}"
mkdir -p "$PUBKEYS_DIR"

usage() {
    echo "Usage: $0 <command> [args]"
    echo ""
    echo "Commands:"
    echo "  add <username> <pubkey_file>   Add a user's SSH public key"
    echo "  add-key <username> <key>       Add a user's SSH public key from string"
    echo "  remove <username>              Remove a user's SSH public key"
    echo "  list                           List all authorized users"
    echo "  show <username>                Show a user's public key"
    echo ""
    echo "Examples:"
    echo "  $0 add alice ~/.ssh/id_rsa.pub"
    echo "  $0 add-key bob 'ssh-ed25519 AAAA... bob@laptop'"
    echo "  $0 remove alice"
    echo "  $0 list"
}

cmd_add() {
    local username="$1"
    local pubkey_file="$2"

    if [ ! -f "$pubkey_file" ]; then
        echo "Error: Public key file not found: $pubkey_file"
        exit 1
    fi

    # Validate it looks like an SSH public key
    if ! grep -qE '^ssh-(rsa|ed25519|ecdsa)|^ecdsa-sha2' "$pubkey_file"; then
        echo "Error: File does not appear to be a valid SSH public key."
        exit 1
    fi

    cp "$pubkey_file" "${PUBKEYS_DIR}/${username}.pub"
    echo "Added user: $username"
    echo "Key: $(head -c 60 "${PUBKEYS_DIR}/${username}.pub")..."
    echo ""
    echo "User can now connect with:"
    echo "  ssh -R <subdomain>:80:localhost:<port> tunnel.example.com -p 2222"
}

cmd_add_key() {
    local username="$1"
    shift
    local key="$*"

    if [[ ! "$key" =~ ^ssh-(rsa|ed25519|ecdsa)|^ecdsa-sha2 ]]; then
        echo "Error: Does not appear to be a valid SSH public key."
        exit 1
    fi

    echo "$key" > "${PUBKEYS_DIR}/${username}.pub"
    echo "Added user: $username"
    echo ""
    echo "User can now connect with:"
    echo "  ssh -R <subdomain>:80:localhost:<port> tunnel.example.com -p 2222"
}

cmd_remove() {
    local username="$1"
    local keyfile="${PUBKEYS_DIR}/${username}.pub"

    if [ ! -f "$keyfile" ]; then
        echo "Error: User not found: $username"
        exit 1
    fi

    rm "$keyfile"
    echo "Removed user: $username"
    echo "Note: Active connections will persist until disconnected."
}

cmd_list() {
    echo "Authorized tunnel users:"
    echo "========================"
    local count=0
    for f in "${PUBKEYS_DIR}"/*.pub 2>/dev/null; do
        if [ -f "$f" ]; then
            local name
            name=$(basename "$f" .pub)
            local key_type
            key_type=$(awk '{print $1}' "$f")
            local key_comment
            key_comment=$(awk '{print $3}' "$f")
            printf "  %-20s %-20s %s\n" "$name" "$key_type" "${key_comment:-}"
            ((count++))
        fi
    done
    if [ "$count" -eq 0 ]; then
        echo "  (no users)"
    fi
    echo ""
    echo "Total: $count user(s)"
}

cmd_show() {
    local username="$1"
    local keyfile="${PUBKEYS_DIR}/${username}.pub"

    if [ ! -f "$keyfile" ]; then
        echo "Error: User not found: $username"
        exit 1
    fi

    echo "User: $username"
    echo "Key:"
    cat "$keyfile"
}

# Main
if [ $# -lt 1 ]; then
    usage
    exit 1
fi

COMMAND="$1"
shift

case "$COMMAND" in
    add)
        [ $# -lt 2 ] && { echo "Error: add requires <username> <pubkey_file>"; exit 1; }
        cmd_add "$1" "$2"
        ;;
    add-key)
        [ $# -lt 2 ] && { echo "Error: add-key requires <username> <key>"; exit 1; }
        cmd_add_key "$@"
        ;;
    remove)
        [ $# -lt 1 ] && { echo "Error: remove requires <username>"; exit 1; }
        cmd_remove "$1"
        ;;
    list)
        cmd_list
        ;;
    show)
        [ $# -lt 1 ] && { echo "Error: show requires <username>"; exit 1; }
        cmd_show "$1"
        ;;
    *)
        echo "Unknown command: $COMMAND"
        usage
        exit 1
        ;;
esac
