#!/bin/bash

# Find which Verilog file and net is causing WNS violation
# Usage: ./scripts/find_wns_source.sh

set -e

RUNS_DIR="./runs"
RECENT_RUN="$RUNS_DIR/recent"

if [ ! -L "$RECENT_RUN" ]; then
    echo "Error: No recent run found. Run 'make openlane' first."
    exit 1
fi

ACTUAL_RUN=$(readlink -f "$RECENT_RUN")
echo "Analyzing run: $ACTUAL_RUN"
echo ""

# Find the latest timing report
TIMING_REPORT=$(find "$ACTUAL_RUN" -name "*sta.rpt" -o -name "*timing.rpt" 2>/dev/null | head -1)

if [ -z "$TIMING_REPORT" ]; then
    echo "Error: No timing report found in $ACTUAL_RUN"
    exit 1
fi

echo "Found timing report: $TIMING_REPORT"
echo ""
echo "========================================"
echo "CRITICAL PATH ANALYSIS"
echo "========================================"
echo ""

# Extract the critical path timing info
if grep -q "Startpoint" "$TIMING_REPORT"; then
    echo "--- Critical Path ---"
    grep -A 30 "Startpoint\|worst negative slack" "$TIMING_REPORT" | head -50
else
    echo "No detailed path info found. Showing worst slack summary:"
    grep -i "slack\|wns" "$TIMING_REPORT" | head -20
fi

echo ""
echo "========================================"
echo "NET NAME MAPPING"
echo "========================================"
echo ""

# Extract signal/net names from the critical path
# Look for nets mentioned in path (usually in parentheses or after @ symbol)
NETS=$(grep -o '\b[a-zA-Z_][a-zA-Z0-9_]*\b' "$TIMING_REPORT" | sort -u | head -40)

echo "Searching for critical path nets in Verilog files..."
echo ""

RTL_FILES=$(find ./rtl -name "*.sv" -o -name "*.v")

for net in $NETS; do
    for file in $RTL_FILES; do
        if grep -n "\b$net\b" "$file" > /dev/null 2>&1; then
            MATCHES=$(grep -n "\b$net\b" "$file" | head -3)
            if [ ! -z "$MATCHES" ]; then
                echo "Found '$net' in $(basename $file):"
                echo "$MATCHES" | sed 's/^/  /'
                echo ""
            fi
        fi
    done
done

echo "========================================"
echo "To get more detailed path info, check:"
echo "  cat $TIMING_REPORT"
echo "========================================"
