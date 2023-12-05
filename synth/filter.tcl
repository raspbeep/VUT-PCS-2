# filter.tcl: Verification execution script for ModelSim
# Copyright (C) 2019 FIT BUT
# Author(s): Lukas Kekely <ikekely@fit.vutbr.cz>
#
# SPDX-License-Identifier: BSD-3-Clause



# Create Vivado Project
#create_project -part xc7vx330tffg1157-1 -force filter_vivado
create_project -part xc7k160tffv676-1 -force filter_vivado
set_param project.enableVHDL2008 1
set_property target_language VHDL [current_project]
set_property enable_vhdl_2008 1 [current_project]

# Add source files
add_files -norecurse \
  ../comp/functions.vhd \
  ../comp/block_memory.vhd \
  ../comp/jenkins_mix.vhd \
  ../comp/jenkins_final.vhd \
  ../comp/jenkins_hash.vhd \
  ../filter_ent.vhd \
  ../filter.vhd
set_property file_type {VHDL 2008} [get_files]
set_property top filter [current_fileset]

# Add contraints file
add_files -fileset constrs_1 filter.xdc

# Run synthesis
set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} -value "-mode out_of_context" -objects [get_runs synth_1]
launch_runs synth_1
wait_on_run synth_1
open_run synth_1

# Generate reports
report_timing_summary -delay_type min_max -report_unconstrained -max_paths 64 -input_pins -name timing_1 -file filter_synthesis_timing.log
report_utilization -file filter_synthesis_utilization.log
