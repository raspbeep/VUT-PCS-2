-- functions.vhd: Useful functions not present in the vanilla VHDL libraries
-- Copyright (C) 2019 FIT BUT
-- Author(s): Lukas Kekely <ikekely@fit.vutbr.cz>
--
-- SPDX-License-Identifier: BSD-3-Clause



library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;



package functions_package is

  -- Ceil 2-logarithm of a given number N, i.e. returns smallest value X for which 2^X >= N holds.
  function clog2(n : natural) return natural;

  -- Ceil division of a given number N by K, i.e. returns smallest value X for which X*K >= N holds.
  function cdiv(n : natural; k : natural) return natural;

end functions_package;



package body functions_package is

  function clog2(n : natural) return natural is
    variable x, m : natural;
  begin
    x := 0;
    m := 1;
    while m < n loop
      x := x + 1;
      m := m * 2;
    end loop;
    return x;
  end function;

  function cdiv(n : natural; k : natural) return natural is
  begin
    return (n-1) / k + 1;
  end function;

end functions_package;