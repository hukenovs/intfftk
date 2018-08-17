-------------------------------------------------------------------------------
--
-- Title       : int_fft_ifft_pair
-- Design      : FFT
-- Author      : Kapitanov Alexander
-- Company     : 
-- E-mail      : sallador@bk.ru
--
-- Description : Main module for FFT/IFFT logic
--
-- Has several important constants:
--
--		NFFT			- (p) - Number of stages = log2(FFT LENGTH)
--		DATA_WIDTH		- (p) - Data width for signal imitator: 8-32 bits.
--		TWDL_WIDTH		- (p) - Data width for twiddle factor : 8-24/26 bits.
--		FLY_FWD			- (s) - Use butterflies into Forward FFT: 1 - TRUE, 0 - FALSE
--		FLY_INV			- (s) - Use butterflies into Inverse FFT: 1 - TRUE, 0 - FALSE			
--		XSERIES			- (p) -	FPGA Series: ULTRASCALE / 7SERIES
--		USE_MLT			- (p) -	Use Multiplier for calculation M_PI in Twiddle factor
--
-- where: (p) - generic parameter, (s) - signal.
--
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--
--	The MIT License (MIT)
--	Copyright (c) 2018 Kapitanov Alexander 													 
--		                                          				 
-- Permission is hereby granted, free of charge, to any person obtaining a copy 
-- of this software and associated documentation files (the "Software"), 
-- to deal in the Software without restriction, including without limitation 
-- the rights to use, copy, modify, merge, publish, distribute, sublicense, 
-- and/or sell copies of the Software, and to permit persons to whom the 
-- Software is furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in 
-- all copies or substantial portions of the Software.
--
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL 
-- THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS 
-- IN THE SOFTWARE.
-- 	                                                 
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;  
use ieee.std_logic_signed.all;
use ieee.std_logic_arith.all;

use ieee.std_logic_textio.all;
use std.textio.all;

entity int_fft_ifft_pair is
	generic (	
		TD				: time:=0.1ns;  		--! Simulation time	
		NFFT			: integer:=13;			--! Number of FFT stages
		DATA_WIDTH		: integer:=16;			--! Data input width (8-32)
		TWDL_WIDTH		: integer:=16; 			--! Data width for twiddle factor
		XSERIES			: string:="NEW";		--! FPGA family: for 6/7 series: "OLD"; for ULTRASCALE: "NEW";
		USE_MLT			: boolean:=FALSE 		--! Use Multiplier for calculation M_PI in Twiddle factor
	);														  
	port (													  
		---- Common ----
		RESET			: in  std_logic;	--! Global reset
		CLK				: in  std_logic;	--! DSP clock
		---- Butterflies ----
		FLY_FWD			: in  std_logic;	--! Forward: '1' - use BFLY, '0' -don't use
		FLY_INV			: in  std_logic;	--! Inverse: '1' - use BFLY, '0' -don't use
		---- Input data ----
		D0_RE			: in  std_logic_vector(DATA_WIDTH-1 downto 0); --! Real: 1'st data part [0:N/2)
		D1_RE			: in  std_logic_vector(DATA_WIDTH-1 downto 0); --! Real: 2'nd data part [N/2:N)
		D0_IM			: in  std_logic_vector(DATA_WIDTH-1 downto 0); --! Imag: 1'st data part [0:N/2)
		D1_IM			: in  std_logic_vector(DATA_WIDTH-1 downto 0); --! Imag: 2'nd data part [N/2:N)	
		DI_EN			: in  std_logic; --! Data enable strobe (valid)
		---- Output data ----
		DO_RE 			: out std_logic_vector(DATA_WIDTH+2*NFFT-1 downto 0); --! Output data Even
		DO_IM 			: out std_logic_vector(DATA_WIDTH+2*NFFT-1 downto 0); --! Output data Odd
		DO_VL			: out std_logic	--! Output valid data
	);
end int_fft_ifft_pair;

architecture int_fft_ifft_pair of int_fft_ifft_pair is   

signal rstp				: std_logic;
signal rstn				: std_logic;

