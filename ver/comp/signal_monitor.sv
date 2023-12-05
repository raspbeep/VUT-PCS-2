// signal_monitor.sv: Monitor of signal interface
// Copyright (C) 2019 FIT BUT
// Author(s): Lukas Kekely <ikekely@fit.vutbr.cz>
//
// SPDX-License-Identifier: BSD-3-Clause



class SignalMonitor #(WIDTH);

  protected bit enabled;
  protected virtual OutputSignal #(WIDTH).test vif;
  protected mailbox #(bit [WIDTH-1 : 0]) mbox;

  function new(virtual OutputSignal #(WIDTH).test v);
    enabled = 0;
    vif = v;
    mbox = new(0);
  endfunction

  function void start();
    enabled = 1;
    fork
      run();
    join_none;
  endfunction

  function void stop();
    enabled = 0;
  endfunction

  task run();
    @(vif.cb); // initial sync
    while(enabled) begin
      if(vif.cb.VALID === 1'bX && vif.cb.RESET == 0) begin
        $write("ERROR: Signal monitor detected an unitialized value on connected VALID flag! (time %0t ps)\n", $time);
        $write("ERROR: Simulation behaviour may be different compared to actual hardware! Stopping ...\n");
        $stop();
      end
      if(vif.cb.VALID)
        mbox.put(vif.cb.VALUE);
      @(vif.cb);
    end
  endtask

  task get(ref bit [WIDTH-1 : 0] value);
    mbox.get(value);
  endtask

  function num();
    return mbox.num();
  endfunction

endclass
