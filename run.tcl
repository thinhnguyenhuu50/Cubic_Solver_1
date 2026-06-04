#### Template Script for RTL->Gate-Level Flow (generated from GENUS 19.10-p001_1) 

if {[file exists /proc/cpuinfo]} {
  sh grep "model name" /proc/cpuinfo
  sh grep "cpu MHz"    /proc/cpuinfo
}

puts "Hostname : [info hostname]"

##############################################################################
## Preset global variables and attributes
##############################################################################


set DESIGN cubic_solver
set GEN_EFF low
set MAP_OPT_EFF low
set DATE [clock format [clock seconds] -format "%b%d-%T"] 
set _OUTPUTS_PATH outputs_${DATE}
set _REPORTS_PATH reports_${DATE}
set _LOG_PATH logs_${DATE}

puts "\n======================================================"
puts "\[DEBUG\] Design       : $DESIGN"
puts "\[DEBUG\] GEN_EFF      : $GEN_EFF"
puts "\[DEBUG\] MAP_OPT_EFF  : $MAP_OPT_EFF"
puts "\[DEBUG\] Date stamp   : $DATE"
puts "\[DEBUG\] Outputs dir  : ${_OUTPUTS_PATH}"
puts "\[DEBUG\] Reports dir  : ${_REPORTS_PATH}"
puts "\[DEBUG\] Logs dir     : ${_LOG_PATH}"
puts "======================================================\n"
##set ET_WORKDIR <ET work directory>
set_db / .init_lib_search_path {. ../LIB} 
##set_db / .script_search_path {. <path>} 
set_db / .init_hdl_search_path {. ../RTL} 
##Uncomment and specify machine names to enable super-threading.
##set_db / .super_thread_servers {<machine names>} 
##For design size of 1.5M - 5M gates, use 8 to 16 CPUs. For designs > 5M gates, use 16 to 32 CPUs
##set_db / .max_cpus_per_server 8
 
##Default undriven/unconnected setting is 'none'.  
##set_db / .hdl_unconnected_value 0 | 1 | x | none

set_db / .information_level 7 

###############################################################
## Library setup
###############################################################


puts "\[DEBUG\] ---- Loading technology libraries ----"
read_libs { ../LIB/fast.lib }
puts "\[DEBUG\] ---- Technology libraries loaded OK ----"
puts "\[DEBUG\] ---- Loading LEF physical data ----"
read_physical -lef { ../LEF/gsclib045_tech.lef ../LEF/gsclib045_macro.lef }
puts "\[DEBUG\] ---- LEF physical data loaded OK ----"
## Provide either cap_table_file or the qrc_tech_file
##set_db / .cap_table_file <file> 
##read_qrc <qrcTechFile name>

##set_db / .lp_insert_clock_gating true 

####################################################################
## Load Design
####################################################################


puts "\[DEBUG\] ---- Reading HDL source files ----"
read_hdl -v2001 " cubic_solver.v "
puts "\[DEBUG\] ---- HDL read complete ----"

puts "\[DEBUG\] ---- Elaborating design: $DESIGN ----"
elaborate $DESIGN
puts "\[DEBUG\] ---- Elaboration complete ----"
puts "Runtime & Memory after 'read_hdl'"
time_info Elaboration

puts "\[DEBUG\] ---- Running check_design -unresolved ----"
check_design -unresolved
puts "\[DEBUG\] ---- check_design complete ----"

####################################################################
## Constraints Setup
####################################################################

puts "\[DEBUG\] ---- Reading SDC constraints ----"
read_sdc ../constraints/cubic_solver.sdc
puts "\[DEBUG\] ---- SDC constraints loaded OK ----"
puts "The number of exceptions is [llength [vfind "design:$DESIGN" -exception *]]"


if {![file exists ${_OUTPUTS_PATH}]} {
  file mkdir ${_OUTPUTS_PATH}
  puts "Creating directory ${_OUTPUTS_PATH}"
}

if {![file exists ${_REPORTS_PATH}]} {
  file mkdir ${_REPORTS_PATH}
  puts "Creating directory ${_REPORTS_PATH}"
}


