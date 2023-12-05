-- filter.vhd: Exact match filter for IP addresses using multiple parallel hash tables (architecture)
-- Copyright (C) 2019 FIT BUT
-- Author(s): Lukas Kekely <ikekely@fit.vutbr.cz>
--
-- SPDX-License-Identifier: BSD-3-Clause



library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_arith.all;
use work.functions_package.all;



architecture structural of filter is

  constant RULE_WIDTH : natural := KEY_WIDTH + DATA_WIDTH + 1; -- each rule record consists of key, data, and empty flag
    subtype   RULE_KEY    is natural range  KEY_WIDTH+DATA_WIDTH downto DATA_WIDTH+1;
    subtype   RULE_DATA   is natural range  DATA_WIDTH downto 1;
    constant  RULE_EMPTY   : natural :=     0;
  constant KEY_WORDS : natural := cdiv(KEY_WIDTH, 32); -- hash component operates with 32-bit words

  type uint32_array is array (natural range<>) of std_logic_vector(32-1 downto 0);
  type rule_array is array (natural range <>) of std_logic_vector(RULE_WIDTH-1 downto 0);

  signal in_key : std_logic_vector(KEY_WORDS*32-1 downto 0) := (others => '0');
  signal in_valid : std_logic;

  signal out_key : std_logic_vector(KEY_WIDTH-1 downto 0);
  signal out_key_found : std_logic;
  signal out_data : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal out_valid : std_logic;

  signal cfg_record : std_logic_vector(RULE_WIDTH-1 downto 0);
  signal cfg_table : std_logic_vector(clog2(TABLES)-1 downto 0);
  signal cfg_item : std_logic_vector(clog2(TABLE_SIZE)-1 downto 0);
  signal cfg_write : std_logic;

  signal hash_values : uint32_array(0 to TABLES-1);
  signal hash_key : std_logic_vector(KEY_WIDTH-1 downto 0);
  signal hash_valid : std_logic_vector(TABLES-1 downto 0);

  signal memory_rule : rule_array(0 to TABLES-1);
  signal memory_key, memory_key_reg, memory_key_reg1 : std_logic_vector(KEY_WIDTH-1 downto 0);
  signal memory_valid : std_logic_vector(TABLES-1 downto 0);

  signal match_flags : std_logic_vector(TABLES-1 downto 0);

