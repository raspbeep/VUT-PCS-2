// signal_driver.sv: Driver of signal interface
// Copyright (C) 2019 FIT BUT
// Author(s): Lukas Kekely <ikekely@fit.vutbr.cz>
//
// SPDX-License-Identifier: BSD-3-Clause



class SignalDriver #(WIDTH);

  protected bit enabled;
  protected virtual InputSignal #(WIDTH).test vif;
  protected mailbox #(bit [WIDTH-1 : 0]) mbox;

  protected rand integer Delay;
  protected rand bit DelayEnable;
  int DelayLow = 1;
  int DelayHigh = 5;
  int DelayEnableRatio = 2;
  int DelayDisableRatio = 8;

  constraint Delays {
    DelayEnable dist { 1'b1 := DelayEnableRatio, 1'b0 := DelayDisableRatio };
    Delay inside { [DelayLow : DelayHigh] };
  }

  function new(virtual InputSignal #(WIDTH).test v);
    enabled = 0;
    vif = v;
    mbox = new(1);
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
    bit [WIDTH-1 : 0] data;
    vif.cb.VALUE <= 0;
    vif.cb.VALID <= 0;
    @(vif.cb); // initial sync
    while(enabled) begin
      if(mbox.try_get(data) == 0) begin
        vif.cb.VALUE <= 'X;
        vif.cb.VALID <= 0;
      end else begin
        //DELAY_RANDOMIZE : assert(randomize());
        if(DelayEnable) begin
          vif.cb.VALUE <= 'X;
          vif.cb.VALID <= 0;
          repeat(Delay)
            @(vif.cb);
        end
        vif.cb.VALUE <= data;
        vif.cb.VALID <= 1;
      end
      @(vif.cb);
    end
  endtask

  task put(bit [WIDTH-1 : 0] value);
    mbox.put(value);
  endtask

endclass
