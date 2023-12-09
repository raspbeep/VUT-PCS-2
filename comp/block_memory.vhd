-- block_memory.vhd: General storage memory build from BlockRAMs or M20Ks with one read and one write port
-- Copyright (C) 2019 FIT BUT
-- Author(s): Lukas Kekely 
--
-- SPDX-License-Identifier: BSD-3-Clause
--
-- Optimization refactorization done by Pavel Kratochvil xkrato61

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_unsigned.all;
use work.functions_package.clog2;

entity block_memory is
	generic (
		-- Size of the memory.
		-- ITEMS individual records addressed from 0 to ITEMS-1, each ITEM_WIDTH bits wide.
		ITEM_WIDTH : natural := 32;
		ITEMS : natural := 1024;
		-- Enables output data register on read port for better frequency.
		-- Latency of reading data from the memory is 1 clock cycle when false, and 2 clock cycles when true.
		OUTPUT_REGISTER : boolean := true
	);
	port (
		-- Main clock signal and its synchronous reset.
		CLK : in std_logic;
		RESET : in std_logic;
		-- Read interface ----------------------------------------------------------
		READ_ADDRESS : in std_logic_vector(clog2(ITEMS) - 1 downto 0); -- item address to read
		READ_VALID : in std_logic; -- read is valid
		READ_DATA : out std_logic_vector(ITEM_WIDTH - 1 downto 0); -- read data (note: read latency!)
		READ_DATA_VALID : out std_logic; -- delayed read valid flag
		-- Write interface ---------------------------------------------------------
		WRITE_DATA : in std_logic_vector(ITEM_WIDTH - 1 downto 0); -- data to write
		WRITE_ADDRESS : in std_logic_vector(clog2(ITEMS) - 1 downto 0); -- item address to write
		WRITE_VALID : in std_logic -- perform write operation
	);
end entity;

architecture behavioral of block_memory is

	type memory_type is array(0 to ITEMS - 1) of std_logic_vector(ITEM_WIDTH - 1 downto 0);
	signal memory : memory_type;
	signal memory_data : std_logic_vector(ITEM_WIDTH - 1 downto 0);
	signal memory_data1 : std_logic_vector(ITEM_WIDTH - 1 downto 0);
	signal memory_data_valid : std_logic;
	signal memory_data_valid1 : std_logic;
	signal memory_read_address : std_logic_vector(clog2(ITEMS) - 1 downto 0);

begin

	-- Unsupported configurations checks -----------------------------------------
	assert ITEMS > 1 report "FAILURE: Block Memory must have at least two items!" severity failure;
	assert ITEM_WIDTH > 0 report "FAILURE: Block Memory item must be at least 1 bit wide!" severity failure;

	-- Runtime error checks ------------------------------------------------------
	assert conv_integer(READ_ADDRESS) < ITEMS or RESET /= '0' report "ERROR: Block Memory read out of bounds!" severity error;
	assert conv_integer(WRITE_ADDRESS) < ITEMS or RESET /= '0' report "ERROR: Block Memory write out of bounds!" severity error;

	-- Memory core implementation ------------------------------------------------
	storage_core : process (CLK)
	begin
		if rising_edge(CLK) then
			-- Write port
			if WRITE_VALID = '1' then
				memory(conv_integer(WRITE_ADDRESS)) <= WRITE_DATA;
			end if;
			-- Read port
			memory_read_address <= READ_ADDRESS;
			memory_data <= memory(conv_integer(memory_read_address));
			memory_data_valid1 <= memory_data_valid;

			if RESET = '1' then
				memory_data_valid <= '0';
			else
				memory_data_valid <= READ_VALID;
			end if;
		end if;
	end process;

	-- Optional output register on read port -------------------------------------
	registered_read : if OUTPUT_REGISTER generate
		read_register : process (CLK)
		begin
			if rising_edge(CLK) then
				READ_DATA <= memory_data;
				if RESET = '1' then
					READ_DATA_VALID <= '0';
				else
					READ_DATA_VALID <= memory_data_valid1;
				end if;
			end if;
		end process;
	end generate;
	direct_read : if not OUTPUT_REGISTER generate
		READ_DATA <= memory_data;
		READ_DATA_VALID <= memory_data_valid;
	end generate;

end architecture;
