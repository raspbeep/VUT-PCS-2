// exact_match.sv: Model of exact match filtering
// Copyright (C) 2019 FIT BUT
// Author(s): Lukas Kekely <ikekely@fit.vutbr.cz>
//
// SPDX-License-Identifier: BSD-3-Clause



package match_package;

  class ExactMatch #(KEY, DATA);

    protected bit [KEY-1 : 0] keys[$];
    protected bit [DATA-1 : 0] data[$];

    function new();
      keys = {};
      data = {};
    endfunction

    function int size();
      return keys.size();
    endfunction

    function bit match(bit [KEY-1 : 0] k, ref bit [DATA-1 : 0] d);
      return match_precise(k, d) != keys.size();
    endfunction

    function int match_precise(bit [KEY-1 : 0] k, ref bit [DATA-1 : 0] d);
      for(int i=0; i<keys.size(); i++)
        if(keys[i] == k) begin
          d = data[i];
          return i;
        end
      d = 0;
      return keys.size();
    endfunction

    function bit add(bit [KEY-1 : 0] k, bit [DATA-1 : 0] d);
      int i;
      bit [DATA-1 : 0] old_data;
      i = match_precise(k, old_data);
      if(i == keys.size()) begin // new item
        keys.push_back(k);
        data.push_back(d);
        return 1;
      end else begin // update
        data[i] = d;
        return 0;
      end
    endfunction

    function bit remove(bit [KEY-1 : 0] k);
      bit [DATA-1 : 0] d;
      int i;
      i = match_precise(k, d);
      if(i < keys.size()) begin
        keys.delete(i);
        data.delete(i);
        return 1;
      end
      return 0;
    endfunction

    function void random_fill(int N);
      bit [KEY-1 : 0] k;
      bit [DATA-1 : 0] d;
      d = 0;
      repeat(N) begin
        d = d + 1;
        do
          for (int i = 0; i < KEY; i++)
            k[i] = $urandom_range(2);
          //RANDOM_RULE : assert(std::randomize(k));
        while(add(k,d) == 0);
      end
    endfunction

    function bit [KEY-1 : 0] get_key(int i);
      return keys[i];
    endfunction

    function bit [DATA-1 : 0] get_data(int i);
      return data[i];
    endfunction

    function bit [KEY-1 : 0] get_random_key();
      if(keys.size() == 0)
        return 0;
      return keys[$urandom_range(keys.size()-1,0)];
    endfunction

    function void clear();
      keys = {};
      data = {};
    endfunction

  endclass

endpackage