---------------- Input data ----------------
signal di_d0			: std_logic_vector(2*DATA_WIDTH-1 downto 0);
signal di_d1			: std_logic_vector(2*DATA_WIDTH-1 downto 0);
signal da_dt			: std_logic_vector(2*DATA_WIDTH-1 downto 0);
signal db_dt			: std_logic_vector(2*DATA_WIDTH-1 downto 0);

---------------- Forward FFT ----------------
signal di_re0			: std_logic_vector(DATA_WIDTH-1 downto 0);
signal di_im0			: std_logic_vector(DATA_WIDTH-1 downto 0);
signal di_re1 			: std_logic_vector(DATA_WIDTH-1 downto 0);
signal di_im1			: std_logic_vector(DATA_WIDTH-1 downto 0);

signal do_re0			: std_logic_vector(NFFT+DATA_WIDTH-1 downto 0);
signal do_im0			: std_logic_vector(NFFT+DATA_WIDTH-1 downto 0);
signal do_re1 			: std_logic_vector(NFFT+DATA_WIDTH-1 downto 0);
signal do_im1			: std_logic_vector(NFFT+DATA_WIDTH-1 downto 0);

signal di_ena			: std_logic;
signal do_val			: std_logic;

---------------- Inverse FFT ----------------
signal fi_re0			: std_logic_vector(NFFT+DATA_WIDTH-1 downto 0);
signal fi_im0			: std_logic_vector(NFFT+DATA_WIDTH-1 downto 0);
signal fi_re1 			: std_logic_vector(NFFT+DATA_WIDTH-1 downto 0);
signal fi_im1			: std_logic_vector(NFFT+DATA_WIDTH-1 downto 0);

signal fo_re0			: std_logic_vector(2*NFFT+DATA_WIDTH-1 downto 0);
signal fo_im0			: std_logic_vector(2*NFFT+DATA_WIDTH-1 downto 0);
signal fo_re1 			: std_logic_vector(2*NFFT+DATA_WIDTH-1 downto 0);
signal fo_im1			: std_logic_vector(2*NFFT+DATA_WIDTH-1 downto 0);

signal fi_ena			: std_logic;
signal fo_val			: std_logic;

---------------- Shuffle data ----------------
signal dt_int0			: std_logic_vector(2*(2*NFFT+DATA_WIDTH)-1 downto 0);    
signal dt_int1			: std_logic_vector(2*(2*NFFT+DATA_WIDTH)-1 downto 0);    
signal dt_en01			: std_logic;     

signal qx_dt			: std_logic_vector(2*(2*NFFT+DATA_WIDTH)-1 downto 0);
---------------- Output data ----------------
signal dx_re 			: std_logic_vector(2*NFFT+DATA_WIDTH-1 downto 0);
signal dx_im 			: std_logic_vector(2*NFFT+DATA_WIDTH-1 downto 0);
signal dx_en			: std_logic;			
	
begin

rstp <= not reset after td when rising_edge(clk);
rstn <= reset after td when rising_edge(clk);

di_d0 <= D0_IM & D0_RE;
di_d1 <= D1_IM & D1_RE;

-------------------- INPUT BUFFER --------------------
xIN_BUF: entity work.iobuf_flow_int2
	generic map (
		TD			=> TD,
		BITREV		=> FALSE,
		ADDR 		=> NFFT,
		DATA		=> 2*DATA_WIDTH
	)	
	port map (
		clk  		=> clk,
		rst			=> rstp,		
	
		dt_int0		=> di_d0,
		dt_int1		=> di_d1,
		dt_en01		=> di_en,

		dt_rev0		=> da_dt,		
		dt_rev1		=> db_dt,		
		dt_vl01		=> di_ena
	);

di_re0 <= da_dt(1*DATA_WIDTH-1 downto 0*DATA_WIDTH);	
di_im0 <= da_dt(2*DATA_WIDTH-1 downto 1*DATA_WIDTH);	
di_re1 <= db_dt(1*DATA_WIDTH-1 downto 0*DATA_WIDTH);	
di_im1 <= db_dt(2*DATA_WIDTH-1 downto 1*DATA_WIDTH);	

