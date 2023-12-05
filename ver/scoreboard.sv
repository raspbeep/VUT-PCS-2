// signal_driver.sv: Driver of signal interface
// Copyright (C) 2019 FIT BUT
// Author(s): Lukas Kekely <ikekely@fit.vutbr.cz>
//
// SPDX-License-Identifier: BSD-3-Clause



// Exact match filtering model extended for hashing tables using Jenkins hash
class JenkinsHashExactMatch extends ExactMatch #(KEY_WIDTH, DATA_WIDTH);

  `define rot(x,k) (((x)<<(k)) | ((x)>>(32-(k))))

  `define mix(a,b,c) \
    a = a-c;  a = a^`rot(c, 4);  c = c+b; \
    b = b-a;  b = b^`rot(a, 6);  a = a+c; \
    c = c-b;  c = c^`rot(b, 8);  b = b+a; \
    a = a-c;  a = a^`rot(c,16);  c = c+b; \
    b = b-a;  b = b^`rot(a,19);  a = a+c; \
    c = c-b;  c = c^`rot(b, 4);  b = b+a;

  `define final(a,b,c) \
    c = c^b; c = c-`rot(b,14); \
    a = a^c; a = a-`rot(c,11); \
    b = b^a; b = b-`rot(a,25); \
    c = c^b; c = c-`rot(b,16); \
    a = a^c; a = a-`rot(c,4);  \
    b = b^a; b = b-`rot(a,14); \
    c = c^b; c = c-`rot(b,24);

  function int unsigned jenkins_hash_base(int unsigned k[], int unsigned length, int unsigned initval);
    int unsigned a,b,c,kk;
    /* Set up the internal state */
    a = 32'hdeadbeef + (length<<2) + initval; b = a; c = a;
    /*------------------------------------------------- handle most of the key */
    kk = 0;
    while (length > 3) begin
      a += k[kk+0];
      b += k[kk+1];
      c += k[kk+2];
      `mix(a,b,c)
      length = length - 3;
      kk = kk + 3;
    end
    /*------------------------------------------- handle the last 3 uint32_t's */
    /* all the case statements fall through */
    if(length >= 3) c = c + k[kk+2];
    if(length >= 2) b = b + k[kk+1];
    if(length >= 1) a = a + k[kk+0];
    /* case 0: nothing left to add */
    `final(a,b,c)
    /*------------------------------------------------------ report the result */
    return c;
  endfunction

  function int unsigned jenkins_hash(bit [RULE_WIDTH-1 : 0] r, int unsigned initval);
    int unsigned k[KEY_WORDS];
    for(int i = 0; i<KEY_WORDS-1; i++)
      k[i] = r[32*i+DATA_WIDTH+1 +: 32];
    k[KEY_WORDS-1] = r[RULE_WIDTH-1 : (KEY_WORDS-1)*32+DATA_WIDTH+1];
    return jenkins_hash_base(k, KEY_WORDS, initval) % TABLE_SIZE;
  endfunction

  task random_fill(int N, SignalDriver #(CONFIG_WIDTH) cd, ref int rules);
    bit [RULE_WIDTH-1 : 0] memory[TABLES][TABLE_SIZE], rule;
    bit [CONFIG_WIDTH-1 : 0] hw_record;
    int unsigned t, s, hash;
    super.random_fill(N); // random matching rules generation
    for(t=0; t<TABLES; t++) // initialize tables to empty rules
      for(s=0; s<TABLE_SIZE; s++)
        memory[t][s] = 1;
    for(int i=0; i<keys.size(); i++) begin // spread of rules into hash tables
      rule[KEY_WIDTH+DATA_WIDTH : DATA_WIDTH+1] = get_key(i);
      rule[DATA_WIDTH : 1] =  get_data(i);
      rule[0] = 0;
      for(t = 0; t<TABLES; t++) begin
        hash = jenkins_hash(rule, t+1);
        if(memory[t][hash][0]) begin// empty record
          memory[t][hash] = rule;
          break;
        end
      end
      if(t == TABLES) begin
        assert(remove(rule[RULE_WIDTH-1 : RULE_WIDTH-KEY_WIDTH]));
        i--;
      end else
        rules++;
    end
    for(t=0; t<TABLES; t++) // fill DUT tables with rules through CONFIG interface
      for(s=0; s<TABLE_SIZE; s++) begin
        hw_record[CONFIG_WIDTH-1 : CONFIG_WIDTH-$clog2(TABLES)] = t;
        hw_record[CONFIG_WIDTH-$clog2(TABLES)-1 : CONFIG_WIDTH-$clog2(TABLES)-$clog2(TABLE_SIZE)] = s;
        hw_record[RULE_WIDTH-1 : 0] = memory[t][s];
        cd.put(hw_record);
      end
  endtask

endclass



// Main scoreboard implementation
class Scoreboard;

  protected bit enabled;
  protected mailbox #(bit [KEY_WIDTH-1 : 0]) mbox;
  protected SignalDriver #(KEY_WIDTH) driver;
  protected SignalMonitor #(RULE_WIDTH) monitor;
  protected ExactMatch #(KEY_WIDTH,DATA_WIDTH) model;
  protected int transactions, matching, nonmatching;

  function new(SignalDriver #(KEY_WIDTH) d, SignalMonitor #(RULE_WIDTH) m, ExactMatch #(KEY_WIDTH,DATA_WIDTH) mod);
    enabled = 0;
    mbox = new();
    driver = d;
    monitor = m;
    model = mod;
    transactions = 0;
    matching = 0;
    nonmatching = 0;
  endfunction

  function void start();
    enabled = 1;
    fork
      run();
    join_none;
  endfunction

  function bit running();
    return enabled;
  endfunction

  task run();
    bit [KEY_WIDTH-1 : 0] dut_key, model_key;
    bit [RULE_WIDTH-1 : 0] dut_raw;
    bit [DATA_WIDTH-1 : 0] dut_data, model_data;
    bit dut_found, model_found;
    while(mbox.try_get(model_key) != 0) begin
      monitor.get(dut_raw);
      dut_key = dut_raw[KEY_WIDTH+DATA_WIDTH : DATA_WIDTH+1];
      dut_data = dut_raw[DATA_WIDTH : 1];
      dut_found = dut_raw[0];
      model_found = model.match(model_key, model_data);
      if(model_key != dut_key || model_found != dut_found || (model_found == 1 && model_data != dut_data)) begin
        $write("Data mismatch detected on transaction #%0d! Details:\n", transactions+1);
        $write("   MODEL: matching key 0x%0x results in ", model_key);
        if(model_found)
          $write("FOUND rule with data 0x%0x\n", model_data);
        else
          $write("NOT FOUND\n");
        $write("     DUT: matching key 0x%0x results in ", dut_key);
        if(dut_found)
          $write("FOUND rule with data 0x%0x\n", dut_data);
        else
          $write("NOT FOUND\n");
        $write("  REASON: ");
        if(model_key != dut_key)
          $write("Different keys paired together (possible desynchronization in DUT)!");
        else if(model_found != dut_found)
          $write("Different FOUND flag!\n");
        else if(model_data != dut_data)
          $write("Different value of data (found rule identificator)!\n");
        else
          $write("Unknown error!\n");
        display();
        $write("\n\nERROR: Verification data mismatch! Stopping ...\n");
        $stop();
      end
      transactions++;
      if(model_found)
        matching++;
      else
        nonmatching++;
    end
    enabled = 0;
  endtask

  task put(bit [KEY_WIDTH-1 : 0] k);
    driver.put(k);
    mbox.put(k);
    if(!enabled)
      start();
  endtask

  task display();
    $write("\n\n============================================================\n");
    $write("= Verification scoreboard\n");
    $write("============================================================\n");
    $write("    Waiting input keys: %08d\n", mbox.num());
    $write("   Waiting output data: %08d\n", monitor.num());
    $write("Processed transactions: %08d (%0d keys matched & %0d did not)\n", transactions, matching, nonmatching);
  endtask

endclass
