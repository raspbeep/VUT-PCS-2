-- jenkins_hash.vhd: Jenkins hashing function VHDL implementation based on https://burtleburtle.net/bob/c/lookup3.c
-- Copyright (C) 2019 FIT BUT
-- Author(s): Lukas Kekely <ikekely@fit.vutbr.cz>
--
-- SPDX-License-Identifier: BSD-3-Clause



library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_unsigned.all;
use IEEE.std_logic_arith.all;



entity jenkins_hash is
  generic(
    -- Width of hashed key in 32-bit words.
    LENGTH          : natural := 1;
    -- Initialization seed value.
    INITVAL         : std_logic_vector(32-1 downto 0) := X"DEADBABE"
  );
  port (
    -- Main clock signal and its synchronous reset.
    CLK             : in std_logic;
    RESET           : in std_logic;
    -- Input interface ---------------------------------------------------------
    INPUT_KEY       : in std_logic_vector(LENGTH*32-1 downto 0); -- value to be hashed
    INPUT_VALID     : in std_logic;                              -- key valid
    -- Output interface --------------------------------------------------------
    OUTPUT_HASH     : out std_logic_vector(32-1 downto 0);        -- computed hash value
    OUTPUT_KEY      : out std_logic_vector(LENGTH*32-1 downto 0); -- delayed input key
    OUTPUT_VALID    : out std_logic                               -- delayed input valid
  );
end entity;



architecture behavioral of jenkins_hash is

  constant MIX_STAGES : integer := (LENGTH-1) / 3;
  constant FINAL_LENGTH : integer := LENGTH - MIX_STAGES*3;
  constant INITIAL_VALUE : std_logic_vector(32-1 downto 0) := X"deadbeef" + conv_std_logic_vector(LENGTH*4, 32) + INITVAL;

  type computation_stage is record
    a : std_logic_vector(32-1 downto 0);
    b : std_logic_vector(32-1 downto 0);
    c : std_logic_vector(32-1 downto 0);
    key : std_logic_vector(LENGTH*32-1 downto 0);
    valid : std_logic;
  end record;
  type computation_stage_array is array(natural range <>) of computation_stage;

  signal mix_stage : computation_stage_array(0 to MIX_STAGES);
  signal mix_to_final : computation_stage;

  signal final_adders : computation_stage;
  signal final_key_part : std_logic_vector(FINAL_LENGTH*32-1 downto 0);

begin

  -- Unsupported configurations checks -----------------------------------------
  assert LENGTH > 0 report "FAILURE: Jenkins Hash key must be at least one word wide!" severity failure;

  -- Set up the internal state -------------------------------------------------
  mix_stage(0).a <= INITIAL_VALUE;
  mix_stage(0).b <= INITIAL_VALUE;
  mix_stage(0).c <= INITIAL_VALUE;
  mix_stage(0).key <= INPUT_KEY;
  mix_stage(0).valid <= INPUT_VALID;

  -- Handle most of the key ----------------------------------------------------
  mix_pipeline: for s in 0 to MIX_STAGES-1 generate
    signal local_key_part : std_logic_vector(3*32-1 downto 0);
    signal adders : computation_stage;
  begin
    -- initial adding with key words
    local_key_part <= mix_stage(s).key(3*32*(s+1)-1 downto 3*32*s);
    adders.a <= mix_stage(s).a + local_key_part(32-1 downto 0);
    adders.b <= mix_stage(s).b + local_key_part(64-1 downto 32);
    adders.c <= mix_stage(s).c + local_key_part(96-1 downto 64);
    adders.key <= mix_stage(s).key;
    adders.valid <= mix_stage(s).valid;
    -- mixing operation itself
    mix: entity work.jenkins_mix
    generic map (
      LENGTH       => LENGTH
    ) port map (
      CLK          => CLK,
      RESET        => RESET,
      INPUT_A      => adders.a,
      INPUT_B      => adders.b,
      INPUT_C      => adders.c,
      INPUT_KEY    => adders.key,
      INPUT_VALID  => adders.valid,
      OUTPUT_A     => mix_stage(s+1).a, -- output dirrectly to the next stage
      OUTPUT_B     => mix_stage(s+1).b,
      OUTPUT_C     => mix_stage(s+1).c,
      OUTPUT_KEY   => mix_stage(s+1).key,
      OUTPUT_VALID => mix_stage(s+1).valid
    );
  end generate;
  mix_to_final <= mix_stage(MIX_STAGES); -- output from the last mix stage is input for final


  -- Handle the last 3 words ---------------------------------------------------
  -- initial adding with key words for given length
  final_key_part <= mix_to_final.key(LENGTH*32-1 downto LENGTH*32-FINAL_LENGTH*32);
  final_length3: if FINAL_LENGTH = 3 generate
    final_adders.c <= mix_to_final.c + final_key_part(96-1 downto 64);
    final_adders.b <= mix_to_final.b + final_key_part(64-1 downto 32);
    final_adders.a <= mix_to_final.a + final_key_part(32-1 downto 0);
  end generate;
  final_length2: if FINAL_LENGTH = 2 generate
    final_adders.c <= mix_to_final.c;
    final_adders.b <= mix_to_final.b + final_key_part(64-1 downto 32);
    final_adders.a <= mix_to_final.a + final_key_part(32-1 downto 0);
  end generate;
  final_length1: if FINAL_LENGTH = 1 generate
    final_adders.c <= mix_to_final.c;
    final_adders.b <= mix_to_final.b;
    final_adders.a <= mix_to_final.a + final_key_part(32-1 downto 0);
  end generate;
  final_length0: if FINAL_LENGTH = 0 generate
    assert false report "FAILURE: Jenkins Hash impossible generate state reached in final stage!" severity failure;
  end generate;
  final_adders.key <= mix_to_final.key;
  final_adders.valid <= mix_to_final.valid;
  -- final operation itself
  final: entity work.jenkins_final
  generic map (
    LENGTH       => LENGTH
  ) port map (
    CLK          => CLK,
    RESET        => RESET,
    INPUT_A      => final_adders.a,
    INPUT_B      => final_adders.b,
    INPUT_C      => final_adders.c,
    INPUT_KEY    => final_adders.key,
    INPUT_VALID  => final_adders.valid,
    OUTPUT_A     => open,        -- output dirrectly into hash output
    OUTPUT_B     => open,
    OUTPUT_C     => OUTPUT_HASH, -- C is returned as hash
    OUTPUT_KEY   => OUTPUT_KEY,
    OUTPUT_VALID => OUTPUT_VALID
  );

end architecture;