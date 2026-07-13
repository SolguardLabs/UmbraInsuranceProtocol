#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

resolve_forge() {
    if command -v forge >/dev/null 2>&1; then
        command -v forge
        return
    fi
    if command -v forge.exe >/dev/null 2>&1; then
        command -v forge.exe
        return
    fi
    if [ -n "${HOME:-}" ] && [ -x "$HOME/.foundry/bin/forge.exe" ]; then
        printf '%s\n' "$HOME/.foundry/bin/forge.exe"
        return
    fi
    if command -v powershell.exe >/dev/null 2>&1 \
        && powershell.exe -NoProfile -ExecutionPolicy Bypass -Command \
            "if (Get-Command forge -ErrorAction SilentlyContinue) { exit 0 } else { exit 1 }" >/dev/null 2>&1; then
        printf '%s\n' "__POWERSHELL_FORGE__"
        return
    fi
    echo "error: forge no esta disponible en PATH" >&2
    exit 127
}

ps_quote() {
    local value="${1//\'/\'\'}"
    printf "'%s'" "$value"
}

run_forge() {
    local forge_bin
    forge_bin="$(resolve_forge)"
    if [[ "$(uname -s)" == Linux* && ("$forge_bin" == *.exe || "$forge_bin" == "__POWERSHELL_FORGE__") \
        && ! -e /proc/sys/fs/binfmt_misc/WSLInterop ]]; then
        echo "error: este WSL no puede ejecutar binarios Windows; instala Foundry nativo o ejecuta forge desde PowerShell" >&2
        exit 127
    fi
    if [[ "$forge_bin" != "__POWERSHELL_FORGE__" && ("$(uname -s)" != Linux* || "$forge_bin" != *.exe) ]]; then
        "$forge_bin" "$@"
        return
    fi

    command -v powershell.exe >/dev/null 2>&1 || {
        echo "error: forge.exe no puede ejecutarse directamente y powershell.exe no esta disponible" >&2
        exit 127
    }
    local win_cwd
    win_cwd="$(wslpath -w "$PWD")"
    local command_text="Set-Location -LiteralPath $(ps_quote "$win_cwd"); forge"
    local arg
    for arg in "$@"; do
        command_text+=" $(ps_quote "$arg")"
    done
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$command_text"
}

bash scripts/bootstrap.sh

run_forge test -vvv
