# filter.tcl: Verification execution script for ModelSim
# Copyright (C) 2019 FIT BUT
# Author(s): Lukas Kekely <ikekely@fit.vutbr.cz>
#
# SPDX-License-Identifier: BSD-3-Clause



# Compile VHDL sources
eval vlib work
vcom -2008 -explicit -work work ../comp/functions.vhd
vcom -2008 -explicit -work work ../comp/block_memory.vhd
vcom -2008 -explicit -work work ../comp/jenkins_mix.vhd
vcom -2008 -explicit -work work ../comp/jenkins_final.vhd
vcom -2008 -explicit -work work ../comp/jenkins_hash.vhd
vcom -2008 -explicit -work work ../filter_ent.vhd
vcom -2008 -explicit -work work ../filter.vhd

# Compile verification sources
vlog -sv -work work +incdir+comp comp/signal_package.sv
vlog -sv -work work comp/exact_match.sv
vlog -sv -work work test_package.sv
vlog -sv -work work test.sv
vlog -sv -work work testbench.sv

# Run verification
quit -sim
vsim -t 1ps -lib work testbench
set StdArithNoWarnings 1

view wave
delete wave *

add wave -noupdate -hex /testbench/VHDL_DUT/*
config wave -signalnamewidth 1

restart -f
run -all