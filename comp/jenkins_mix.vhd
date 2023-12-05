-- jenkins_mix.vhd: Part of Jenkins hashing function based on https://burtleburtle.net/bob/c/lookup3.c
-- Copyright (C) 2019 FIT BUT
-- Author(s): Lukas Kekely <ikekely@fit.vutbr.cz>
--
-- SPDX-License-Identifier: BSD-3-Clause



library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_unsigned.all;



entity jenkins_mix is
  generic(
    -- Width of hashed key in 32-bit words.
    LENGTH          : natural := 1
  );
  port (
    -- Main clock signal and its synchronous reset.
    CLK             : in std_logic;
    RESET           : in std_logic;
    -- Input interface ---------------------------------------------------------
    INPUT_A         : in std_logic_vector(32-1 downto 0);
    INPUT_B         : in std_logic_vector(32-1 downto 0);
    INPUT_C         : in std_logic_vector(32-1 downto 0);
    INPUT_KEY       : in std_logic_vector(LENGTH*32-1 downto 0);
    INPUT_VALID     : in std_logic;
    -- Output interface --------------------------------------------------------
    OUTPUT_A        : out std_logic_vector(32-1 downto 0);
    OUTPUT_B        : out std_logic_vector(32-1 downto 0);
    OUTPUT_C        : out std_logic_vector(32-1 downto 0);
    OUTPUT_KEY      : out std_logic_vector(LENGTH*32-1 downto 0);
    OUTPUT_VALID    : out std_logic
  );
end entity;



architecture behavioral of jenkins_mix is

  constant STAGES : integer := 6;

  function rot(x : std_logic_vector(32-1 downto 0); k : natural) return std_logic_vector is
  begin
    return x(32-k-1 downto 0) & x(32-1 downto 32-k);
  end function;

  type computation_stage is record
    a : std_logic_vector(32-1 downto 0);
    b : std_logic_vector(32-1 downto 0);
    c : std_logic_vector(32-1 downto 0);
    key : std_logic_vector(LENGTH*32-1 downto 0);
    valid : std_logic;
  end record;
  type computation_stage_array is array(natural range <>) of computation_stage;

  signal s : computation_stage_array(0 to STAGES);

begin

  -- Input connections
  s(0).a <= INPUT_A;
  s(0).b <= INPUT_B;
  s(0).c <= INPUT_C;
  s(0).key <= INPUT_KEY;
  s(0).valid <= INPUT_VALID;

  -- Stage 1: a -= c;  a ^= rot(c, 4);  c += b;
  s(1).a <= (s(0).a - s(0).c) xor rot(s(0).c, 4);
  s(1).b <= s(0).b;
  s(1).c <= s(0).c + s(0).b;
  s(1).key <= s(0).key;
  s(1).valid <= s(0).valid;

  -- Stage 2: b -= a;  b ^= rot(a, 6);  a += c;
  s(2).a <= s(1).a + s(1).c;
  s(2).b <= (s(1).b - s(1).a) xor rot(s(1).a, 6);
  s(2).c <= s(1).c;
  s(2).key <= s(1).key;
  s(2).valid <= s(1).valid;

  -- Stage 3: c -= b;  c ^= rot(b, 8);  b += a;
  s(3).a <= s(2).a;
  s(3).b <= s(2).b + s(2).a;
  s(3).c <= (s(2).c - s(2).b) xor rot(s(2).b, 8);
  s(3).key <= s(2).key;
  s(3).valid <= s(2).valid;

  -- Stage 4: a -= c;  a ^= rot(c,16);  c += b;
  s(4).a <= (s(3).a - s(3).c) xor rot(s(3).c, 16);
  s(4).b <= s(3).b;
  s(4).c <= s(3).c + s(3).b;
  s(4).key <= s(3).key;
  s(4).valid <= s(3).valid;

  -- Stage 5: b -= a;  b ^= rot(a,19);  a += c;
  s(5).a <= s(4).a + s(4).c;
  s(5).b <= (s(4).b - s(4).a) xor rot(s(4).a, 19);
  s(5).c <= s(4).c;
  s(5).key <= s(4).key;
  s(5).valid <= s(4).valid;

  -- Stage 6: c -= b;  c ^= rot(b, 4);  b += a;
  s(6).a <= s(5).a;
  s(6).b <= s(5).b + s(5).a;
  s(6).c <= (s(5).c - s(5).b) xor rot(s(5).b, 4);
  s(6).key <= s(5).key;
  s(6).valid <= s(5).valid;

  -- Output connections
  OUTPUT_A <= s(STAGES).a;
  OUTPUT_B <= s(STAGES).b;
  OUTPUT_C <= s(STAGES).c;
  OUTPUT_KEY <= s(STAGES).key;
  OUTPUT_VALID <= s(STAGES).valid;

end architecture;