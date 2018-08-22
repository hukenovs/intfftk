-------------------------------------------------------------------------------
--
-- Title       : fft_signle_test
-- Design      : fpfftk
-- Author      : Kapitanov Alexander
-- Company     : 
-- E-mail      : sallador@bk.ru
--
-- Description : Testbench file for complex testing FFT / IFFT
--
-- Has several important constants:
--
--		NFFT		- (p) - Number of stages = log2(FFT LENGTH)
--		SCALE		- (s) - Scale factor for float-to-fix transform
--		DATA_WIDTH		- (p) - Data width for signal imitator: 8-32 bits.
--		TWDL_WIDTH		- (p) - Data width for twiddle factor : 16-24 bits.
--		OWIDTH		- (p) - Data width for signal output: 16, 24, 32 bits.
--		FLY_FWD		- (s) - Use butterflies into Forward FFT: 1 - TRUE, 0 - FALSE
--		DBG_FWD		- (p) - 1 - Debug in FFT (save file in FP32 on selected stage)	
--		DT_RND		- (s) - Data output multiplexer for rounding			
--		XSERIES		- (p) -	FPGA Series: ULTRASCALE / 7SERIES
--		USE_MLT		- (p) -	Use Multiplier for calculation M_PI in Twiddle factor
--
-- where: (p) - generic parameter, (s) - signal.
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
use ieee.std_logic_signed.all;
use ieee.std_logic_arith.all;
use ieee.math_real.all;

use ieee.std_logic_textio.all;
use std.textio.all;	

entity fft_signle_test is 
end fft_signle_test;

architecture fft_signle_test of fft_signle_test is   		
  
-- **************************************************************** --
-- **** Constant declaration: change any parameter for testing **** --
-- **************************************************************** --
constant	NFFT 		: integer:=10; -- Number of stages = log2(FFT LENGTH)

constant	DATA_WIDTH	: integer:=16; -- Data width for signal imitator	: 8-32.
constant	TWDL_WIDTH	: integer:=16; -- Data width for twiddle factor 	: 16-24.

constant	FLY_FWD		: std_logic:='1'; -- 1 - Use butterflies for Forward FFT	

constant	XSERIES		: string:="NEW"; -- FPGA Series: ULTRA / 7SERIES
constant	USE_MLT		: boolean:=FALSE; -- 1 - Use Multiplier for calculation M_PI

-- **************************************************************** --
-- ********* Signal declaration: clocks, reset, data etc. ********* --
-- **************************************************************** --

signal clk				: std_logic:='0';
signal reset			: std_logic:='0';
signal start			: std_logic:='0';

------------------------ In / Out data --------------------	
signal di_re			: std_logic_vector(DATA_WIDTH-1 downto 0):=(others=>'0'); 
signal di_im			: std_logic_vector(DATA_WIDTH-1 downto 0):=(others=>'0'); 
signal di_en			: std_logic:='0';

signal do_re			: std_logic_vector(NFFT+DATA_WIDTH-1 downto 0);
signal do_im 			: std_logic_vector(NFFT+DATA_WIDTH-1 downto 0);
signal do_vl			: std_logic;

signal sc_re			: std_logic_vector(DATA_WIDTH-1 downto 0);
signal sc_im 			: std_logic_vector(DATA_WIDTH-1 downto 0);
signal sc_vl			: std_logic;

begin

clk <= not clk after 5 ns;
reset <= '0', '1' after 30 ns;
start <= '0', '1' after 100 ns;

-------------------------------------------------------------------------------- 
read_signal: process is
	file fl_data		: text;
	constant fl_path	: string:="../../../../../math/di_single.dat";

	variable l		: line;	
	variable lt1	: integer:=0; 
	variable lt2	: integer:=0; 
begin  	  	
	wait for 5 ns;
	if (reset = '0') then	
		di_en <= '0';
		di_re <= (others => '0');
		di_im <= (others => '0');		
	else	
		-- wait for 100 ns;
		wait until (start = '1');
		
		lp_inf: for jj in 0 to 63 loop	   

			file_open( fl_data, fl_path, read_mode );				

			-- lp_32k: for ii in 0 to Nst2x-1 loop
			while not endfile(fl_data) loop
				wait until rising_edge(clk);
					
					readline( fl_data, l ); 
					read( l, lt1 );	read( l, lt2 );	 
					
					di_re <= conv_std_logic_vector( lt1, DATA_WIDTH );
					di_im <= conv_std_logic_vector( lt2, DATA_WIDTH );
					di_en <= '1'; 
					
					-- wait until rising_edge(clk);
					-- di_en <= '0';
					-- di_re <= (others => '0');
					-- di_im <= (others => '0');						
			end loop;
			
			file_close( fl_data);
			
			wait until rising_edge(clk);
			di_en <= '0';
			di_re <= (others => '0');
			di_im <= (others => '0');
			
			lp_Nk: for ii in 0 to 31 loop
				wait until rising_edge(clk);
			end loop;
			
		end loop;
		
		di_en <= 'X';
		di_re <= (others => 'X');
		di_im <= (others => 'X');	
		wait;
		
	end if;
end process; 

--------------------------------------------------------------------------------
UUT: entity work.int_fft_single_path
	generic map ( 
		TD				=> 0.1 ns,	
		DATA_WIDTH		=> DATA_WIDTH,
		TWDL_WIDTH		=> TWDL_WIDTH,	
		XSERIES			=> XSERIES,	
		NFFT			=> NFFT,	
		USE_MLT			=> USE_MLT	
	)   
	port map ( 
		---- Common signals ----
		RESET			=> reset,	
		CLK				=> clk,	
		---- Input data ----
		DI_RE			=> di_re,
		DI_IM			=> di_im,
		DI_EN			=> di_en,
		---- Output data ----
		DO_RE			=> do_re,
		DO_IM			=> do_im,
		DO_VL			=> do_vl,
		---- Butterflies ----
		FLY_FWD			=> fly_fwd
	);
	
UUT_SC: entity work.int_fft_single_scaled
	generic map ( 
		TD				=> 0.1 ns,	
		DATA_WIDTH		=> DATA_WIDTH,
		TWDL_WIDTH		=> TWDL_WIDTH,	
		XSERIES			=> XSERIES,	
		NFFT			=> NFFT,	
		USE_MLT			=> USE_MLT	
	)   
	port map ( 
		---- Common signals ----
		RESET			=> reset,	
		CLK				=> clk,	
		---- Input data ----
		DI_RE			=> di_re,
		DI_IM			=> di_im,
		DI_EN			=> di_en,
		---- Output data ----
		DO_RE			=> sc_re,
		DO_IM			=> sc_im,
		DO_VL			=> sc_vl,
		---- Butterflies ----
		FLY_FWD			=> fly_fwd
	);
end fft_signle_test; 