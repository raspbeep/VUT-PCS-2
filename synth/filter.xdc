# filter.tcl: Verification execution script for ModelSim
# Copyright (C) 2019 FIT BUT
# Author(s): Lukas Kekely <ikekely@fit.vutbr.cz>
#
# SPDX-License-Identifier: BSD-3-Clause



# Configure clock frequencies
create_clock -period 4 [get_ports CLK]

# Configure delays for synthesis
set_input_delay -clock [get_clocks CLK] 1 [all_inputs]
set_output_delay -clock [get_clocks CLK] 1 [all_outputs]