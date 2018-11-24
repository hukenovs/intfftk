//-----------------------------------------------------------------------------
//
// Title       : int_cmult18x25_dsp48
// Design      : FFTK
// Author      : Kapitanov
// Company     :
//
// Description : Integer complex multiplier on DSP48 block
//
//-----------------------------------------------------------------------------
//
//    Version 1.0: 13.02.2018
//
//  Description: Simple complex multiplier by DSP48 unit
//
//  Math:
//
//  Out:    In:
//  1. MP_12 = M2_AA * M2_BB + M1_AA * M1_BB; (ALUMODE = "0000")
//  2. MP_12 = M2_AA * M2_BB - M1_AA * M1_BB; (ALUMODE = "0011")
//
//    Input variables:
//    1. MAW - Input data width for A ports
//    2. MBW - Input data width for B ports
//    3. XSER - Xilinx series: 
//        "NEW" - DSP48E2 (Ultrascale), 
//        "OLD" - DSP48E1 (6/7-series).
//    4. XALU - ALU MODE: 
//        "ADD" - adder
//        "SUB" - subtractor
//
//  DSP48 data signals:
//    A port - data width up to 25 (27) bits
//    B port - data width up to 18 bits
//
//  Total delay      : 4 clock cycles
//  Total resources  : 2 DSP48 units
//
//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
//
//    GNU GENERAL PUBLIC LICENSE
//  Version 3, 29 June 2007
//
//    Copyright (c) 2018 Kapitanov Alexander
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


module int_cmult18x25_dsp48
    #(
        parameter 
        MAW  = 24,
        MBW  = 17,
        ALUMODE = 4'b0000,
        XSER  = "OLD"
    )
    (
        input CLK, RST,
        
        input  signed [MAW-1 : 0] M1_AA, M2_AA,
        input  signed [MBW-1 : 0] M1_BB, M2_BB,
        output signed [47 : 0] MP_12
    );

    wire [29 : 0] dspA_M1, dspA_M2;
    wire [17 : 0] dspB_M1, dspB_M2;

    reg [47 : 0] dspP_M1, dspP_M2;

    // ---- Wrap input data ----
    assign dspB_M1 = { {(18-MBW){M1_BB[MBW-1]}}, M1_BB[MBW-1 : 0] };
    assign dspB_M2 = { {(18-MBW){M2_BB[MBW-1]}}, M2_BB[MBW-1 : 0] };
    assign dspA_M1 = { {(30-MAW){M1_AA[MAW-1]}}, M1_AA[MAW-1 : 0] };
    assign dspA_M2 = { {(30-MAW){M2_AA[MAW-1]}}, M2_AA[MAW-1 : 0] };
    
    // ---- Output data ----
    assign MP_12 = dspP_M1;
    
    generate 
        if (XSER == "OLD") begin
            // Wrap DSP48E1 unit
            DSP48E1 #(
                .USE_MULT("MULTIPLY"),
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
                .MREG(1),
                .OPMODEREG(1),
                .PREG(1)
            )
            xDSP_M1 (
               // Cascade: 30-bit (each) input: 
               .ACIN(30'b0),    
               .BCIN(18'b0),    
               .CARRYCASCIN(1'b0),
               .MULTSIGNIN(1'b0),
               .PCIN(dspP_M2),
               .ALUMODE(ALUMODE),
               .CARRYINSEL(3'b0),
               .CLK(CLK),
               .INMODE(5'b0),
               .OPMODE(7'b0010101),
               // Data input / output data ports
               .A(dspA_M1),
               .B(dspB_M1),
               .C(48'b0),
               .P(dspP_M1),
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
            
        // Wrap DSP48E1 unit
            DSP48E1 #(
                .USE_MULT("MULTIPLY"),
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
                .MREG(1),
                .OPMODEREG(1),
                .PREG(1)
            )
            xDSP_M2 (
               // Cascade: 30-bit (each) input: 
               .ACIN(30'b0),
               .BCIN(18'b0),
               .CARRYCASCIN(1'b0),
               .MULTSIGNIN(1'b0),
               .PCIN(dspP_M2),
               .ALUMODE(ALUMODE),
               .CARRYINSEL(3'b0),
               .CLK(CLK),
               .INMODE(5'b0),
               .OPMODE(7'b0000101),
               // Data input / output data ports
               .A(dspA_M2),
               .B(dspB_M2),
               .C(48'b0),
               .PCOUT(dspP_M2),
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
            // Wrap DSP48E2 unit
            DSP48E2 #(
                .USE_MULT("MULTIPLY"),
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
                .MREG(1),
                .OPMODEREG(1),
                .PREG(1)
            )
            xDSP_M1 (
               // Cascade: 30-bit (each) input: 
               .ACIN(30'b0),    
               .BCIN(18'b0),    
               .CARRYCASCIN(1'b0),
               .MULTSIGNIN(1'b0),
               .PCIN(dspP_M2),
               .ALUMODE(ALUMODE),
               .CARRYINSEL(3'b0),
               .CLK(CLK),
               .INMODE(5'b0),
               .OPMODE(9'b000010101),
               // Data input / output data ports
               .A(dspA_M1),
               .B(dspB_M1),
               .C(48'b0),
               .P(dspP_M1),
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
            
        // Wrap DSP48E2 unit
            DSP48E2 #(
                .USE_MULT("MULTIPLY"),
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
                .MREG(1),
                .OPMODEREG(1),
                .PREG(1)
            )
            xDSP_M2 (
               // Cascade: 30-bit (each) input: 
               .ACIN(30'b0),    
               .BCIN(18'b0),    
               .CARRYCASCIN(1'b0),
               .MULTSIGNIN(1'b0),
               .PCIN(dspP_M2),
               .ALUMODE(ALUMODE),
               .CARRYINSEL(3'b0),
               .CLK(CLK),
               .INMODE(5'b0),
               .OPMODE(9'b000000101),
               // Data input / output data ports
               .A(dspA_M2),
               .B(dspB_M2),
               .C(48'b0),
               .PCOUT(dspP_M2),
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