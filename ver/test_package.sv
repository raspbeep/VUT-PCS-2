// test_package.sv: Parameters of the verification run
// Copyright (C) 2019 FIT BUT
// Author(s): Lukas Kekely <ikekely@fit.vutbr.cz>
//
// SPDX-License-Identifier: BSD-3-Clause



package test_package;

    parameter KEY_WIDTH = 128;
    parameter DATA_WIDTH = 32;
    parameter TABLES = 4;
    parameter TABLE_SIZE = 2048;

    parameter TRANSACTIONS = 20000;
    parameter TEST3_FORCE_RATIO = 0.2;
    parameter CLK_PERIOD = 5ns;
    parameter RESET_TIME = 2 * CLK_PERIOD;

    parameter KEY_WORDS = (KEY_WIDTH-1) / 32 + 1;
    parameter RULE_WIDTH = KEY_WIDTH + DATA_WIDTH + 1;
    parameter CONFIG_WIDTH = RULE_WIDTH + $clog2(TABLES) + $clog2(TABLE_SIZE);

endpackage
