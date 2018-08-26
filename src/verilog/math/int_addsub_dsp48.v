//-----------------------------------------------------------------------------
//
// Title       : int_addsub_dsp48
// Design      : FFTK
// Author      : Kapitanov
// Company     :
//
// Description : Integer adder/subtractor on DSP48 block
//
//-----------------------------------------------------------------------------
//
//	Version 1.0: 12.02.2018
//
//  Description: Simple complex adder/subtractor by DSP48 unit
//
//  Math:
//
//  Out:    In:
//  OX_RE = IA_RE + IB_RE;
//  OX_IM = IA_IM + IB_IM; 
//  OY_RE = IA_RE - IB_RE; 
//  OY_IM = IA_IM - IB_IM; 
//
//	Input variables:
//    1. DSPW - DSP48 input width (from 8 to 48): data width + FFT stage
//    2. XSER - Xilinx series: 
//        "NEW" - DSP48E2 (Ultrascale), 
//        "OLD" - DSP48E1 (6/7-series).
//
//  DSP48 data signals:
//    A port - In B data (MSB part),
//    B port - In B data (LSB part),
//    C port - In A data,
//    P port - Output data: P = C +/- A:B 
//
//  IF (DSPW < 25) 
//    use DSP48 SIMD mode (dual 24-bit) add/subtract
//  ELSE 
//    don't use DSP48 SIMD mode (one 48-bit) add/subtract
//
//  DSP48E1 options:
//  [A:B] and [C] port: - OPMODE: "0110011" (Z = 011, Y = 00, X = 11)
//  Add op: ALUMODE - "0000" Z + Y + X,
//  Sub op: ALUMODE - "0011" Z + Y + X;
//
//  DSP48E2 options:
//  [A:B] and [C] port: - OPMODE: "000110011" (W = 00, Z = 011, Y = 00, X = 11)
//  Add op: ALUMODE - "0000" P = Z + Y + X,
//  Sub op: ALUMODE - "0011" P = Z - Y - X;
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

