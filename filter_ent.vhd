-- filter_ent.vhd: Exact match filter for IP addresses using multiple parallel hash tables (entity)
-- Copyright (C) 2019 FIT BUT
-- Author(s): Lukas Kekely <ikekely@fit.vutbr.cz>
--
-- SPDX-License-Identifier: BSD-3-Clause



library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_arith.all;
use work.functions_package.all;



entity filter is
  generic(
    -- Width of hashed key (IP address) in bits.
    KEY_WIDTH       : natural := 128;
    -- Width of data value associated with each key in bits.
    DATA_WIDTH      : natural := 16;
    -- Number of parallel hash tables or hash functions used.
    TABLES          : natural := 4;
    -- Number of items in each hash table. Must be a power of 2.
    TABLE_SIZE      : natural := 2048;
    -- Enables registers on selected interfaces for better frequency.
    INPUT_REGISTER  : boolean := true;
    OUTPUT_REGISTER : boolean := true;
    CONFIG_REGISTER : boolean := true
  );
  port (
    -- Main clock signal and its synchronous reset.
    CLK             : in std_logic;
    RESET           : in std_logic;
    -- Input interface ---------------------------------------------------------
    INPUT_KEY       : in std_logic_vector(KEY_WIDTH-1 downto 0); -- searched key
    INPUT_VALID     : in std_logic;                              -- key valid flag
    -- Output interface --------------------------------------------------------
    OUTPUT_KEY       : out std_logic_vector(KEY_WIDTH-1 downto 0);  -- delayed searched key
    OUTPUT_KEY_FOUND : out std_logic;                               -- key was found successfully
    OUTPUT_DATA      : out std_logic_vector(DATA_WIDTH-1 downto 0); -- data associated with the found key
    OUTPUT_VALID     : out std_logic;                               -- delayed input valid
    -- Configuration interface (insertion of rules) ----------------------------
    CONFIG_KEY           : in std_logic_vector(KEY_WIDTH-1 downto 0);         -- key value of a rule
    CONFIG_DATA          : in std_logic_vector(DATA_WIDTH-1 downto 0);        -- data value of a rule
    CONFIG_EMPTY         : in std_logic;                                      -- rule is empty flag (data+key are ignored and rule cannot be matched)
    CONFIG_ADDRESS_TABLE : in std_logic_vector(clog2(TABLES)-1 downto 0);     -- address where to write the rule - table selection
    CONFIG_ADDRESS_ITEM  : in std_logic_vector(clog2(TABLE_SIZE)-1 downto 0); -- address where to write the rule - item selection in the table
    CONFIG_WRITE         : in std_logic                                       -- write enable flag
  );
end entity;
