#!/usr/bin/env bash
# Run all checkpoint test suites and provide summary

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "\n${YELLOW}========================================${NC}"
echo -e "${YELLOW}     CHECKPOINT TEST SUITE RUNNER${NC}"
echo -e "${YELLOW}========================================${NC}\n"

# Track overall results
declare -i total_passed=0
declare -i total_failed=0
declare -i total_skipped=0

# Run each test suite
for test_file in tests/*.bats; do
    if [[ ! -f "$test_file" ]]; then
        continue
    fi

    test_name=$(basename "$test_file" .bats)
    echo -e "\n${YELLOW}Running: $test_name${NC}"
    echo "----------------------------------------"

    # Run tests and capture output
    if output=$(bats "$test_file" 2>&1); then
        status=0
    else
        status=$?
    fi

    # Parse results
    passed=$(echo "$output" | grep -c "^ok " || true)
    failed=$(echo "$output" | grep -c "^not ok " || true)
    skipped=$(echo "$output" | grep -c "# skip" || true)
    total=$(echo "$output" | grep "^1\.\." | sed 's/1\.\.//')

    # Update totals
    ((total_passed += passed - skipped)) || true
    ((total_failed += failed)) || true
    ((total_skipped += skipped)) || true

    # Display results
    if [[ $failed -eq 0 ]]; then
        echo -e "${GREEN}✓ All tests passed!${NC}"
        echo "  Passed: $((passed - skipped)), Skipped: $skipped"
    else
        echo -e "${RED}✗ Some tests failed${NC}"
        echo "  Passed: $((passed - skipped)), Failed: $failed, Skipped: $skipped"

        # Show which tests failed
        echo -e "\n  ${RED}Failed tests:${NC}"
        echo "$output" | grep "^not ok " | sed 's/^/    /'
    fi
done

# Display summary
echo -e "\n${YELLOW}========================================${NC}"
echo -e "${YELLOW}             SUMMARY${NC}"
echo -e "${YELLOW}========================================${NC}"

if [[ $total_failed -eq 0 ]]; then
    echo -e "${GREEN}✓ ALL TESTS PASSED!${NC}"
else
    echo -e "${RED}✗ SOME TESTS FAILED${NC}"
fi

echo -e "\nTotal Results:"
echo -e "  ${GREEN}Passed:${NC}  $total_passed"
echo -e "  ${RED}Failed:${NC}  $total_failed"
echo -e "  ${YELLOW}Skipped:${NC} $total_skipped"
echo -e "  Total:    $((total_passed + total_failed + total_skipped))"

# Exit with appropriate code
[[ $total_failed -eq 0 ]] && exit 0 || exit 1