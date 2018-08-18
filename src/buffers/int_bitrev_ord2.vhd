-------------------------------------------------------------------------------
--
-- Title       : Bit-reverse 
-- Design      : FFT
-- Author      : Kapitanov Alexander
-- Company     : 
--
-------------------------------------------------------------------------------
--
--	Version 1.0  13.08.2017
--			   	 Description: Universal bitreverse algorithm for FFT project
-- 					It has several independent DPRAM components for FFT stages 
-- 					between 2k and 512k
--
--	Version 2.0  01.08.2018
--			Bit-reverse w/ signle cache RAM for operation!
--
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--
--	GNU GENERAL PUBLIC LICENSE
--  Version 3, 29 June 2007
--
--	Copyright (c) 2018 Kapitanov Alexander
--
--  This program is free software: you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation, either version 3 of the License, or
--  (at your option) any later version.
--
--  You should have received a copy of the GNU General Public License
--  along with this program.  If not, see <http://www.gnu.org/licenses/>.
--
--  THERE IS NO WARRANTY FOR THE PROGRAM, TO THE EXTENT PERMITTED BY
--  APPLICABLE LAW. EXCEPT WHEN OTHERWISE STATED IN WRITING THE COPYRIGHT 
--  HOLDERS AND/OR OTHER PARTIES PROVIDE THE PROGRAM "AS IS" WITHOUT WARRANTY 
--  OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, 
--  THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR 
--  PURPOSE.  THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE PROGRAM 
--  IS WITH YOU.  SHOULD THE PROGRAM PROVE DEFECTIVE, YOU ASSUME THE COST OF 
--  ALL NECESSARY SERVICING, REPAIR OR CORRECTION. 
-- 
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity int_bitrev_ord2 is
	generic (	
		STAGES		: integer:=11; --! FFT stages
		NWIDTH		: integer:=16 --! Data width		
	);
	port(								
		clk  		: in  std_logic; --! Clock
		reset 		: in  std_logic; --! Reset		
		
		di_dt		: in  std_logic_vector(NWIDTH-1 downto 0); --! Data input
		di_en		: in  std_logic; --! DATA enable

		do_dt		: out std_logic_vector(NWIDTH-1 downto 0); --! Data output	
		do_vl		: out std_logic --! DATA valid		
	);	
end int_bitrev_ord2;

architecture int_bitrev_ord2 of int_bitrev_ord2 is

signal rstp				: std_logic;

signal addra			: std_logic_vector(STAGES-1 downto 0);
signal addrb			: std_logic_vector(STAGES-1 downto 0);
signal cnt				: std_logic_vector(STAGES downto 0);	  

signal ram_di			: std_logic_vector(NWIDTH-1 downto 0);
signal ram_dz			: std_logic_vector(NWIDTH-1 downto 0);
signal ram_do			: std_logic_vector(NWIDTH-1 downto 0);

signal wea				: std_logic;
signal wez				: std_logic;
signal rdt				: std_logic;
signal vld				: std_logic;

signal valid			: std_logic;

function bit_pair(Len: integer; Dat: std_logic_vector) return std_logic_vector is
	variable Tmp : std_logic_vector(Len-1 downto 0);
begin 
	Tmp(0) :=  Dat(Len-1);
	for ii in 1 to Len-1 loop
		Tmp(ii) := Dat(ii-1);
	end loop;
	return Tmp; 
end function; 

signal cnt1st	: std_logic_vector(STAGES downto 0);	

begin

rstp <= not reset when rising_edge(clk);	

-- Data out and valid proc --	
pr_cnt1: process(clk) is
begin
	if rising_edge(clk) then
		if (rstp = '1') then
			cnt1st <= (others => '0');		
		else		
			if (di_en = '1') then
				if (cnt1st(STAGES) = '0') then
					cnt1st <= cnt1st + '1';
				end if;
			end if;	
		end if;
	end if;
end process;

-- Data out and valid proc --	
do_dt <= ram_do;
do_vl <= valid;
		
-- Common proc --	
ram_di <= di_dt when rising_edge(clk);
ram_dz <= ram_di when rising_edge(clk);

pr_cnt: process(clk) is
begin
	if rising_edge(clk) then
		if (rstp = '1') then
			cnt <= (others => '0');
		else
			if (di_en = '1') then
				cnt <= cnt + '1';
			end if;	
		end if;
	end if;
end process;

wea <= di_en when rising_edge(clk);
wez <= wea when rising_edge(clk);

-- Read / Address proc --	
vld <= rdt when rising_edge(clk);
rdt <= di_en and cnt1st(STAGES) when rising_edge(clk);

pr_adr: process(clk) is
begin
	if rising_edge(clk) then
		if (cnt(cnt'left) = '0') then
			addra <= cnt(STAGES-1 downto 0);
		else	
			xl2: for ii in 0 to STAGES-1 loop
				addra(ii) <= cnt(STAGES-1-ii);
			end loop;
		end if;
	end if;
end process;
addrb <= addra when rising_edge(clk);

-- RAMB generator --	
G_LOW_STAGE: if (STAGES < 9) generate	
	type ram_t is array(0 to 2**(STAGES)-1) of std_logic;--_vector(31 downto 0);	
begin
	X_GEN_SRL0: for ii in 0 to NWIDTH-1 generate
	begin
		pr_srlram0: process(clk) is
			variable ram0 : ram_t;
		begin
			if (clk'event and clk = '1') then
				if (wez = '1') then
					ram0(conv_integer(addrb)) := ram_dz(ii);
				end if;
				if (rdt = '1') then
					ram_do(ii) <= ram0(conv_integer(addra)); -- dual port
				end if;
			end if;	
		end process;
	end generate;

	valid <= vld;
end generate; 

G_HIGH_STAGE: if (STAGES >= 9) generate
	type ram_t is array(0 to 2**(STAGES)-1) of std_logic_vector(NWIDTH-1 downto 0);
	signal ram0			: ram_t;
	signal dout0		: std_logic_vector(NWIDTH-1 downto 0);

	attribute ram_style			: string;
	attribute ram_style of RAM0 : signal is "block";	

begin

	PR_RAMB0: process(clk) is
	begin
		if (clk'event and clk = '1') then
			ram_do <= dout0;
			if (rstp = '1') then
				dout0 <= (others => '0');
			else
				if (rdt = '1') then
					dout0 <= ram0(conv_integer(addra)); -- dual port
				end if;
			end if;	
			
			if (wez = '1') then
				ram0(conv_integer(addrb)) <= ram_dz;
			end if;
		end if;	
	end process;

	valid <= vld when rising_edge(clk);
end generate;

end int_bitrev_ord2;