//-----------------------------------------------------------------------------
//
// Title       : int_cmult_dsp48
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
//  DO_RE = DI_RE * WW_RE - DI_IM * WW_IM;
//  DO_IM = DI_RE * WW_IM + DI_IM * WW_RE;
//
//    Input variables:
//    1. DTW - DSP48 input width (from 8 to 48): data width + FFT stage
//    2. TWD - DSP48 input width (from 8 to 24): data width + FFT stage
//    3. XSER - Xilinx series: 
//        "NEW" - DSP48E2 (Ultrascale), 
//        "OLD" - DSP48E1 (6/7-series).
//
//  DSP48 data signals:
//    A port - In B data (MSB part),
//    B port - In B data (LSB part),
//    C port - In A data,
//    P port - Output data: P = C +/- A*B 
//
//  IF (TWD < 19)
//      IF (DTW < 26) and (DTW < 18)
//          use single DSP48 for mult operation*
//      ELSE IF (DTW > 25) and (DTW < 43) 
//          use double DSP48 for mult operation**
//      ELSE
//          use triple DSP48 for mult operation
//
//  IF (TWD > 18) and (TWD < 26)
//      IF (DTW < 19)
//          use single DSP48 for mult operation
//      ELSE IF (DTW > 18) and (DTW < 34) 
//          use double DSP48 for mult operation***
//      ELSE
//          use triple DSP48 for mult operation
//
// *   - 25 bit for DSP48E1, 27 bit for DSP48E2,
// **  - 43 bit for DSP48E1, 45 bit for DSP48E2,
// *** - 34 bit for DSP48E1, 35 bit for DSP48E2;
//
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