------------------ FFTK_N (FORWARD FFT) --------------------
xFFT: entity work.int_fftNk
	generic map (
		IS_SIM		=> FALSE,
		TD			=> TD,
		NFFT		=> NFFT,
		DATA_WIDTH	=> DATA_WIDTH,
		TWDL_WIDTH	=> TWDL_WIDTH,
		XSER		=> XSERIES,
		USE_MLT		=> USE_MLT
	)
	port map (
		DI_RE0		=> di_re0,
		DI_IM0		=> di_im0,
		DI_RE1		=> di_re1,
		DI_IM1		=> di_im1,
		DI_ENA		=> di_ena,
    
		USE_FLY		=> fly_fwd,
	
		DO_RE0		=> do_re0,
		DO_IM0		=> do_im0,
		DO_RE1		=> do_re1,
		DO_IM1		=> do_im1,
		DO_VAL		=> do_val,
		
		RST  		=> rstp, 
		CLK 		=> clk
	);

------------------ FFTK_N (FORWARD FFT) --------------------
fi_re0 <= do_re0 when rising_edge(clk);
fi_im0 <= do_im0 when rising_edge(clk);
fi_re1 <= do_re1 when rising_edge(clk);
fi_im1 <= do_im1 when rising_edge(clk);
fi_ena <= do_val when rising_edge(clk);

xIFFT: entity work.int_ifftNk
	generic map (
		IS_SIM		=> FALSE,
		TD			=> TD,
		NFFT		=> NFFT,
		DATA_WIDTH	=> DATA_WIDTH+NFFT,
		TWDL_WIDTH	=> TWDL_WIDTH,
		XSER		=> XSERIES,
		USE_MLT		=> USE_MLT
	)
	port map (
		DI_RE0		=> fi_re0,
		DI_IM0		=> fi_im0,
		DI_RE1		=> fi_re1,
		DI_IM1		=> fi_im1,
		DI_ENA		=> fi_ena,
    
		USE_FLY		=> fly_inv,
	
		DO_RE0		=> fo_re0,
		DO_IM0		=> fo_im0,
		DO_RE1		=> fo_re1,
		DO_IM1		=> fo_im1,
		DO_VAL		=> fo_val,
		
		RST  		=> rstp, 
		CLK 		=> clk
	);	

-------------------- SHUFFLE BUFFER --------------------	
dt_int0 <= fo_im0 & fo_re0;
dt_int1 <= fo_im1 & fo_re1;
dt_en01 <= fo_val;

xSHL_BUF: entity work.iobuf_flow_int2 
	generic map (
		TD			=> TD,
		BITREV		=> TRUE,
		ADDR 		=> NFFT,
		DATA		=> 2*(2*NFFT+DATA_WIDTH)
	)
	port map (
		clk 		=> clk,
		rst 		=> rstp,    

	    dt_int0		=> dt_int0, 
	    dt_int1		=> dt_int1, 
	    dt_en01		=> dt_en01,
		
	    dt_rev0		=> open,
	    dt_rev1		=> open,
		dt_vl01		=> open
	);


--------------------------------------------------------------------------------
-------------------- FOT TESTS ONLY -------------------
--------------------------------------------------------------------------------

-------------------- OUTPUT BUFFER --------------------	
xOUT_BUF : entity work.outbuf_half_path
	generic map (
		TD			=> TD,
		ADDR 		=> NFFT,
		DATA		=> 2*(2*NFFT+DATA_WIDTH)
	)
	port map (
		clk 		=> clk,
		reset 		=> rstp,		

		da_dt		=> dt_int0, --dt_rev0,
		db_dt		=> dt_int1, --dt_rev1,
		ab_vl		=> dt_en01, --dt_vl01,

		do_dt		=> qx_dt,
		do_en		=> dx_en	
	);

do_re(2*NFFT+DATA_WIDTH-1 downto 00) <= qx_dt(1*(2*NFFT+DATA_WIDTH)-1 downto 0*(2*NFFT+DATA_WIDTH));
do_im(2*NFFT+DATA_WIDTH-1 downto 00) <= qx_dt(2*(2*NFFT+DATA_WIDTH)-1 downto 1*(2*NFFT+DATA_WIDTH));

do_vl <= dx_en;

end int_fft_ifft_pair;