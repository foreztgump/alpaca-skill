#!/usr/bin/env bash
# tests/run_tests.sh — Discover and run all test_*.sh files
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

PASS=0
FAIL=0
ERRORS=""

for test_file in "${SCRIPT_DIR}"/test_*.sh; do
  [[ -f "$test_file" ]] || continue
  test_name=$(basename "$test_file")
  if bash "$test_file"; then
    PASS=$((PASS + 1))
    echo "  PASS  $test_name"
  else
    FAIL=$((FAIL + 1))
    ERRORS="${ERRORS}  FAIL  ${test_name}\n"
    echo "  FAIL  $test_name"
  fi
done

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [[ $FAIL -gt 0 ]]; then
  echo -e "\nFailed tests:\n${ERRORS}"
  exit 1
fi
