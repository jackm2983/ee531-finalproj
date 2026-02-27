
# Generic STA script - uses environment variables for design name
# Usage: DESIGN_NAME=my_design RUN_DIR=runs/RUN_2025-09-20_06-04-08 openroad -s sta.tcl
# Or set PDKPATH and DESIGN_NAME before sourcing

set design_name [expr {[info exists ::env(DESIGN_NAME)] ? $::env(DESIGN_NAME) : "WRAPPER_trade_engine"}]
set run_dir [expr {[info exists ::env(RUN_DIR)] ? $::env(RUN_DIR) : "runs/recent"}]
set pdk_path [expr {[info exists ::env(PDKPATH)] ? $::env(PDKPATH) : "/foss/pdks/sky130A"}]

set lib_file "$pdk_path/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_100C_1v80.lib"
set netlist "$run_dir/final/nl/${design_name}.nl.v"
set sdc "$run_dir/final/sdc/${design_name}.sdc"

read_liberty $lib_file
read_verilog $netlist
link_design $design_name
read_sdc $sdc
report_worst_slack
report_tns
exit