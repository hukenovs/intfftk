//-----------------------------------------------------------------------------
//
// Title       : int_cmult_dbl35_dsp48
// Design      : FFTK
// Author      : Kapitanov
// Company     :
//
// Description : Integer complex multiplier (double mult width)
//
//-----------------------------------------------------------------------------
//
//	Version 1.0: 14.02.2018
//
//  Description: Double complex multiplier by DSP48 unit
//    "Double35" means that the unit uses two DSP48 w/ 35-bits width on port (B)
//
//  Math:
//
//  Out:    In:
//  MP_12 = M2_AA * M2_BB + M1_AA * M1_BB; (ALUMODE = "0000")
//  MP_12 = M2_AA * M2_BB - M1_AA * M1_BB; (ALUMODE = "0011")
//
//	Input variables:
//    1. MAW - Input data width for A ports
//    2. MBW - Input data width for B ports
//    3. XALU - ALU MODE: 
//        "ADD" - adder
//        "SUB" - subtractor
//
//  DSP48 data signals:
//    A port - data width up to 35 bits
//    B port - data width up to 25 (27)* bits
//    P port - data width up to 60 (62)** bits
//  * - 25 bits for DSP48E1, 27 bits for DSP48E2.
//  * - 60 bits for DSP48E1, 62 bits for DSP48E2.
//
//  Total delay      : 6 clock cycles
//  Total resources  : 5 DSP48 units
//
//  Unit dependence:
//    >. mlt35x25_dsp48e1.v
//    >. mlt35x27_dsp48e2.v
//
//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
//
//  GNU GENERAL PUBLIC LICENSE
//  Version 3, 29 June 2007
//
//  Copyright (c) 2018 Kapitanov Alexander
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//
//  THERE IS NO WARRANTY FOR THE PROGRAM, TO THE EXTENT PERMITTED BY
//  APPLICABLE LAW. EXCEPT WHEN OTHERWISE STATED IN WRITING THE COPYRIGHT 
//  HOLDERS AND/OR OTHER PARTIES PROVIDE THE PROGRAM "AS IS" WITHOUT WARRANTY 
//  OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, 
//  THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR 
//  PURPOSE.  THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE PROGRAM 
//  IS WITH YOU.  SHOULD THE PROGRAM PROVE DEFECTIVE, YOU ASSUME THE COST OF 
//  ALL NECESSARY SERVICING, REPAIR OR CORRECTION. 
// 
//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------

