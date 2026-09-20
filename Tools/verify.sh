#!/bin/bash
# Checks the scheduling maths and runs one real warm through the Claude CLI.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/Sources/ClaudePrewarm"
OUT="$(mktemp -d)"
swiftc -o "$OUT/verify" "$ROOT/Tools/Verify/main.swift" \
    "$SRC"/Models/*.swift \
    "$SRC/Services/ClaudeRunner.swift" \
    "$SRC/Services/ProcessRunner.swift" \
    "$SRC/Services/UsageReader.swift" \
    "$SRC/Services/SettingsStore.swift" \
    "$SRC"/Utilities/*.swift
"$OUT/verify"