begin

  -- Unsupported configurations checks -----------------------------------------
  assert KEY_WIDTH > 0 report "FAILURE: Filter key must be at least one bit wide!" severity failure;
  assert DATA_WIDTH > 0 report "FAILURE: Filter data must be at least one bit wide!" severity failure;
  assert TABLES >= 2 report "FAILURE: Filter must have at least two tables to support effective hashing scheme!" severity failure;
  assert TABLE_SIZE > 1 report "FAILURE: Filter table must have multiple items!" severity failure;
  assert 2**clog2(TABLE_SIZE) = TABLE_SIZE report "FAILURE: Filter table must have size that is a power of 2!" severity failure;


  -- Registering of entity interfaces ------------------------------------------
  -- Input interface
  registered_input: if INPUT_REGISTER generate
    input_register: process(CLK)
    begin
      if rising_edge(CLK) then
        in_key(KEY_WIDTH-1 downto 0) <= INPUT_KEY;
        if RESET = '1' then
          in_valid <= '0';
        else
          in_valid <= INPUT_VALID;
        end if;
      end if;
    end process;
  end generate;
  dirrect_input: if not INPUT_REGISTER generate
    in_key(KEY_WIDTH-1 downto 0) <= INPUT_KEY;
    in_valid <= INPUT_VALID;
  end generate;
  -- Output interface
  registered_output: if OUTPUT_REGISTER generate
    output_register: process(CLK)
    begin
      if rising_edge(CLK) then
        OUTPUT_KEY <= out_key;
        OUTPUT_KEY_FOUND <= out_key_found;
        OUTPUT_DATA <= out_data;
        if RESET = '1' then
          OUTPUT_VALID <= '0';
        else
          OUTPUT_VALID <= out_valid;
        end if;
      end if;
    end process;
  end generate;
  dirrect_output: if not OUTPUT_REGISTER generate
    OUTPUT_KEY_FOUND <= out_key_found;
    OUTPUT_DATA <= out_data;
    OUTPUT_VALID <= out_valid;
  end generate;
  -- Configuration interface
  registered_config: if CONFIG_REGISTER generate
    config_register: process(CLK)
    begin
      if rising_edge(CLK) then
        cfg_record(RULE_KEY) <= CONFIG_KEY;
        cfg_record(RULE_DATA) <= CONFIG_DATA;
        cfg_record(RULE_EMPTY) <= CONFIG_EMPTY;
        cfg_table <= CONFIG_ADDRESS_TABLE;
        cfg_item <= CONFIG_ADDRESS_ITEM;
        if RESET = '1' then
          cfg_write <= '0';
        else
          cfg_write <= CONFIG_WRITE;
        end if;
      end if;
    end process;
  end generate;
  dirrect_config: if not CONFIG_REGISTER generate
    cfg_record(RULE_KEY) <= CONFIG_KEY;
    cfg_record(RULE_DATA) <= CONFIG_DATA;
    cfg_record(RULE_EMPTY) <= CONFIG_EMPTY;
    cfg_table <= CONFIG_ADDRESS_TABLE;
    cfg_item <= CONFIG_ADDRESS_ITEM;
    cfg_write <= CONFIG_WRITE;
  end generate;


  -- Hashing stage -------------------------------------------------------------
  hash_generate: for t in 0 to TABLES-1 generate
    signal local_key : std_logic_vector(KEY_WORDS*32-1 downto 0);
    signal local_valid : std_logic;
  begin
    hash: entity work.jenkins_hash
    generic map (
      LENGTH          => KEY_WORDS,
      INITVAL         => conv_std_logic_vector(t+1,32)
    ) port map (
      CLK             => CLK,
      RESET           => RESET,
      INPUT_KEY       => in_key,
      INPUT_VALID     => in_valid,
      OUTPUT_HASH     => hash_values(t),
      OUTPUT_KEY      => local_key,
      OUTPUT_VALID    => hash_valid(t)
    );
    key_valid_connection: if t = 0 generate -- key is pipelined inside the hash for table #0
      hash_key <= local_key(KEY_WIDTH-1 downto 0);
    end generate;
  end generate;


  -- Storage stage -------------------------------------------------------------
  storage_generate: for t in 0 to TABLES-1 generate
    signal table_select : std_logic;
    signal write_here : std_logic;
  begin
    storage: entity work.block_memory
    generic map (
      ITEM_WIDTH        => RULE_WIDTH,
      ITEMS             => TABLE_SIZE,
      OUTPUT_REGISTER   => true
    ) port map (
      CLK             => CLK,
      RESET           => RESET,
      READ_ADDRESS    => hash_values(t)(clog2(TABLE_SIZE)-1 downto 0), -- lowest hash bits are used as address
      READ_VALID      => hash_valid(t),
      READ_DATA       => memory_rule(t),
      READ_DATA_VALID => memory_valid(t),
      WRITE_DATA      => cfg_record,
      WRITE_ADDRESS   => cfg_item,
      WRITE_VALID     => write_here
    );
    table_select <= '1' when cfg_table = conv_std_logic_vector(t,clog2(TABLES)) else '0'; -- table write enable selection
    write_here <= cfg_write and table_select;
  end generate;
  key_memory_register: process(CLK) -- key pipeline to match memory latency
  begin
    if rising_edge(CLK) then
      -- memory_key <= hash_key; -- memory is configured to have one cycle read latecy
      memory_key <= memory_key_reg1;
      memory_key_reg1 <= memory_key_reg;
      memory_key_reg <= hash_key;
    end if;
  end process;


  -- Match decoding stage ------------------------------------------------------
  compare_and_select: process(memory_key, memory_rule)
  begin
    out_key_found <= '0';
    out_data <= (others => 'X');
    for t in 0 to TABLES-1 loop
      if memory_key = memory_rule(t)(RULE_KEY) then -- main key compares
        if memory_rule(t)(RULE_EMPTY) = '0' then    -- do not forget to ignore empty rules
          out_key_found <= '1';
          out_data <= memory_rule(t)(RULE_DATA);
        end if;
      end if;
    end loop;
  end process;
  out_valid <= memory_valid(0); -- select pipelined valid flag from table #0
  out_key <= memory_key;

end architecture;