module int_cmult_dbl35_dsp48
	#(
		parameter
		MAW	 = 35,
		MBW	 = 25,
		XSER = "OLD",
		XALU = 4'b0000
	)
	(
		input CLK, RST,
		
		input [MAW-1 : 0] M1_AA, M2_AA,
		input [MBW-1 : 0] M1_BB, M2_BB,
		output signed [MAW-1 : 0] MP_12
	);

	// ---------------- Calculate Data Width --------
	localparam integer BWD = (XSER == "NEW") ? 27 : 25;
	localparam integer PWD = (XSER == "NEW") ? 62 : 60;

	// ---- DSP48 signal declaration ----
	wire [34 : 0] dspA_M1, dspA_M2;
	wire [BWD-1 : 0] dspB_M1, dspB_M2;

	wire [PWD-1 : 0] dspP_M1, dspP_M2;

	wire [47 : 0] dsp1_48, dsp2_48;

	wire [29 : 0] dspA_12;
	wire [17 : 0] dspB_12;
	wire [47 : 0] dspC_12, dspP_12;
	
	// ---- Wrap input data ----
	assign dspB_M1 = { {(BWD-MBW){M1_BB[MBW-1]}}, M1_BB[MBW-1 : 0] };
	assign dspB_M2 = { {(BWD-MBW){M2_BB[MBW-1]}}, M2_BB[MBW-1 : 0] };
	assign dspA_M1 = { {(35-MAW){M1_AA[MAW-1]}}, M1_AA[MAW-1 : 0] };
	assign dspA_M2 = { {(35-MAW){M2_AA[MAW-1]}}, M2_AA[MAW-1 : 0] };

	// ---- Min value MBW = 19! ----
	assign dsp1_48 = dspP_M1[PWD-1-(BWD-MBW)-1 : PWD-48-(BWD-MBW)-1];
	assign dsp2_48 = dspP_M2[PWD-1-(BWD-MBW)-1 : PWD-48-(BWD-MBW)-1];

	// ---- Output data ----
	assign MP_12 = dspP_12[47-1-(35-MAW) : 47-35];

	assign dspA_12 = dsp1_48[47 : 18];
	assign dspB_12 = dsp1_48[17 : 00];
	assign dspC_12 = dsp2_48;
	
	generate
		// ---- Wrap DSP48E1 units ----
		if (XSER == "OLD") begin
			
			mlt35x25_dsp48e1 xMLT1 (
				.MLT_A(dspA_M1),
				.MLT_B(dspB_M1),
				.MLT_P(dspP_M1),
				.RST(RST),
				.CLK(CLK)
			);
				
			mlt35x25_dsp48e1 xMLT2 (
				.MLT_A(dspA_M1),
				.MLT_B(dspB_M1),
				.MLT_P(dspP_M1),
				.RST(RST),
				.CLK(CLK)
			);	
			
			DSP48E1 #(
				.USE_MULT("NONE"),  
				.ACASCREG(1),
				.ADREG(1),
				.ALUMODEREG(1),
				.AREG(1),
				.BCASCREG(1),
				.BREG(1),
				.CARRYINREG(1),
				.CARRYINSELREG(1),
				.CREG(1),
				.DREG(1),
				.INMODEREG(1),
				.MREG(0),
				.OPMODEREG(1),
				.PREG(1)
			)
			xDSP_ADD (
			   // Cascade: 30-bit (each) input: 
			   .ACIN(30'b0),
			   .BCIN(18'b0),
			   .CARRYCASCIN(1'b0),
			   .MULTSIGNIN(1'b0),
			   .PCIN(dspP_M2),
			   .ALUMODE(XALU),
			   .CARRYINSEL(3'b0),
			   .CLK(CLK),
			   .INMODE(5'b0),
			   .OPMODE(7'b0110011),
			   // Data input / output data ports
			   .A(dspA_12),
			   .B(dspB_12),
			   .C(dspC_12),
			   .P(dspP_12),
			   .D(25'b0),
			   .CARRYIN(1'b0),
			   // Clock enables
			   .CEA1(1'b1),     
			   .CEA2(1'b1),     
			   .CEAD(1'b1),     
			   .CEALUMODE(1'b1),
			   .CEB1(1'b1),     
			   .CEB2(1'b1),     
			   .CEC(1'b1),      
			   .CECARRYIN(1'b1),
			   .CECTRL(1'b1),   
			   .CED(1'b1),      
			   .CEINMODE(1'b1), 
			   .CEM(1'b1),
			   .CEP(1'b1),
			   .RSTA(RST),
			   .RSTALLCARRYIN(RST),   
			   .RSTALUMODE(RST),
			   .RSTB(RST),
			   .RSTC(RST),
			   .RSTCTRL(RST),
			   .RSTD(RST),
			   .RSTINMODE(RST),
			   .RSTM(RST),
			   .RSTP(RST)
			);				
	
		end else begin
		// ---- Wrap DSP48E2 units ----
			mlt35x27_dsp48e2 xMLT1 (
				.MLT_A(dspA_M1),
				.MLT_B(dspB_M1),
				.MLT_P(dspP_M1),
				.RST(RST),
				.CLK(CLK)
			);
				
			mlt35x27_dsp48e2 xMLT2 (
				.MLT_A(dspA_M1),
				.MLT_B(dspB_M1),
				.MLT_P(dspP_M1),
				.RST(RST),
				.CLK(CLK)
			);

			DSP48E2 #(
				.USE_MULT("NONE"),  
				.ACASCREG(1),
				.ADREG(1),
				.ALUMODEREG(1),
				.AREG(1),
				.BCASCREG(1),
				.BREG(1),
				.CARRYINREG(1),
				.CARRYINSELREG(1),
				.CREG(1),
				.DREG(1),
				.INMODEREG(1),
				.MREG(0),
				.OPMODEREG(1),
				.PREG(1)
			)
			xDSP_ADD (
			   // Cascade: 30-bit (each) input: 
			   .ACIN(30'b0),
			   .BCIN(18'b0),
			   .CARRYCASCIN(1'b0),
			   .MULTSIGNIN(1'b0),
			   .PCIN(dspP_M2),
			   .ALUMODE(XALU),
			   .CARRYINSEL(3'b0),
			   .CLK(CLK),
			   .INMODE(5'b0),
			   .OPMODE(9'b000110011),
			   // Data input / output data ports
			   .A(dspA_12),
			   .B(dspB_12),
			   .C(dspC_12),
			   .P(dspP_12),
			   .D(27'b0),
			   .CARRYIN(1'b0),
			   // Clock enables
			   .CEA1(1'b1),     
			   .CEA2(1'b1),     
			   .CEAD(1'b1),     
			   .CEALUMODE(1'b1),
			   .CEB1(1'b1),     
			   .CEB2(1'b1),     
			   .CEC(1'b1),      
			   .CECARRYIN(1'b1),
			   .CECTRL(1'b1),   
			   .CED(1'b1),      
			   .CEINMODE(1'b1), 
			   .CEM(1'b1),
			   .CEP(1'b1),
			   .RSTA(RST),
			   .RSTALLCARRYIN(RST),   
			   .RSTALUMODE(RST),
			   .RSTB(RST),
			   .RSTC(RST),
			   .RSTCTRL(RST),
			   .RSTD(RST),
			   .RSTINMODE(RST),
			   .RSTM(RST),
			   .RSTP(RST)
			);	
		end
	endgenerate	
endmodule