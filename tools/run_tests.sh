#!/bin/sh
# Runs the Godot test suite headless; fails on any test failure or script error.
cd "$(dirname "$0")/../game" || exit 1
G="../tools/bin/godot/Godot_v4.7.2-stable_win64_console.exe"
# refresh the class cache (new class_name scripts) before running
"$G" --headless --path . --import >/dev/null 2>&1
OUT=$(timeout 600 "$G" --headless --path . res://tests/test_runner.tscn 2>&1)
CODE=$?
echo "$OUT" | grep -E "FAIL|passed|^        " 
ERRS=$(echo "$OUT" | grep -c -E "SCRIPT ERROR|Parse Error|Compile Error")
if [ "$ERRS" -gt 0 ]; then
  echo "$OUT" | grep -A3 -E "SCRIPT ERROR|Parse Error|Compile Error" | head -60
  echo "!! $ERRS script errors"
  exit 1
fi
exit $CODE