#### To turn off sequential merging on the design 
#### uncomment & use the following attributes.
##set_db / .optimize_merge_flops false 
##set_db / .optimize_merge_latches false 
#### For a particular instance use attribute 'optimize_merge_seqs' to turn off sequential merging. 



####################################################################################################
## Synthesizing to generic 
####################################################################################################

puts "\n======================================================"
puts "\[DEBUG\] ---- PHASE 1: syn_generic (effort=$GEN_EFF) ----"
puts "======================================================\n"
set_db / .syn_generic_effort $GEN_EFF
syn_generic
puts "\[DEBUG\] ---- syn_generic complete ----"
puts "Runtime & Memory after 'syn_generic'"
time_info GENERIC
report_dp > $_REPORTS_PATH/generic/${DESIGN}_datapath.rpt
write_snapshot -outdir $_REPORTS_PATH -tag generic
report_summary -directory $_REPORTS_PATH





####################################################################################################
## Synthesizing to gates
####################################################################################################


puts "\n======================================================"
puts "\[DEBUG\] ---- PHASE 2: syn_map (effort=$MAP_OPT_EFF) ----"
puts "======================================================\n"
set_db / .syn_map_effort $MAP_OPT_EFF
syn_map
puts "\[DEBUG\] ---- syn_map complete ----"
puts "Runtime & Memory after 'syn_map'"
time_info MAPPED
write_snapshot -outdir $_REPORTS_PATH -tag map
report_summary -directory $_REPORTS_PATH
report_dp > $_REPORTS_PATH/map/${DESIGN}_datapath.rpt



puts "\[DEBUG\] ---- Writing LEC dofile (rtl2intermediate) ----"
write_do_lec -revised_design fv_map -logfile ${_LOG_PATH}/rtl2intermediate.lec.log > ${_OUTPUTS_PATH}/rtl2intermediate.lec.do

## ungroup -threshold <value>

#######################################################################################################
## Optimize Netlist
#######################################################################################################

## Uncomment to remove assigns & insert tiehilo cells during Incremental synthesis
##set_db / .remove_assigns true 
##set_remove_assign_options -buffer_or_inverter <libcell> -design <design|subdesign> 
##set_db / .use_tiehilo_for_const <none|duplicate|unique> 
puts "\n======================================================"
puts "\[DEBUG\] ---- PHASE 3: syn_opt (effort=$MAP_OPT_EFF) ----"
puts "======================================================\n"
set_db / .syn_opt_effort $MAP_OPT_EFF
syn_opt
puts "\[DEBUG\] ---- syn_opt complete ----"
write_snapshot -outdir $_REPORTS_PATH -tag syn_opt
report_summary -directory $_REPORTS_PATH

puts "Runtime & Memory after 'syn_opt'"
time_info OPT




puts "\[DEBUG\] ---- Writing final snapshot & reports ----"
write_snapshot -outdir $_REPORTS_PATH -tag final
report_summary -directory $_REPORTS_PATH
write_hdl  > ${_OUTPUTS_PATH}/${DESIGN}_m.v
## write_script > ${_OUTPUTS_PATH}/${DESIGN}_m.script
puts "\[DEBUG\] ---- Writing final SDC ----"
write_sdc > ${_OUTPUTS_PATH}/${DESIGN}_m.sdc


#################################
### write_do_lec
#################################


puts "\[DEBUG\] ---- Writing LEC dofile (intermediate2final) ----"
write_do_lec -golden_design fv_map -revised_design ${_OUTPUTS_PATH}/${DESIGN}_m.v -logfile  ${_LOG_PATH}/intermediate2final.lec.log > ${_OUTPUTS_PATH}/intermediate2final.lec.do
##Uncomment if the RTL is to be compared with the final netlist..
##write_do_lec -revised_design ${_OUTPUTS_PATH}/${DESIGN}_m.v -logfile ${_LOG_PATH}/rtl2final.lec.log > ${_OUTPUTS_PATH}/rtl2final.lec.do

puts "Final Runtime & Memory."
time_info FINAL
puts "============================"
puts "Synthesis Finished ........."
puts "============================"

##file copy [get_db / .stdout_log] ${_LOG_PATH}/.

quit
