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
  
  signal inter1 : computation_stage;
  signal inter2 : computation_stage;
  
  signal inter11 : computation_stage;
  signal inter12 : computation_stage;
  
  signal inter21 : computation_stage;
  signal inter22: computation_stage;
  
  

begin
  -- Input connections
  s(0).a <= INPUT_A;
  s(0).b <= INPUT_B;
  s(0).c <= INPUT_C;
  s(0).key <= INPUT_KEY;
  s(0).valid <= INPUT_VALID;

  -- Stage 1: a -= c;  a ^= rot(c, 4);  c += b;
  inter11.a <= (s(0).a - s(0).c) xor rot(s(0).c, 4);
  inter11.b <= s(0).b;
  inter11.c <= s(0).c + s(0).b;
  inter11.key <= s(0).key;
  inter11.valid <= s(0).valid;
  
  -- Pipeline registers update process
    process(CLK) begin
        if rising_edge(CLK) then
            if RESET = '1' then
                -- Reset logic for inter2
                inter12.a <= (others => '0');
                inter12.b <= (others => '0');
                inter12.c <= (others => '0');
                inter12.key <= (others => '0');
                inter12.valid <= '0';
            else
                inter12.a <= inter11.a;
                inter12.b <= inter11.b;
                inter12.c <= inter11.c;
                inter12.key <= inter11.key;
                inter12.valid <= inter11.valid;
            end if;
        end if;
    end process;

  -- Stage 2: b -= a;  b ^= rot(a, 6);  a += c;
  s(2).a <= inter12.a + inter12.c;
  s(2).b <= (inter12.b - inter12.a) xor rot(inter12.a, 6);
  s(2).c <= inter12.c;
  s(2).key <= inter12.key;
  s(2).valid <= inter12.valid;

  -- Stage 3: c -= b;  c ^= rot(b, 8);  b += a;
  inter1.a <= s(2).a;
  inter1.b <= s(2).b + s(2).a;
  inter1.c <= (s(2).c - s(2).b) xor rot(s(2).b, 8);
  inter1.key <= s(2).key;
  inter1.valid <= s(2).valid;
  
    -- Pipeline registers update process
    process(CLK) begin
        if rising_edge(CLK) then
            if RESET = '1' then
                -- Reset logic for inter2
                inter2.a <= (others => '0');
                inter2.b <= (others => '0');
                inter2.c <= (others => '0');
                inter2.key <= (others => '0');
                inter2.valid <= '0';
            else
                inter2.a <= inter1.a;
                inter2.b <= inter1.b;
                inter2.c <= inter1.c;
                inter2.key <= inter1.key;
                inter2.valid <= inter1.valid;
            end if;
        end if;
    end process;
    
  s(3).a <= inter2.a;
  s(3).b <= inter2.b;
  s(3).c <= inter2.c;
  s(3).key <= inter2.key;
  s(3).valid <= inter2.valid;
    

  -- Stage 4: a -= c;  a ^= rot(c,16);  c += b;
  inter21.a <= (s(3).a - s(3).c) xor rot(s(3).c, 16);
  inter21.b <= s(3).b;
  inter21.c <= s(3).c + s(3).b;
  inter21.key <= s(3).key;
  inter21.valid <= s(3).valid;
  
    -- Pipeline registers update process
    process(CLK) begin
        if rising_edge(CLK) then
            if RESET = '1' then
                -- Reset logic for inter2
                inter22.a <= (others => '0');
                inter22.b <= (others => '0');
                inter22.c <= (others => '0');
                inter22.key <= (others => '0');
                inter22.valid <= '0';
            else
                inter22.a <= inter21.a;
                inter22.b <= inter21.b;
                inter22.c <= inter21.c;
                inter22.key <= inter21.key;
                inter22.valid <= inter21.valid;
            end if;
        end if;
    end process;

  -- Stage 5: b -= a;  b ^= rot(a,19);  a += c;
  s(5).a <= inter22.a + inter22.c;
  s(5).b <= (inter22.b - inter22.a) xor rot(inter22.a, 19);
  s(5).c <= inter22.c;
  s(5).key <= inter22.key;
  s(5).valid <= inter22.valid;

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