module int_addsub_dsp48 
	#(
		parameter 
		DATA_WIDTH  = 16,
		XSER  = "OLD"
	)
	(
		input CLK, RST, 
		input  signed [DATA_WIDTH-1 : 0] IA_RE, IA_IM, IB_RE, IB_IM,
		output reg signed [DATA_WIDTH : 0] OX_RE, OX_IM, OY_RE, OY_IM
	);
	
	generate 
		if ((DATA_WIDTH > 23) & (DATA_WIDTH < 48)) begin
			wire [29 : 0] dspA_RE, dspA_IM;
			wire [17 : 0] dspB_RE, dspB_IM;
			wire [47 : 0] dspC_RE, dspC_IM;

			wire [47 : 0] dspX_RE, dspX_IM, dspY_RE, dspY_IM;

			//-- Create A:B 48-bit data ----
			assign dspB_RE = IB_RE[17 : 00];
			assign dspB_IM = IB_IM[17 : 00];
	
			// -- A port 48-bit data ----
			assign dspA_RE = { {(30-DATA_WIDTH){IB_RE[DATA_WIDTH-1]}}, IB_RE[DATA_WIDTH-1 : 0] };
			assign dspA_IM = { {(30-DATA_WIDTH){IB_IM[DATA_WIDTH-1]}}, IB_IM[DATA_WIDTH-1 : 0] };

			assign dspC_RE = { {(48-DATA_WIDTH){IA_RE[DATA_WIDTH-1]}}, IA_RE[DATA_WIDTH-1 : 0] };
			assign dspC_IM = { {(48-DATA_WIDTH){IA_IM[DATA_WIDTH-1]}}, IA_IM[DATA_WIDTH-1 : 0] };
		
			always @(*) begin
				OX_RE = dspX_RE[DATA_WIDTH : 0];
				OX_IM = dspX_IM[DATA_WIDTH : 0];
				OY_RE = dspY_RE[DATA_WIDTH : 0];
				OY_IM = dspY_IM[DATA_WIDTH : 0];
			end
			
            if (XSER == "NEW") begin	
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
                xDSP_REX (                 
                   // Cascade: 30-bit (each) input: 
                   .ACIN(30'b0),
                   .BCIN(18'b0),
                   .CARRYCASCIN(1'b0),
                   .MULTSIGNIN(1'b0),
                   .PCIN(48'b0),
                   .ALUMODE(4'b0),
                   .CARRYINSEL(3'b0),
                   .CLK(CLK),
                   .INMODE(5'b0),
                   .OPMODE(9'b000110011),
                   // Data input / output data ports
                   .A(dspA_RE),
                   .B(dspB_RE),
                   .C(dspC_RE),
                   .P(dspX_RE),
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
                xDSP_IMX (                 
                   // Cascade: 30-bit (each) input: 
                   .ACIN(30'b0),
                   .BCIN(18'b0),
                   .CARRYCASCIN(1'b0),       
                   .MULTSIGNIN(1'b0),         
                   .PCIN(48'b0),
                   .ALUMODE(4'b0),
                   .CARRYINSEL(3'b0),
                   .CLK(CLK),
                   .INMODE(5'b0),
                   .OPMODE(9'b000110011),
                   // Data input / output data ports
                   .A(dspA_IM),
                   .B(dspB_IM),
                   .C(dspC_IM),
                   .P(dspX_IM),
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
                xDSP_REY (                 
                   // Cascade: 30-bit (each) input: 
                   .ACIN(30'b0),
                   .BCIN(18'b0),
                   .CARRYCASCIN(1'b0),
                   .MULTSIGNIN(1'b0),
                   .PCIN(48'b0),
                   .ALUMODE(4'b0011),
                   .CARRYINSEL(3'b0),
                   .CLK(CLK),
                   .INMODE(5'b0),
                   .OPMODE(9'b000110011),
                   // Data input / output data ports
                   .A(dspA_RE),
                   .B(dspB_RE),
                   .C(dspC_RE),
                   .P(dspY_RE),
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
                xDSP_IMY (                 
                   // Cascade: 30-bit (each) input: 
                   .ACIN(30'b0),
                   .BCIN(18'b0),
                   .CARRYCASCIN(1'b0),       
                   .MULTSIGNIN(1'b0),         
                   .PCIN(48'b0),
                   .ALUMODE(4'b0011),
                   .CARRYINSEL(3'b0),
                   .CLK(CLK),
                   .INMODE(5'b0),
                   .OPMODE(9'b000110011),
                   // Data input / output data ports
                   .A(dspA_IM),
                   .B(dspB_IM),
                   .C(dspC_IM),
                   .P(dspY_IM),
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
            end else begin
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
                xDSP_REX (                 
                   // Cascade: 30-bit (each) input: 
                   .ACIN(30'b0),
                   .BCIN(18'b0),
                   .CARRYCASCIN(1'b0),
                   .MULTSIGNIN(1'b0),
                   .PCIN(48'b0),
                   .ALUMODE(4'b0),
                   .CARRYINSEL(3'b0),
                   .CLK(CLK),
                   .INMODE(5'b0),
                   .OPMODE(7'b0110011),
                   // Data input / output data ports
                   .A(dspA_RE),
                   .B(dspB_RE),
                   .C(dspC_RE),
                   .P(dspX_RE),
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
                xDSP_IMX (                 
                   // Cascade: 30-bit (each) input: 
                   .ACIN(30'b0),
                   .BCIN(18'b0),
                   .CARRYCASCIN(1'b0),       
                   .MULTSIGNIN(1'b0),         
                   .PCIN(48'b0),
                   .ALUMODE(4'b0),
                   .CARRYINSEL(3'b0),
                   .CLK(CLK),
                   .INMODE(5'b0),
                   .OPMODE(7'b0110011),
                   // Data input / output data ports
                   .A(dspA_IM),
                   .B(dspB_IM),
                   .C(dspC_IM),
                   .P(dspX_IM),
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
                xDSP_REY (                 
                   // Cascade: 30-bit (each) input: 
                   .ACIN(30'b0),
                   .BCIN(18'b0),
                   .CARRYCASCIN(1'b0),
                   .MULTSIGNIN(1'b0),
                   .PCIN(48'b0),
                   .ALUMODE(4'b0011),
                   .CARRYINSEL(3'b0),
                   .CLK(CLK),
                   .INMODE(5'b0),
                   .OPMODE(7'b0110011),
                   // Data input / output data ports
                   .A(dspA_RE),
                   .B(dspB_RE),
                   .C(dspC_RE),
                   .P(dspY_RE),
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
                xDSP_IMY (                 
                   // Cascade: 30-bit (each) input: 
                   .ACIN(30'b0),
                   .BCIN(18'b0),
                   .CARRYCASCIN(1'b0),       
                   .MULTSIGNIN(1'b0),         
                   .PCIN(48'b0),
                   .ALUMODE(4'b0011),
                   .CARRYINSEL(3'b0),
                   .CLK(CLK),
                   .INMODE(5'b0),
                   .OPMODE(7'b0110011),
                   // Data input / output data ports
                   .A(dspA_IM),
                   .B(dspB_IM),
                   .C(dspC_IM),
                   .P(dspY_IM),
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
            end
		end 
		else if (DATA_WIDTH < 24) begin

			wire [29 : 0] dspA_XY;
			wire [17 : 0] dspB_XY;
			wire [47 : 0] dspAB, dspC_XY, dspP_XX, dspP_YY;

			//-- Create A:B 48-bit data ----
			assign dspC_XY = { {(24-DATA_WIDTH){IA_IM[DATA_WIDTH-1]}}, IA_IM, {(24-DATA_WIDTH){IA_RE[DATA_WIDTH-1]}}, IA_RE };
			assign dspAB   = { {(24-DATA_WIDTH){IB_IM[DATA_WIDTH-1]}}, IB_IM, {(24-DATA_WIDTH){IB_RE[DATA_WIDTH-1]}}, IB_RE };
			assign dspA_XY = dspAB[47 : 18];
			assign dspB_XY = dspAB[17 : 00];
	       
            always @(*) begin
                OX_RE = dspP_XX[DATA_WIDTH : 00];
                OY_RE = dspP_YY[DATA_WIDTH : 00];
                OX_IM = dspP_XX[DATA_WIDTH+24 : 24];
                OY_IM = dspP_YY[DATA_WIDTH+24 : 24];
            end
            if (XSER == "NEW") begin	
                DSP48E2 #(
                    .USE_MULT("NONE"),  
                    .USE_SIMD("TWO24"),  
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
                xDSP_X (                 
                   // Cascade: 30-bit (each) input: 
                   .ACIN(30'b0),
                   .BCIN(18'b0),
                   .CARRYCASCIN(1'b0),
                   .MULTSIGNIN(1'b0),
                   .PCIN(48'b0),
                   .ALUMODE(4'b0),
                   .CARRYINSEL(3'b0),
                   .CLK(CLK),
                   .INMODE(5'b0),
                   .OPMODE(9'b000110011),
                   // Data input / output data ports
                   .A(dspA_XY),
                   .B(dspB_XY),
                   .C(dspC_XY),
                   .P(dspP_XX),
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

                DSP48E2 #(
                    .USE_MULT("NONE"),  
                    .USE_SIMD("TWO24"),  
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
                xDSP_Y (                 
                   // Cascade: 30-bit (each) input: 
                   .ACIN(30'b0),
                   .BCIN(18'b0),
                   .CARRYCASCIN(1'b0),       
                   .MULTSIGNIN(1'b0),         
                   .PCIN(48'b0),
                   .ALUMODE(4'b0011),
                   .CARRYINSEL(3'b0),
                   .CLK(CLK),
                   .INMODE(5'b0),
                   .OPMODE(9'b000110011),
                   // Data input / output data ports
                   .A(dspA_XY),
                   .B(dspB_XY),
                   .C(dspC_XY),
                   .P(dspP_YY),
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
            end else begin
                DSP48E1 #(
                    .USE_MULT("NONE"),  
                    .USE_SIMD("TWO24"),  
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
                xDSP_X (                 
                   // Cascade: 30-bit (each) input: 
                   .ACIN(30'b0),
                   .BCIN(18'b0),
                   .CARRYCASCIN(1'b0),
                   .MULTSIGNIN(1'b0),
                   .PCIN(48'b0),
                   .ALUMODE(4'b0),
                   .CARRYINSEL(3'b0),
                   .CLK(CLK),
                   .INMODE(5'b0),
                   .OPMODE(7'b0110011),
                   // Data input / output data ports
                   .A(dspA_XY),
                   .B(dspB_XY),
                   .C(dspC_XY),
                   .P(dspP_XX),
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

                DSP48E1 #(
                    .USE_MULT("NONE"),  
                    .USE_SIMD("TWO24"),  
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
                xDSP_Y (                 
                   // Cascade: 30-bit (each) input: 
                   .ACIN(30'b0),
                   .BCIN(18'b0),
                   .CARRYCASCIN(1'b0),       
                   .MULTSIGNIN(1'b0),         
                   .PCIN(48'b0),
                   .ALUMODE(4'b0011),
                   .CARRYINSEL(3'b0),
                   .CLK(CLK),
                   .INMODE(5'b0),
                   .OPMODE(7'b0110011),
                   // Data input / output data ports
                   .A(dspA_XY),
                   .B(dspB_XY),
                   .C(dspC_XY),
                   .P(dspP_YY),
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
            end
		end 
		else if (DATA_WIDTH > 47) begin
			
			wire [29 : 0] dspA_RE1, dspA_RE2, dspA_IM1, dspA_IM2;
			wire [17 : 0] dspB_RE1, dspB_RE2, dspB_IM1, dspB_IM2;
			wire [47 : 0] dspC_RE1, dspC_IM1;
			reg  [47 : 0] dspC_RE2, dspC_IM2;
			
			wire [47 : 0] dspX_RE1, dspY_RE1, dspX_IM1, dspY_IM1;
			wire [47 : 0] dspX_RE2, dspY_RE2, dspX_IM2, dspY_IM2;
			
			wire [95 : 0] dspA_RE, dspA_IM, dspB_RE, dspB_IM;
			
			wire dspC_XR, dspC_XI, dspC_YR, dspC_YI;
		
			// -- port 48-bit data ----
			assign dspA_RE = { {(96-DATA_WIDTH){IA_RE[DATA_WIDTH-1]}}, IA_RE[DATA_WIDTH-1 : 0] };
			assign dspA_IM = { {(96-DATA_WIDTH){IA_IM[DATA_WIDTH-1]}}, IA_IM[DATA_WIDTH-1 : 0] };
			assign dspB_RE = { {(96-DATA_WIDTH){IB_RE[DATA_WIDTH-1]}}, IB_RE[DATA_WIDTH-1 : 0] };
			assign dspB_IM = { {(96-DATA_WIDTH){IB_IM[DATA_WIDTH-1]}}, IB_IM[DATA_WIDTH-1 : 0] };

			assign dspB_RE1 = dspB_RE[17 : 00];
			assign dspB_IM1 = dspB_IM[17 : 00];
			assign dspA_RE1 = dspB_RE[47 : 18];
			assign dspA_IM1 = dspB_IM[47 : 18];

			assign dspB_RE2 = dspB_RE[65 : 48];
			assign dspB_IM2 = dspB_IM[65 : 48];
			assign dspA_RE2 = dspB_RE[95 : 66];
			assign dspA_IM2 = dspB_IM[95 : 66];
			
			assign dspC_RE1 = dspA_RE[47 : 0];
			assign dspC_IM1 = dspA_IM[47 : 0];
			
			always @(posedge CLK) begin
				dspC_RE2 <= dspA_RE[95 : 48];
				dspC_IM2 <= dspA_IM[95 : 48];
			end

			always @(posedge CLK) begin
				OX_RE[47 : 0] <= dspX_RE1;
				OX_IM[47 : 0] <= dspX_IM1;
				OY_RE[47 : 0] <= dspY_RE1;
				OY_IM[47 : 0] <= dspY_IM1;
			end			
			always @(*) begin
				OX_RE[DATA_WIDTH : 48] = dspX_RE2[DATA_WIDTH-48 : 0];
				OX_IM[DATA_WIDTH : 48] = dspX_IM2[DATA_WIDTH-48 : 0];
				OY_RE[DATA_WIDTH : 48] = dspY_RE2[DATA_WIDTH-48 : 0];
				OY_IM[DATA_WIDTH : 48] = dspY_IM2[DATA_WIDTH-48 : 0];
			end	

            if (XSER == "NEW") begin	
                DSP48E2 #(
                    .USE_MULT("NONE"),  
                    .ACASCREG(1),
                    .ADREG(1),
                    .ALUMODEREG(1),
                    .AREG(2),
                    .BCASCREG(1),
                    .BREG(2),
                    .CARRYINREG(1),
                    .CARRYINSELREG(1),
                    .CREG(1),
                    .DREG(1),
                    .INMODEREG(1),
                    .MREG(0),
                    .OPMODEREG(1),
                    .PREG(1)
                )
                xDSP_REX2 (                 
                   // Cascade: 30-bit (each) input: 
                   .ACIN(30'b0),
                   .BCIN(18'b0),
                   .CARRYCASCIN(dspC_XR),
                   .MULTSIGNIN(1'b0),
                   .PCIN(48'b0),
                   .ALUMODE(4'b0),
                   .CARRYINSEL(3'b010),
                   .CLK(CLK),
                   .INMODE(5'b0),
                   .OPMODE(9'b000110011),
                   // Data input / output data ports
                   .A(dspA_RE2),
                   .B(dspB_RE2),
                   .C(dspC_RE2),
                   .P(dspX_RE2),
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
                xDSP_REX1 (                 
                   // Cascade: 30-bit (each) input: 
                   .ACIN(30'b0),
                   .BCIN(18'b0),
                   .CARRYCASCIN(1'b0),
                   .MULTSIGNIN(1'b0),
                   .PCIN(48'b0),
                   .ALUMODE(4'b0),
                   .CARRYINSEL(3'b0),
                   .CLK(CLK),
                   .INMODE(5'b0),
                   .OPMODE(9'b000110011),
                   // Data input / output data ports
                   .A(dspA_RE1),
                   .B(dspB_RE1),
                   .C(dspC_RE1),
                   .P(dspX_RE1),
                   .D(27'b0),
                   .CARRYIN(1'b0),
                   .CARRYCASCOUT(dspC_XR),
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

                DSP48E2 #(
                    .USE_MULT("NONE"),  
                    .ACASCREG(1),
                    .ADREG(1),
                    .ALUMODEREG(1),
                    .AREG(2),
                    .BCASCREG(1),
                    .BREG(2),
                    .CARRYINREG(1),
                    .CARRYINSELREG(1),
                    .CREG(1),
                    .DREG(1),
                    .INMODEREG(1),
                    .MREG(0),
                    .OPMODEREG(1),
                    .PREG(1)
                )
                xDSP_IMX2 (                 
                   // Cascade: 30-bit (each) input: 
                   .ACIN(30'b0),
                   .BCIN(18'b0),
                   .CARRYCASCIN(dspC_XI),
                   .MULTSIGNIN(1'b0),
                   .PCIN(48'b0),
                   .ALUMODE(4'b0),
                   .CARRYINSEL(3'b010),
                   .CLK(CLK),
                   .INMODE(5'b0),
                   .OPMODE(9'b000110011),
                   // Data input / output data ports
                   .A(dspA_IM2),
                   .B(dspB_IM2),
                   .C(dspC_IM2),
                   .P(dspX_IM2),
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
                xDSP_IMX1 (                 
                   // Cascade: 30-bit (each) input: 
                   .ACIN(30'b0),
                   .BCIN(18'b0),
                   .CARRYCASCIN(1'b0),
                   .MULTSIGNIN(1'b0),
                   .PCIN(48'b0),
                   .ALUMODE(4'b0),
                   .CARRYINSEL(3'b0),
                   .CLK(CLK),
                   .INMODE(5'b0),
                   .OPMODE(9'b000110011),
                   // Data input / output data ports
                   .A(dspA_IM1),
                   .B(dspB_IM1),
                   .C(dspC_IM1),
                   .P(dspX_IM1),
                   .D(27'b0),
                   .CARRYIN(1'b0),
                   .CARRYCASCOUT(dspC_XI),
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

                DSP48E2 #(
                    .USE_MULT("NONE"),  
                    .ACASCREG(1),
                    .ADREG(1),
                    .ALUMODEREG(1),
                    .AREG(2),
                    .BCASCREG(1),
                    .BREG(2),
                    .CARRYINREG(1),
                    .CARRYINSELREG(1),
                    .CREG(1),
                    .DREG(1),
                    .INMODEREG(1),
                    .MREG(0),
                    .OPMODEREG(1),
                    .PREG(1)
                )
                xDSP_REY2 (                 
                   // Cascade: 30-bit (each) input: 
                   .ACIN(30'b0),
                   .BCIN(18'b0),
                   .CARRYCASCIN(dspC_YR),
                   .MULTSIGNIN(1'b0),
                   .PCIN(48'b0),
                   .ALUMODE(4'b0011),
                   .CARRYINSEL(3'b010),
                   .CLK(CLK),
                   .INMODE(5'b0),
                   .OPMODE(9'b000110011),
                   // Data input / output data ports
                   .A(dspA_RE2),
                   .B(dspB_RE2),
                   .C(dspC_RE2),
                   .P(dspY_RE2),
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
                xDSP_REY1 (                 
                   // Cascade: 30-bit (each) input: 
                   .ACIN(30'b0),
                   .BCIN(18'b0),
                   .CARRYCASCIN(1'b0),
                   .MULTSIGNIN(1'b0),
                   .PCIN(48'b0),
                   .ALUMODE(4'b0011),
                   .CARRYINSEL(3'b0),
                   .CLK(CLK),
                   .INMODE(5'b0),
                   .OPMODE(9'b000110011),
                   // Data input / output data ports
                   .A(dspA_RE1),
                   .B(dspB_RE1),
                   .C(dspC_RE1),
                   .P(dspY_RE1),
                   .D(27'b0),
                   .CARRYIN(1'b0),
                   .CARRYCASCOUT(dspC_YR),
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

                DSP48E2 #(
                    .USE_MULT("NONE"),  
                    .ACASCREG(1),
                    .ADREG(1),
                    .ALUMODEREG(1),
                    .AREG(2),
                    .BCASCREG(1),
                    .BREG(2),
                    .CARRYINREG(1),
                    .CARRYINSELREG(1),
                    .CREG(1),
                    .DREG(1),
                    .INMODEREG(1),
                    .MREG(0),
                    .OPMODEREG(1),
                    .PREG(1)
                )
                xDSP_IMY2 (                 
                   // Cascade: 30-bit (each) input: 
                   .ACIN(30'b0),
                   .BCIN(18'b0),
                   .CARRYCASCIN(dspC_YI),
                   .MULTSIGNIN(1'b0),
                   .PCIN(48'b0),
                   .ALUMODE(4'b0011),
                   .CARRYINSEL(3'b010),
                   .CLK(CLK),
                   .INMODE(5'b0),
                   .OPMODE(9'b000110011),
                   // Data input / output data ports
                   .A(dspA_IM2),
                   .B(dspB_IM2),
                   .C(dspC_IM2),
                   .P(dspY_IM2),
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
                xDSP_IMY1 (                 
                   // Cascade: 30-bit (each) input: 
                   .ACIN(30'b0),
                   .BCIN(18'b0),
                   .CARRYCASCIN(1'b0),
                   .MULTSIGNIN(1'b0),
                   .PCIN(48'b0),
                   .ALUMODE(4'b0011),
                   .CARRYINSEL(3'b0),
                   .CLK(CLK),
                   .INMODE(5'b0),
                   .OPMODE(9'b000110011),
                   // Data input / output data ports
                   .A(dspA_IM1),
                   .B(dspB_IM1),
                   .C(dspC_IM1),
                   .P(dspY_IM1),
                   .D(27'b0),
                   .CARRYIN(1'b0),
                   .CARRYCASCOUT(dspC_YI),
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
                DSP48E1 #(
                    .USE_MULT("NONE"),  
                    .ACASCREG(1),
                    .ADREG(1),
                    .ALUMODEREG(1),
                    .AREG(2),
                    .BCASCREG(1),
                    .BREG(2),
                    .CARRYINREG(1),
                    .CARRYINSELREG(1),
                    .CREG(1),
                    .DREG(1),
                    .INMODEREG(1),
                    .MREG(0),
                    .OPMODEREG(1),
                    .PREG(1)
                )
                xDSP_REX2 (                 
                   // Cascade: 30-bit (each) input: 
                   .ACIN(30'b0),
                   .BCIN(18'b0),
                   .CARRYCASCIN(dspC_XR),
                   .MULTSIGNIN(1'b0),
                   .PCIN(48'b0),
                   .ALUMODE(4'b0),
                   .CARRYINSEL(3'b010),
                   .CLK(CLK),
                   .INMODE(5'b0),
                   .OPMODE(7'b0110011),
                   // Data input / output data ports
                   .A(dspA_RE2),
                   .B(dspB_RE2),
                   .C(dspC_RE2),
                   .P(dspX_RE2),
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
                xDSP_REX1 (                 
                   // Cascade: 30-bit (each) input: 
                   .ACIN(30'b0),
                   .BCIN(18'b0),
                   .CARRYCASCIN(1'b0),
                   .MULTSIGNIN(1'b0),
                   .PCIN(48'b0),
                   .ALUMODE(4'b0),
                   .CARRYINSEL(3'b0),
                   .CLK(CLK),
                   .INMODE(5'b0),
                   .OPMODE(7'b0110011),
                   // Data input / output data ports
                   .A(dspA_RE1),
                   .B(dspB_RE1),
                   .C(dspC_RE1),
                   .P(dspX_RE1),
                   .D(25'b0),
                   .CARRYIN(1'b0),
                   .CARRYCASCOUT(dspC_XR),
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

                DSP48E1 #(
                    .USE_MULT("NONE"),  
                    .ACASCREG(1),
                    .ADREG(1),
                    .ALUMODEREG(1),
                    .AREG(2),
                    .BCASCREG(1),
                    .BREG(2),
                    .CARRYINREG(1),
                    .CARRYINSELREG(1),
                    .CREG(1),
                    .DREG(1),
                    .INMODEREG(1),
                    .MREG(0),
                    .OPMODEREG(1),
                    .PREG(1)
                )
                xDSP_IMX2 (                 
                   // Cascade: 30-bit (each) input: 
                   .ACIN(30'b0),
                   .BCIN(18'b0),
                   .CARRYCASCIN(dspC_XI),
                   .MULTSIGNIN(1'b0),
                   .PCIN(48'b0),
                   .ALUMODE(4'b0),
                   .CARRYINSEL(3'b010),
                   .CLK(CLK),
                   .INMODE(5'b0),
                   .OPMODE(7'b0110011),
                   // Data input / output data ports
                   .A(dspA_IM2),
                   .B(dspB_IM2),
                   .C(dspC_IM2),
                   .P(dspX_IM2),
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
                xDSP_IMX1 (                 
                   // Cascade: 30-bit (each) input: 
                   .ACIN(30'b0),
                   .BCIN(18'b0),
                   .CARRYCASCIN(1'b0),
                   .MULTSIGNIN(1'b0),
                   .PCIN(48'b0),
                   .ALUMODE(4'b0),
                   .CARRYINSEL(3'b0),
                   .CLK(CLK),
                   .INMODE(5'b0),
                   .OPMODE(7'b0110011),
                   // Data input / output data ports
                   .A(dspA_IM1),
                   .B(dspB_IM1),
                   .C(dspC_IM1),
                   .P(dspX_IM1),
                   .D(25'b0),
                   .CARRYIN(1'b0),
                   .CARRYCASCOUT(dspC_XI),
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

                DSP48E1 #(
                    .USE_MULT("NONE"),  
                    .ACASCREG(1),
                    .ADREG(1),
                    .ALUMODEREG(1),
                    .AREG(2),
                    .BCASCREG(1),
                    .BREG(2),
                    .CARRYINREG(1),
                    .CARRYINSELREG(1),
                    .CREG(1),
                    .DREG(1),
                    .INMODEREG(1),
                    .MREG(0),
                    .OPMODEREG(1),
                    .PREG(1)
                )
                xDSP_REY2 (                 
                   // Cascade: 30-bit (each) input: 
                   .ACIN(30'b0),
                   .BCIN(18'b0),
                   .CARRYCASCIN(dspC_YR),
                   .MULTSIGNIN(1'b0),
                   .PCIN(48'b0),
                   .ALUMODE(4'b0011),
                   .CARRYINSEL(3'b010),
                   .CLK(CLK),
                   .INMODE(5'b0),
                   .OPMODE(7'b0110011),
                   // Data input / output data ports
                   .A(dspA_RE2),
                   .B(dspB_RE2),
                   .C(dspC_RE2),
                   .P(dspY_RE2),
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
                xDSP_REY1 (                 
                   // Cascade: 30-bit (each) input: 
                   .ACIN(30'b0),
                   .BCIN(18'b0),
                   .CARRYCASCIN(1'b0),
                   .MULTSIGNIN(1'b0),
                   .PCIN(48'b0),
                   .ALUMODE(4'b0011),
                   .CARRYINSEL(3'b0),
                   .CLK(CLK),
                   .INMODE(5'b0),
                   .OPMODE(7'b0110011),
                   // Data input / output data ports
                   .A(dspA_RE1),
                   .B(dspB_RE1),
                   .C(dspC_RE1),
                   .P(dspY_RE1),
                   .D(25'b0),
                   .CARRYIN(1'b0),
                   .CARRYCASCOUT(dspC_YR),
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

                DSP48E1 #(
                    .USE_MULT("NONE"),  
                    .ACASCREG(1),
                    .ADREG(1),
                    .ALUMODEREG(1),
                    .AREG(2),
                    .BCASCREG(1),
                    .BREG(2),
                    .CARRYINREG(1),
                    .CARRYINSELREG(1),
                    .CREG(1),
                    .DREG(1),
                    .INMODEREG(1),
                    .MREG(0),
                    .OPMODEREG(1),
                    .PREG(1)
                )
                xDSP_IMY2 (                 
                   // Cascade: 30-bit (each) input: 
                   .ACIN(30'b0),
                   .BCIN(18'b0),
                   .CARRYCASCIN(dspC_YI),
                   .MULTSIGNIN(1'b0),
                   .PCIN(48'b0),
                   .ALUMODE(4'b0011),
                   .CARRYINSEL(3'b010),
                   .CLK(CLK),
                   .INMODE(5'b0),
                   .OPMODE(7'b0110011),
                   // Data input / output data ports
                   .A(dspA_IM2),
                   .B(dspB_IM2),
                   .C(dspC_IM2),
                   .P(dspY_IM2),
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
                xDSP_IMY1 (                 
                   // Cascade: 30-bit (each) input: 
                   .ACIN(30'b0),
                   .BCIN(18'b0),
                   .CARRYCASCIN(1'b0),
                   .MULTSIGNIN(1'b0),
                   .PCIN(48'b0),
                   .ALUMODE(4'b0011),
                   .CARRYINSEL(3'b0),
                   .CLK(CLK),
                   .INMODE(5'b0),
                   .OPMODE(7'b0110011),
                   // Data input / output data ports
                   .A(dspA_IM1),
                   .B(dspB_IM1),
                   .C(dspC_IM1),
                   .P(dspY_IM1),
                   .D(25'b0),
                   .CARRYIN(1'b0),
                   .CARRYCASCOUT(dspC_YI),
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
		end
	endgenerate
endmodule