// signal_package.sv: Package with signal related verification components
// Copyright (C) 2019 FIT BUT
// Author(s): Lukas Kekely <ikekely@fit.vutbr.cz>
//
// SPDX-License-Identifier: BSD-3-Clause

`include "signal_interface.sv"



package signal_package;
  `include "signal_driver.sv"
  `include "signal_monitor.sv"
endpackage
