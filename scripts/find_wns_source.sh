#!/bin/bash

# Find timing violations and which Verilog file/line is causing them
# Usage: ./scripts/find_wns_source.sh [run_name] [corner]
#        ./scripts/find_wns_source.sh           (uses runs/recent, nom_ss_100C_1v60)
#        ./scripts/find_wns_source.sh RUN_2026-02-27_07-28-15
#        ./scripts/find_wns_source.sh recent nom_ss_100C_1v60

RUNS_DIR="./runs"
RUN_NAME="${1:-.}"  # Use provided argument or default to "."
CORNER="${2:-nom_ss_100C_1v60}"  # Default corner for worst timing

# If run_name is just "." (default), use the recent symlink
if [ "$RUN_NAME" = "." ]; then
    TARGET_RUN="$RUNS_DIR/recent"
else
    TARGET_RUN="$RUNS_DIR/$RUN_NAME"
fi

if [ ! -e "$TARGET_RUN" ]; then
    echo "Run directory not found: $TARGET_RUN"
    echo "Available runs in $RUNS_DIR:"
    ls -1 "$RUNS_DIR" | grep -v recent
    exit 1
fi

ACTUAL_RUN=$(readlink -f "$TARGET_RUN")

# STA reports are in the OpenROAD step directory with corner subdirectories
STA_BASE="$ACTUAL_RUN/12-openroad-staprepnr"

