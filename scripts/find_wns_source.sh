#!/bin/bash
set -euo pipefail

# find timing violations and try to map them back to netlist/rtl
# usage:
#   ./scripts/find_wns_source.sh [run_name] [corner]
#   ./scripts/find_wns_source.sh             (uses runs/recent, nom_ss_100C_1v60)
#   ./scripts/find_wns_source.sh RUN_2026-02-27_07-28-15
#   ./scripts/find_wns_source.sh recent nom_ss_100C_1v60

RUNS_DIR="./runs"
RUN_NAME="${1:-recent}"
CORNER="${2:-nom_ss_100C_1v60}"

if [[ "$RUN_NAME" == "." ]]; then
  RUN_NAME="recent"
fi

TARGET_RUN="$RUNS_DIR/$RUN_NAME"
if [[ ! -e "$TARGET_RUN" ]]; then
  echo "run directory not found: $TARGET_RUN"
  echo "available runs in $RUNS_DIR:"
  ls -1 "$RUNS_DIR" 2>/dev/null | grep -v '^recent$' || true
  exit 1
fi

ACTUAL_RUN="$(readlink -f "$TARGET_RUN")"
STA_BASE="$ACTUAL_RUN/12-openroad-staprepnr"

if [[ ! -d "$STA_BASE" ]]; then
  echo "sta directory not found: $STA_BASE"
  echo "available directories in run:"
  ls -1d "$ACTUAL_RUN"/*openroad* 2>/dev/null || true
  exit 1
fi

if [[ ! -d "$STA_BASE/$CORNER" ]]; then
  echo "corner '$CORNER' not found. available corners:"
  ls -1d "$STA_BASE"/*/ 2>/dev/null | sed 's|.*/||;s|/$||' || true
  echo ""
  echo "using first available corner..."
  CORNER="$(ls -1d "$STA_BASE"/*/ 2>/dev/null | head -1 | sed 's|.*/||;s|/$||' || true)"
  if [[ -z "${CORNER:-}" ]]; then
    echo "no timing corners found!"
    exit 1
  fi
fi

WNS_REPORT="$STA_BASE/$CORNER/wns.max.rpt"
TNS_REPORT="$STA_BASE/$CORNER/tns.max.rpt"
MAX_REPORT="$STA_BASE/$CORNER/max.rpt"

if [[ ! -f "$WNS_REPORT" ]]; then
  echo "wns report not found: $WNS_REPORT"
  exit 1
fi

echo "Timing Analysis - Run: $(basename "$ACTUAL_RUN"), Corner: $CORNER"
echo "================================================================"
echo ""

WNS_VAL="$(grep -oE '(-?[0-9]+(\.[0-9]+)?)$' "$WNS_REPORT" | head -1 || true)"
echo "Worst Negative Slack (WNS): ${WNS_VAL:-unknown} ns"

if [[ -n "${WNS_VAL:-}" ]] && (( $(echo "$WNS_VAL < 0" | bc -l) )); then
  echo "⚠️  TIMING VIOLATION DETECTED"
else
  echo "✓ Timing PASSED"
fi

if [[ -f "$TNS_REPORT" ]]; then
  TNS_VAL="$(grep -oE '(-?[0-9]+(\.[0-9]+)?)$' "$TNS_REPORT" | head -1 || true)"
  echo "Total Negative Slack (TNS): ${TNS_VAL:-unknown} ns"
fi

if [[ -n "${WNS_VAL:-}" ]] && (( $(echo "$WNS_VAL < 0" | bc -l) )); then
  CURRENT_PERIOD="$(grep -o '"CLOCK_PERIOD"[^,}]*' config.json 2>/dev/null | grep -oE '[0-9]+\.?[0-9]*' | head -1 || true)"
  CURRENT_PERIOD="${CURRENT_PERIOD:-20}"

  MIN_PERIOD="$(echo "$CURRENT_PERIOD - ($WNS_VAL)" | bc -l)"
  MIN_PERIOD_1DP="$(echo "$MIN_PERIOD" | awk '{printf "%.1f\n",$1}')"
  CUR_FREQ="$(echo "1000 / $CURRENT_PERIOD" | bc -l | awk '{printf "%.1f\n",$1}')"
  MIN_FREQ="$(echo "1000 / $MIN_PERIOD_1DP" | bc -l | awk '{printf "%.1f\n",$1}')"

  echo ""
  echo "=== SUGGESTED CLOCK ADJUSTMENT ==="
  echo "Current Clock Period: ${CURRENT_PERIOD}ns (Freq: ${CUR_FREQ} MHz)"
  echo "Violation Margin: ${WNS_VAL}ns"
  echo "Minimum Required Period: ${MIN_PERIOD_1DP}ns (Freq: ${MIN_FREQ} MHz)"
  echo ""
  echo "To fix timing, increase CLOCK_PERIOD in config.json to at least ${MIN_PERIOD_1DP}ns"
fi

echo ""
echo "=== VIOLATION SUMMARY ==="
echo ""

