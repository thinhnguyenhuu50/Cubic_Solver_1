###############################################################
## SDC Constraints for cubic_solver
## Target: Cadence Genus
## Clock: 25 MHz (40 ns period) — adjust as needed
###############################################################
current_design cubic_solver

###############################################################
## Clock Definition
###############################################################

set CLK_PERIOD 40.0
set CLK_NAME   clk

create_clock -name $CLK_NAME -period $CLK_PERIOD [get_ports clk]

## Clock uncertainty (jitter + skew)
set_clock_uncertainty 0.3 [get_clocks $CLK_NAME]

## Clock transition
set_clock_transition 0.1 [get_clocks $CLK_NAME]

###############################################################
## Reset — Asynchronous, False Path
###############################################################

## rst_n is an asynchronous active-low reset.
## Exclude it from timing analysis (it is not synchronous to clk).
set_false_path -from [get_ports rst_n]

###############################################################
## Input Delays
###############################################################

## All inputs arrive within 30% of the clock period relative to
## the rising edge of clk. Adjust if the upstream logic requires
## a tighter or more relaxed budget.

set INPUT_DELAY [expr {$CLK_PERIOD * 0.3}]

set_input_delay  $INPUT_DELAY -clock $CLK_NAME [get_ports in_valid]
set_input_delay  $INPUT_DELAY -clock $CLK_NAME [get_ports out_ready]
set_input_delay  $INPUT_DELAY -clock $CLK_NAME [get_ports {a[*]}]
set_input_delay  $INPUT_DELAY -clock $CLK_NAME [get_ports {b[*]}]
set_input_delay  $INPUT_DELAY -clock $CLK_NAME [get_ports {c[*]}]
set_input_delay  $INPUT_DELAY -clock $CLK_NAME [get_ports {d[*]}]

###############################################################
## Output Delays
###############################################################

## All outputs must be stable 30% of the clock period before the
## next rising edge.

set OUTPUT_DELAY [expr {$CLK_PERIOD * 0.3}]

set_output_delay $OUTPUT_DELAY -clock $CLK_NAME [get_ports in_ready]
set_output_delay $OUTPUT_DELAY -clock $CLK_NAME [get_ports out_valid]
set_output_delay $OUTPUT_DELAY -clock $CLK_NAME [get_ports {x0[*]}]
set_output_delay $OUTPUT_DELAY -clock $CLK_NAME [get_ports {x1[*]}]
set_output_delay $OUTPUT_DELAY -clock $CLK_NAME [get_ports {x2[*]}]

###############################################################
## Driving Cell and Load (library-dependent)
###############################################################

## Uncomment and adjust to match your standard cell library.
## Example for a generic GSCL045 library:
# set_driving_cell -lib_cell INVX1 -pin Y [all_inputs]
# set_load 0.05 [all_outputs]

###############################################################
## Design Rule Constraints
###############################################################

## Maximum fanout — prevent high-fanout nets from degrading timing.
set_max_fanout 20 [current_design]

## Maximum transition time on all nets.
set_max_transition 0.5 [current_design]

###############################################################
## Area Constraint (optional)
###############################################################

## Set to 0 for minimum-area optimization.
## Uncomment to enable:
# set_max_area 0

###############################################################
## Operating Conditions (library-dependent)
###############################################################

## Uncomment if your library provides named operating conditions:
# set_operating_conditions -max slow -max_library slow
