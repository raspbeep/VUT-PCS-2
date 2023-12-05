// test.sv: Testing program specification
// Copyright (C) 2019 FIT BUT
// Author(s): Lukas Kekely <ikekely@fit.vutbr.cz>
//
// SPDX-License-Identifier: BSD-3-Clause

import test_package::*;
import signal_package::*;
import match_package::*;

`include "scoreboard.sv"



module TEST (
  input logic CLK,
  output logic RESET,
  InputSignal.test RX,
  OutputSignal.test TX,
  InputSignal.test CFG
);



  SignalDriver #(KEY_WIDTH) driver;
  SignalMonitor #(RULE_WIDTH) monitor;
  SignalDriver #(CONFIG_WIDTH) configuration;
  JenkinsHashExactMatch model;
  Scoreboard score;

  task create();
    driver = new(RX);
    monitor = new(TX);
    configuration = new(CFG);
    configuration.DelayEnableRatio = 0;
    model =  new();
    score = new(driver, monitor, model);
  endtask

  task start();
    driver.start();
    monitor.start();
    configuration.start();
  endtask

  task stop();
    wait(!score.running());
    driver.stop();
    monitor.stop();
    configuration.stop();
  endtask

  task reset();
    RESET = 1;
    #RESET_TIME RESET = 0;
  endtask

  task configureFilter();
    int rules;
    $write("\n\n============================================================\n");
    $write("= Filter Configuration\n");
    $write("============================================================\n");
    model.random_fill(TABLES*TABLE_SIZE, configuration, rules);
    $write("%0d random rules generated and configured into DUT\n", rules);
  endtask

  task test1();
    $write("\n\n============================================================\n");
    $write("= TEST1: Matching rules only\n");
    $write("============================================================\n");
    for(int i=0; i<model.size(); i++)
      score.put(model.get_key(i));
    #RESET_TIME;
    for(int i=model.size()-1; i>=0; i--)
      score.put(model.get_key(i));
    wait(!score.running());
    $write("Test finished successfully!\n");
  endtask

  task test2();
    bit [KEY_WIDTH-1 : 0] random_key;
    $write("\n\n============================================================\n");
    $write("= TEST2: Random rules only\n");
    $write("============================================================\n");
    repeat(TRANSACTIONS) begin
      for (int i = 0; i < KEY_WIDTH; i++)
        random_key[i] = $urandom_range(2);
      //TEST2_RANDOMIZE : assert(std::randomize(random_key));
      score.put(random_key);
    end
    wait(!score.running());
    $write("Test finished successfully!\n");
  endtask

  task test3();
    bit [KEY_WIDTH-1 : 0] key;
    $write("\n\n============================================================\n");
    $write("= TEST3: Mixed rules\n");
    $write("============================================================\n");
    repeat(TRANSACTIONS) begin
      if($urandom_range(1024) < 1024*TEST3_FORCE_RATIO)
        key = model.get_random_key();
      else 
        for (int i = 0; i < KEY_WIDTH; i++)
          key[i] = $urandom_range(2);
        //TEST3_RANDOMIZE : assert(std::randomize(key));
      score.put(key);
    end
    wait(!score.running());
    $write("Test finished successfully!\n");
  endtask

  initial begin
    create();
    start();
    reset();
    configureFilter();
    test1();
    test2();
    test3();
    stop();
    score.display();
    $write("\n\nVerification finished successfully!\n");
    $stop();
  end

endmodule