if [[ ! -f "$MAX_REPORT" ]]; then
  echo "detailed path report not found: $MAX_REPORT"
  echo ""
  echo "For full details, see: $WNS_REPORT"
  exit 0
fi

VIOLATED_PATHS="$(grep -c "slack (VIOLATED)" "$MAX_REPORT" 2>/dev/null || true)"
echo "Total Violated Paths (all check types in max.rpt): ${VIOLATED_PATHS:-0}"

RECOVERY_VIOLATIONS="$(awk '
  BEGIN{c=0}
  /recovery check/ {inwin=12; next}
  inwin>0 {
    if ($0 ~ /slack \(VIOLATED\)/) {c++; inwin=0}
    inwin--
  }
  END{print c}
' "$MAX_REPORT" 2>/dev/null || echo 0)"
echo "Violated Recovery Checks (async reset recovery): ${RECOVERY_VIOLATIONS:-0}"

echo ""
echo "=== ROOT CAUSE ANALYSIS (best-effort) ==="
echo ""

NETLIST_FILE="$ACTUAL_RUN/final/nl/WRAPPER_trade_engine.nl.v"
if [[ ! -f "$NETLIST_FILE" ]]; then
  echo "netlist not found: $NETLIST_FILE"
else
  if [[ "${VIOLATED_PATHS:-0}" -eq 0 ]]; then
    echo "no violated paths found in max.rpt; any async reset flops shown below are analyzed, not failing."
    echo ""
  fi

  mapfile -t VIOL_EP < <(awk '
    BEGIN{have_viol=0; ep=""}
    /^Startpoint:/ {have_viol=0; ep=""}
    /^Endpoint:/ {ep=$0; sub(/^Endpoint:[[:space:]]*/,"",ep); sub(/[[:space:]].*$/,"",ep)}
    /slack \(VIOLATED\)/ {have_viol=1}
    /^$/ {
      if (have_viol && ep!="") print ep
      have_viol=0; ep=""
    }
    END{ if (have_viol && ep!="") print ep }
  ' "$MAX_REPORT" 2>/dev/null | sort -u)

  if [[ "${#VIOL_EP[@]}" -eq 0 ]]; then
    echo "no violated endpoints extracted (either no violations or report formatting differs)."
  else
    echo "violated endpoints (up to 10):"
    echo ""
    printf '%s\n' "${VIOL_EP[@]}" | head -10 | while read -r endpoint; do
      [[ -z "$endpoint" ]] && continue
      inst_re="$(printf '%s' "$endpoint" | sed 's/[][\.^$*+?(){}|\\/]/\\&/g')"
      MODULE_INFO="$(grep -nE "([[:space:]]|^)$inst_re([[:space:]]|\()" "$NETLIST_FILE" | head -1 || true)"
      if [[ -n "$MODULE_INFO" ]]; then
        CELL_TYPE="$(echo "$MODULE_INFO" | sed -n 's/.*\b\(sky130[^[:space:]]*\)\b.*/\1/p' | head -1)"
        echo "  • Endpoint: $endpoint"
        echo "    Cell Type: ${CELL_TYPE:-unknown}"
        echo "    Netlist Ref: $NETLIST_FILE:$(echo "$MODULE_INFO" | cut -d: -f1)"
        echo ""
      else
        echo "  • Endpoint: $endpoint"
        echo "    Cell Type: unknown (instance not found in netlist with simple grep)"
        echo ""
      fi
    done
  fi

  echo "rtl async reset patterns (quick scan):"
  if [[ -d rtl ]]; then
    matches="$(
      grep -RIn --include='*.v' --include='*.sv' -E \
        'always(_ff)?[[:space:]]*@?[[:space:]]*\([^)]*(negedge|posedge)[[:space:]]+rst(_n)?[^)]*\)' \
        rtl 2>/dev/null || true
    )"
    if [[ -n "$matches" ]]; then
      printf '%s\n' "$matches" | head -50 | while read -r match; do
        file="$(echo "$match" | cut -d: -f1)"
        line="$(echo "$match" | cut -d: -f2)"
        mod="$(basename "$file")"
        echo "  • $mod (line $line): $file:$line"
      done
    else
      echo "  • none found"
    fi
  else
    echo "  • rtl/ directory not found"
  fi
fi

echo ""
echo "=== VIOLATED PATHS (First 3) ==="
echo ""

awk '
  function flush() {
    if (blk != "" && viol) {
      print ""
      print blk
      shown++
    }
    blk=""
    viol=0
  }
  BEGIN{blk=""; viol=0; shown=0}
  /^Startpoint:/ {
    flush()
    if (shown>=3) exit
  }
  {
    blk = (blk=="" ? $0 : blk "\n" $0)
    if ($0 ~ /slack \(VIOLATED\)/) viol=1
  }
  END{flush()}
' "$MAX_REPORT" | head -400

if [[ "${VIOLATED_PATHS:-0}" -gt 3 ]]; then
  echo ""
  echo "... (showing first 3 violated paths)"
fi

echo ""
echo "For full details with all paths, see: $MAX_REPORT"