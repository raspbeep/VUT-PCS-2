// testbench.sv: Verification top-level connection of specific DUT
// Copyright (C) 2019 FIT BUT
// Author(s): Lukas Kekely <ikekely@fit.vutbr.cz>
//
// SPDX-License-Identifier: BSD-3-Clause

import test_package::*;



module testbench;

  logic clk = 0;
  logic reset;
  InputSignal #(KEY_WIDTH) rx (clk, reset);
  OutputSignal #(RULE_WIDTH) tx (clk, reset);
  InputSignal #(CONFIG_WIDTH) cfg (clk, reset);


  always #(CLK_PERIOD/2) clk = ~clk;


  filter #(
    .KEY_WIDTH       (KEY_WIDTH),
    .DATA_WIDTH      (DATA_WIDTH),
    .TABLES          (TABLES),
    .TABLE_SIZE      (TABLE_SIZE),
    .INPUT_REGISTER  (1),
    .OUTPUT_REGISTER (1),
    .CONFIG_REGISTER (1)
  ) VHDL_DUT (
    .CLK                  (clk),
    .RESET                (reset),
    .INPUT_KEY            (rx.VALUE),
    .INPUT_VALID          (rx.VALID),
    .OUTPUT_KEY           (tx.VALUE[KEY_WIDTH+DATA_WIDTH : DATA_WIDTH+1]),
    .OUTPUT_KEY_FOUND     (tx.VALUE[0]),
    .OUTPUT_DATA          (tx.VALUE[DATA_WIDTH : 1]),
    .OUTPUT_VALID         (tx.VALID),
    .CONFIG_KEY           (cfg.VALUE[KEY_WIDTH+DATA_WIDTH : DATA_WIDTH+1]),
    .CONFIG_DATA          (cfg.VALUE[DATA_WIDTH : 1]),
    .CONFIG_EMPTY         (cfg.VALUE[0]),
    .CONFIG_ADDRESS_TABLE (cfg.VALUE[CONFIG_WIDTH-1 : CONFIG_WIDTH-$clog2(TABLES)]),
    .CONFIG_ADDRESS_ITEM  (cfg.VALUE[CONFIG_WIDTH-$clog2(TABLES)-1 : CONFIG_WIDTH-$clog2(TABLES)-$clog2(TABLE_SIZE)]),
    .CONFIG_WRITE         (cfg.VALID)
  );

  TEST TEST_PROGRAM (
    .CLK        (clk),
    .RESET      (reset),
    .RX         (rx),
    .TX         (tx),
    .CFG        (cfg)
  );

endmodule