if [ ! -d "$STA_BASE" ]; then
    echo "STA directory not found: $STA_BASE"
    echo "Available directories in run:"
    ls -1d "$ACTUAL_RUN"/*openroad* 2>/dev/null
    exit 1
fi

# If corner not found, list available corners
if [ ! -d "$STA_BASE/$CORNER" ]; then
    echo "Corner '$CORNER' not found. Available corners:"
    ls -1d "$STA_BASE"/*/ 2>/dev/null | sed 's|.*/||;s|/$||'
    echo ""
    echo "Using first available corner..."
    CORNER=$(ls -1d "$STA_BASE"/*/ 2>/dev/null | head -1 | sed 's|.*/||;s|/$||')
    if [ -z "$CORNER" ]; then
        echo "No timing corners found!"
        exit 1
    fi
fi

WNS_REPORT="$STA_BASE/$CORNER/wns.max.rpt"
MAX_REPORT="$STA_BASE/$CORNER/max.rpt"

if [ ! -f "$WNS_REPORT" ]; then
    echo "WNS report not found: $WNS_REPORT"
    exit 1
fi

echo "Timing Analysis - Run: $(basename $ACTUAL_RUN), Corner: $CORNER"
echo "================================================================"
echo ""

# Extract WNS value - format is "corner_name: -value"
WNS_VAL=$(grep -oE "(\-?[0-9]+\.[0-9]+)$" "$WNS_REPORT" | head -1)
echo "Worst Negative Slack (WNS): $WNS_VAL ns"

# Check if violation
if [ -n "$WNS_VAL" ] && (( $(echo "$WNS_VAL < 0" | bc -l) )); then
    echo "⚠️  TIMING VIOLATION DETECTED"
else
    echo "✓ Timing PASSED"
fi

# Extract TNS value
if [ -f "$STA_BASE/$CORNER/tns.max.rpt" ]; then
    TNS_VAL=$(grep -oE "(\-?[0-9]+\.[0-9]+)$" "$STA_BASE/$CORNER/tns.max.rpt" | head -1)
    echo "Total Negative Slack (TNS): $TNS_VAL ns"
fi

# Calculate suggested clock period
if [ -n "$WNS_VAL" ]; then
    # Get current clock period from config (assume 20ns default if can't read)
    CURRENT_PERIOD=$(grep -o '"CLOCK_PERIOD"[^,}]*' config.json 2>/dev/null | grep -oE '[0-9]+\.?[0-9]*' | head -1)
    CURRENT_PERIOD=${CURRENT_PERIOD:-20}
    
    # If WNS is negative (violation), calculate minimum required period
    if (( $(echo "$WNS_VAL < 0" | bc -l) )); then
        # Minimum period = current period - WNS (adding the slack requirement)
        MIN_PERIOD=$(echo "$CURRENT_PERIOD - ($WNS_VAL)" | bc -l)
        MIN_PERIOD_INT=$(echo "$MIN_PERIOD" | awk '{printf "%.1f\n", $1}')
        FREQ_MHZ=$(echo "1000 / $MIN_PERIOD_INT" | bc -l)
        FREQ_INT=$(echo "$FREQ_MHZ" | awk '{printf "%.1f\n", $1}')
        
        echo ""
        echo "=== SUGGESTED CLOCK ADJUSTMENT ==="
        echo "Current Clock Period: ${CURRENT_PERIOD}ns (Freq: $(echo "1000 / $CURRENT_PERIOD" | bc -l | awk '{printf "%.1f\n", $1}') MHz)"
        echo "Violation Margin: ${WNS_VAL}ns"
        echo "Minimum Required Period: ${MIN_PERIOD_INT}ns (Freq: ${FREQ_INT} MHz)"
        echo ""
        echo "To fix timing, increase CLOCK_PERIOD in config.json to at least ${MIN_PERIOD_INT}ns"
        echo "Or implement reset synchronizers/fix reset distribution"
    fi
fi

echo ""
echo "=== VIOLATION SUMMARY ==="
echo ""

# Count violations by type
SETUP_VIOLATIONS=$(grep -c "recovery check" "$MAX_REPORT" 2>/dev/null || echo 0)
echo "Recovery Time Violations (Asynchronous Reset): $SETUP_VIOLATIONS"

echo ""
echo "=== ROOT CAUSE ANALYSIS ==="
echo ""

# Extract endpoints and map to RTL modules
NETLIST_FILE="$ACTUAL_RUN/final/nl/WRAPPER_trade_engine.nl.v"
if [ -f "$NETLIST_FILE" ]; then
    echo "Analyzing which modules have reset recovery violations..."
    echo ""
    
    # Get unique endpoints from the max.rpt
    grep "Endpoint:" "$MAX_REPORT" | sed 's/.*Endpoint: //' | sed 's/ .*//' | sort -u | head -10 | while read endpoint; do
        if [ ! -z "$endpoint" ]; then
            # Try to find this cell instance in the netlist
            MODULE_INFO=$(grep -m1 "$endpoint " "$NETLIST_FILE" | head -1)
            if [ ! -z "$MODULE_INFO" ]; then
                # Extract the module type (usually in the form: identifier module_type(...))
                MODULE_TYPE=$(echo "$MODULE_INFO" | sed 's/.*\(sky130[^ ]*\).*/\1/')
                echo "  • Endpoint: $endpoint"
                echo "    Cell Type: $MODULE_TYPE"
                echo "    Violation: Asynchronous Reset ($endpoint/RESET_B)"
                echo ""
            fi
        fi
    done
    
    # Find which RTL modules instantiate these flip-flops
    echo "RTL Modules using async reset (potential problematic areas):"
    grep -rn "always_ff.*negedge rst_n" rtl/ | while read match; do
        FILE=$(echo "$match" | cut -d: -f1)
        LINE=$(echo "$match" | cut -d: -f2)
        MODULE=$(basename "$FILE" .sv)
        echo "  • $MODULE (line $LINE): async reset flip-flop"
    done
fi

echo ""
echo "=== CRITICAL PATH (First 3 Paths) ==="
echo ""

if [ ! -f "$MAX_REPORT" ]; then
    echo "Detailed path report not found: $MAX_REPORT"
    exit 0
fi

# Show first few paths only for readability
FIRST_PATH=0
grep -A 40 "Startpoint:" "$MAX_REPORT" | head -150 | while read line; do
    # Track path count
    if echo "$line" | grep -q "^Startpoint:"; then
        FIRST_PATH=$((FIRST_PATH + 1))
        if [ $FIRST_PATH -gt 3 ]; then
            echo ""
            echo "... (showing first 3 of many violations)"
            break
        fi
        echo ""
        echo "$line"
    elif echo "$line" | grep -q "slack (VIOLATED)"; then
        echo "$line"
    elif [ $FIRST_PATH -le 3 ]; then
        if echo "$line" | grep -qE "Startpoint|Endpoint|Path Type|Fanout|slack|VIOLATED|^ *[0-9]+ "; then
            echo "$line"
        fi
    fi
done

echo ""
echo "For full details with all paths, see: $MAX_REPORT"