module int_cmult_dsp48
    #(
        parameter
        DTW  = 52,
        TWD  = 25,
        XSER = "OLD"
    )
    (
        input CLK, RST,
        
        input [DTW-1 : 0] DI_RE, DI_IM,
        input [TWD-1 : 0] WW_RE, WW_IM,
        output signed [DTW-1 : 0] DO_RE, DO_IM
    );

    // ---------------- Calculate Data Width --------
    localparam integer DTW18_SNGL = (XSER == "NEW") ? 28 : 26;
    localparam integer DTW18_DBL  = (XSER == "NEW") ? 45 : 43;    
    localparam integer DTW18_TRPL = (XSER == "NEW") ? 79 : 77;    
    
    localparam integer TWD_DSP = (XSER == "NEW") ? 28 : 26;    

    wire [DTW-1 : 0] D_RE, D_IM;

    assign DO_RE = D_RE;
    assign DO_IM = D_IM;

    // ---- Twiddle factor width less than 19 ----
    generate
        if (TWD < 19) begin : xTWDL18

            // ---- Data width from 8 to 25/27 ----
            if (DTW < DTW18_SNGL) begin : xSNGL_DSP
                wire [47 : 0] P_RE, P_IM;
    
                assign D_RE = P_RE[DTW+TWD-2 : TWD-1];
                assign D_IM = P_IM[DTW+TWD-2 : TWD-1];
        
                int_cmult18x25_dsp48 #( .MAW(DTW), .MBW(TWD), .XALU(4'b0011), .XSER(XSER))
                xMDSP_RE ( .M1_AA(DI_IM), .M1_BB(WW_IM), .M2_AA(DI_RE), .M2_BB(WW_RE), .MP_12(P_RE), .RST(RST), .CLK(CLK) );
                
                int_cmult18x25_dsp48 #( .MAW(DTW), .MBW(TWD), .XALU(4'b0000), .XSER(XSER))
                xMDSP_IM ( .M1_AA(DI_IM), .M1_BB(WW_RE), .M2_AA(DI_RE), .M2_BB(WW_IM), .MP_12(P_IM), .RST(RST), .CLK(CLK) );
            
            // ---- Data width from 25/27 to 42/44 ----
            end else if ((DTW > DTW18_SNGL-1) & (DTW < DTW18_DBL)) begin : xDBL_DSP
    
                int_cmult_dbl18_dsp48 #( .MAW(DTW), .MBW(TWD), .XALU(4'b0011), .XSER(XSER))
                xMDSP_RE ( .M1_AA(DI_IM), .M1_BB(WW_IM), .M2_AA(DI_RE), .M2_BB(WW_RE), .MP_12(D_RE), .RST(RST), .CLK(CLK) );
                
                int_cmult_dbl18_dsp48 #( .MAW(DTW), .MBW(TWD), .XALU(4'b0000), .XSER(XSER))
                xMDSP_IM ( .M1_AA(DI_IM), .M1_BB(WW_RE), .M2_AA(DI_RE), .M2_BB(WW_IM), .MP_12(D_IM), .RST(RST), .CLK(CLK) );    
            
            // ---- Data width from 42/44 to 59/61 ----
            end else if ((DTW > DTW18_DBL-1) & (DTW < DTW18_TRPL)) begin : xTRPL_DSP
                
                int_cmult_trpl18_dsp48 #( .MAW(DTW), .MBW(TWD), .XALU(4'b0011), .XSER(XSER))
                xMDSP_RE ( .M1_AA(DI_IM), .M1_BB(WW_IM), .M2_AA(DI_RE), .M2_BB(WW_RE), .MP_12(D_RE), .RST(RST), .CLK(CLK) );
                
                int_cmult_trpl18_dsp48 #( .MAW(DTW), .MBW(TWD), .XALU(4'b0000), .XSER(XSER))
                xMDSP_IM ( .M1_AA(DI_IM), .M1_BB(WW_RE), .M2_AA(DI_RE), .M2_BB(WW_IM), .MP_12(D_IM), .RST(RST), .CLK(CLK) );                
    
            end

        // ---- Twiddle factor width more than 18 and less than 25/27 ----
        end else if ((TWD > 18) & (TWD < TWD_DSP)) begin : xTWDL25
    
            //---- Data width from 8 to 18 ----
            if (DTW < 19) begin : xSNGL_DSP
                wire [47 : 0] P_RE;
                wire [47 : 0] P_IM;
    
                assign D_RE = P_RE[DTW+TWD-3 : TWD-2];
                assign D_IM = P_IM[DTW+TWD-3 : TWD-2];
            
                int_cmult18x25_dsp48 #( .MAW(TWD), .MBW(DTW), .XALU(4'b0011), .XSER(XSER))
                xMDSP_RE ( .M1_AA(WW_IM), .M1_BB(DI_IM), .M2_AA(WW_RE), .M2_BB(DI_RE), .MP_12(P_RE), .RST(RST), .CLK(CLK) );
                
                int_cmult18x25_dsp48 #( .MAW(TWD), .MBW(DTW), .XALU(4'b0000), .XSER(XSER))
                xMDSP_IM ( .M1_AA(WW_RE), .M1_BB(DI_IM), .M2_AA(WW_IM), .M2_BB(DI_RE), .MP_12(P_IM), .RST(RST), .CLK(CLK) );        
            
            // ---- Data width from 18 to 35 ----
            end else if ((DTW > 18) & (DTW < 36)) begin : xDBL_DSP
    
                int_cmult_dbl35_dsp48 #( .MAW(DTW), .MBW(TWD), .XALU(4'b0011), .XSER(XSER))
                xMDSP_RE ( .M1_AA(DI_IM), .M1_BB(WW_IM), .M2_AA(DI_RE), .M2_BB(WW_RE), .MP_12(D_RE), .RST(RST), .CLK(CLK) );
                
                int_cmult_dbl35_dsp48 #( .MAW(DTW), .MBW(TWD), .XALU(4'b0000), .XSER(XSER))
                xMDSP_IM ( .M1_AA(DI_IM), .M1_BB(WW_RE), .M2_AA(DI_RE), .M2_BB(WW_IM), .MP_12(D_IM), .RST(RST), .CLK(CLK) );            
            
            // ---- Data width from 35 to 52 ----
            end else if ((DTW > 35) & (DTW < 53)) begin : xTRPL_DSP
            
                int_cmult_trpl52_dsp48 #( .MAW(DTW), .MBW(TWD), .XALU(4'b0011), .XSER(XSER))
                xMDSP_RE ( .M1_AA(DI_IM), .M1_BB(WW_IM), .M2_AA(DI_RE), .M2_BB(WW_RE), .MP_12(D_RE), .RST(RST), .CLK(CLK) );
                
                int_cmult_trpl52_dsp48 #( .MAW(DTW), .MBW(TWD), .XALU(4'b0000), .XSER(XSER))
                xMDSP_IM ( .M1_AA(DI_IM), .M1_BB(WW_RE), .M2_AA(DI_RE), .M2_BB(WW_IM), .MP_12(D_IM), .RST(RST), .CLK(CLK) );                
            end
        end
    endgenerate
endmodule
