#!/usr/bin/env bash

set -euo pipefail

# Capture `code` output (both stdout and stderr) so we can filter warnings
output=$(code --list-extensions 2>&1) || rc=$?

# Check for error JSON patterns (like {"name":"Error"}) before filtering
if printf '%s' "$output" | grep -qE '^\s*{.*"name"\s*:\s*"Error'; then
    printf 'Error when invoking the extension management command: %s\n' "$(printf '%s' "$output" | grep -E '^\s*{.*"name"\s*:\s*"Error' | head -1)" >&2
    exit 1
fi

# Remove known noisy warning lines and any header/footer lines that aren't extension IDs
filtered=$(printf '%s' "$output" | \
    sed '/^Ignoring option/d' | \
    sed '/^Extensions installed on SSH/d' | \
    sed '/^\\s*$/d' | \
sed '/^~\//d')

# If `code` returned a non-zero exit code, surface that
if [ "${rc:-0}" -ne 0 ]; then
    printf '%s\n' "$output" >&2
    exit ${rc}
fi

# Build a proper JSON array of strings without a trailing comma
tmp=/tmp/extensions.json
mapfile -t lines < <(printf '%s\n' "$filtered")
printf '[' > "$tmp"
for i in "${!lines[@]}"; do
    line=${lines[$i]}
    # escape backslashes and double quotes
    esc=${line//\\/\\\\}
    esc=${esc//"/\\"}
    printf '%s' "\"$esc\"" >> "$tmp"
    if [ "$i" -lt "$((${#lines[@]}-1))" ]; then
        printf ',' >> "$tmp"
    fi
done
printf ']\n' >> "$tmp"
