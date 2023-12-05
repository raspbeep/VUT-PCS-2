// signal_interface.sv: Specification of general data signal interface
// Copyright (C) 2019 FIT BUT
// Author(s): Lukas Kekely <ikekely@fit.vutbr.cz>
//
// SPDX-License-Identifier: BSD-3-Clause



interface InputSignal #(WIDTH = 32) (input logic CLK, RESET);

  logic [WIDTH-1:0] VALUE;
  logic VALID;

  clocking cb @(posedge CLK);
    default input #1step output #500ps;
    input RESET;
    output VALUE, VALID;
  endclocking;

  modport dut (input VALUE, VALID);
  modport test (clocking cb);

endinterface



interface OutputSignal #(WIDTH = 32) (input logic CLK, RESET);

  logic [WIDTH-1:0] VALUE;
  logic VALID;

  clocking cb @(posedge CLK);
    default input #1step output #500ps;
    input VALUE, VALID, RESET;
  endclocking;

  modport dut (output VALUE, VALID);
  modport test (clocking cb);

endinterface
