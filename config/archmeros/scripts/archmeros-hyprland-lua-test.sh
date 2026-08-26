#!/usr/bin/env bash
# ArchMerOS - Safe Hyprland Lua Migration Test Script
# Provides an auto-reverting timed test for the new Lua configuration.

set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
REPO_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/../../.." && pwd)"
HYPR_DIR="${REPO_ROOT}/config/hypr"
BACKUP_DIR="${HYPR_DIR}/legacy-conf-backup"

CONF_FILE="${HYPR_DIR}/hyprland.conf"
CONF_BAK="${HYPR_DIR}/hyprland.conf.inactive"
LUA_FILE="${HYPR_DIR}/hyprland.lua"

notify() {
    local title="$1"
    local msg="$2"
    if command -v hyprctl >/dev/null 2>&1; then
        hyprctl notify -1 5000 "rgb(58d6ff)" "${title}: ${msg}" >/dev/null 2>&1 || true
    fi
}

verify_lua() {
    printf "\033[1;34m[1/3] Verifying hyprland.lua syntax with Hyprland --verify-config...\033[0m\n"
    if ! Hyprland -c "${LUA_FILE}" --verify-config; then
        printf "\033[1;31m[ERROR] Lua configuration verification failed! Aborting without changes.\033[0m\n"
        exit 1
    fi
    printf "\033[1;32m[OK] Lua configuration is 100%% valid.\033[0m\n\n"
}

revert_to_conf() {
    printf "\n\033[1;33m[REVERT] Reverting to hyprland.conf...\033[0m\n"
    if [[ -f "${CONF_BAK}" ]]; then
        mv -f "${CONF_BAK}" "${CONF_FILE}"
    elif [[ -f "${BACKUP_DIR}/hyprland.conf" ]]; then
        cp -f "${BACKUP_DIR}/hyprland.conf" "${CONF_FILE}"
    fi

    if command -v hyprctl >/dev/null 2>&1; then
        hyprctl reload config-only >/dev/null 2>&1 || true
    fi
    notify "ArchMerOS Hyprland" "Reverted back to classic hyprland.conf"
    printf "\033[1;32m[OK] Successfully reverted to classic .conf configuration.\033[0m\n"
}

apply_lua_permanently() {
    printf "\n\033[1;32m[APPLY] Applying hyprland.lua permanently...\033[0m\n"
    if [[ -f "${CONF_FILE}" ]]; then
        mv -f "${CONF_FILE}" "${CONF_BAK}"
    fi
    if command -v hyprctl >/dev/null 2>&1; then
        hyprctl reload config-only >/dev/null 2>&1 || true
    fi
    notify "ArchMerOS Hyprland" "Hyprland Lua configuration is now permanently ACTIVE"
    printf "\033[1;32m[OK] hyprland.lua is now the active configuration.\033[0m\n"
    printf "\033[0;36m(Original .conf is preserved at: %s)\033[0m\n" "${BACKUP_DIR}/hyprland.conf"
}

run_timed_test() {
    local duration="${1:-30}"
    verify_lua

    printf "\033[1;33m[2/3] Starting timed test for %s seconds...\033[0m\n" "${duration}"
    printf "\033[0;37m- hyprland.conf will be temporarily deactivated\033[0m\n"
    printf "\033[0;37m- Hyprland will reload with hyprland.lua\033[0m\n"
    printf "\033[0;37m- If you do NOT confirm within %s seconds, it automatically reverts to .conf\033[0m\n\n" "${duration}"

    # Move conf out of the way so Hyprland picks lua
    if [[ -f "${CONF_FILE}" ]]; then
        mv "${CONF_FILE}" "${CONF_BAK}"
    fi

    # Reload hyprland
    if command -v hyprctl >/dev/null 2>&1; then
        hyprctl reload config-only >/dev/null 2>&1 || true
    fi
    notify "ArchMerOS Hyprland" "Testing Lua config! Auto-reverting in ${duration}s..."

    # Setup trap to revert on SIGINT / Ctrl+C or premature exit
    trap 'revert_to_conf; exit 1' INT TERM

    printf "\033[1;36mTesting Lua config now.\033[0m\n"
    printf "Try your keybindings, workspace switching, floating windows, etc.\n\n"

    # Countdown loop with non-blocking read
    local remaining="${duration}"
    local confirmed=false

    while (( remaining > 0 )); do
        printf "\r\033[1;33mAuto-reverting in %2d seconds... Press [y/ENTER] to KEEP or [n/Ctrl+C] to REVERT: \033[0m" "${remaining}"
        if read -r -t 1 -n 1 user_input; then
            if [[ "${user_input}" == "y" || "${user_input}" == "Y" || -z "${user_input}" ]]; then
                confirmed=true
                break
            elif [[ "${user_input}" == "n" || "${user_input}" == "N" ]]; then
                printf "\nUser selected revert.\n"
                revert_to_conf
                return 0
            fi
        fi
        ((remaining--))
    done

    if [[ "${confirmed}" == "true" ]]; then
        printf "\n\n\033[1;32m[CONFIRMED] Keeping Lua configuration!\033[0m\n"
        notify "ArchMerOS Hyprland" "Lua configuration confirmed and active!"
    else
        printf "\n\n\033[1;31m[TIMEOUT] Time expired without confirmation. Auto-reverting...\033[0m\n"
        revert_to_conf
    fi
}

case "${1:-test}" in
    test)
        run_timed_test "${2:-30}"
        ;;
    apply)
        verify_lua
        apply_lua_permanently
        ;;
    revert)
        revert_to_conf
        ;;
    verify)
        verify_lua
        ;;
    *)
        printf "Usage: %s [test <seconds>|apply|revert|verify]\n" "$0"
        exit 1
        ;;
esac
