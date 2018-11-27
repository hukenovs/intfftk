// -------------------------------------------------------------------------------
// --
// -- Title       : int_dif2_fly
// -- Design      : FFT
// -- Author      : Kapitanov Alexander
// -- Company     :
// -- E-mail      : sallador@bk.ru
// --
// -- Description : DIF butterfly (Radix-2)
// --
// -------------------------------------------------------------------------------
// --
// --    Version 1.0  10.12.2017
// --    Description: Simple butterfly Radix-2 for FFT (DIF)
// --
// --    Algorithm: Decimation in frequency
// --
// --    X = (A+B), 
// --    Y = (A-B)*W;
// --
// -------------------------------------------------------------------------------
// -------------------------------------------------------------------------------
// --
// --  GNU GENERAL PUBLIC LICENSE
// --  Version 3, 29 June 2007
// --
// --  Copyright (c) 2018 Kapitanov Alexander
// --
// --  This program is free software: you can redistribute it and/or modify
// --  it under the terms of the GNU General Public License as published by
// --  the Free Software Foundation, either version 3 of the License, or
// --  (at your option) any later version.
// --
// --  You should have received a copy of the GNU General Public License
// --  along with this program.  If not, see <http://www.gnu.org/licenses/>.
// --
// --  THERE IS NO WARRANTY FOR THE PROGRAM, TO THE EXTENT PERMITTED BY
// --  APPLICABLE LAW. EXCEPT WHEN OTHERWISE STATED IN WRITING THE COPYRIGHT 
// --  HOLDERS AND/OR OTHER PARTIES PROVIDE THE PROGRAM "AS IS" WITHOUT WARRANTY 
// --  OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, 
// --  THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR 
// --  PURPOSE.  THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE PROGRAM 
// --  IS WITH YOU.  SHOULD THE PROGRAM PROVE DEFECTIVE, YOU ASSUME THE COST OF 
// --  ALL NECESSARY SERVICING, REPAIR OR CORRECTION. 
// -- 
// -------------------------------------------------------------------------------
// -------------------------------------------------------------------------------

module int_dif2_fly
    
    #(
        parameter
        STAGE    = 0,    // --! Butterfly stages
        DTW      = 16;   // --! Data width
        TFW      = 16;   // --! Twiddle factor width
        XSER     = "OLD" // --! Xilinx series: NEW - DSP48E2, OLD - DSP48E1
    )
    (
        input clk, rst,
       
        input [DTW-1 : 0] ia_re, ia_im, ib_re, ib_im,
        input in_en,
        input [TFW-1 : 0] ww_re, ww_im,

        output signed [DTW : 0] oa_re, oa_im, ob_re, ob_im,
        output do_vl
    );

    // functions declaration //
    function integer find_delay;
        input string sVAR;
        input integer iDW, iTW;
    begin
        // ---- DSP48E1 ----
        if (sVAR = "OLD") begin 
            // ---- TWIDDLE WIDTH UP TO 18 ----
            if (iTW < 19) begin
                if (iDW < 26)
                    find_delay = 4;
                else if ((iDW > 25) && (iDW < 43))
                    find_delay = 6;
                else
                    find_delay = 8;
            // ---- TWIDDLE WIDTH FROM 18 TO 25 ----
            end else if ((iTW > 18) && (iTW < 26)) begin
                if (iDW < 19)
                    find_delay = 4;
                else if ((iDW > 18) && (iDW < 36))
                    find_delay = 6;
                else
                    find_delay = 8;
            end else begin
                find_delay = 0;
            end
        // ---- DSP48E2 ----
        end else if (sVAR = "NEW") begin
            // ---- TWIDDLE WIDTH UP TO 18 ----
            if (iTW < 19) begin
                if (iDW < 28)
                    find_delay = 4;
                else if ((iDW > 27) && (iDW < 45))
                    find_delay = 6;
                else
                    find_delay = 8;
                end
            // ---- TWIDDLE WIDTH FROM 18 TO 25 ----
            end else if ((iTW > 18) && (iTW < 28)) begin
                if (iDW < 19)
                    find_delay = 4;
                else if ((iDW > 18) && (iDW < 36))
                    find_delay = 6;
                else
                    find_delay = 8;
            end else begin
                find_delay = 0;
            end
        else begin
            find_delay = 0;
        end
    endfunction

    localparam ADD_DELAY = (iDW < 48) ? 2 : 3;

    wire [DTW : 0] ad_re, ad_im, su_re, su_im;

    // ---------------------------------------------------------------
    // -------- SUM = (A + B), DIF = (A-B) --------
    int_addsub_dsp48 #(
        .DSPW(DTW),
        .XSER(XSER)
    )
    xADD_RE (
        .IA_RE(ia_re),
        .IA_IM(ia_im),
        .IB_RE(ib_re),
        .IB_IM(ib_im),

        .OX_RE(ad_re),
        .OX_IM(ad_im),
        .OY_RE(su_re),
        .OY_IM(su_im),

        .RST(rst),
        .CLK(clk)
    );
    // ---------------------------------------------------------------

    generate
        // ---- First butterfly: don't need multipliers! WW0 = {1, 0} ----
        if (STAGE = 0) begin : xST0
            reg [ADD_DELAY-1 : 0] vl_zz;
        begin
            assign oa_re = ad_re;
            assign oa_im = ad_im;
            assign ob_re = su_re;
            assign ob_im = su_im;
            assign do_vl = vl_zz[add_delay-1];

            always @(posedge clk) begin
                vl_zz[0] <= IN_EN;
                vl_zz <= vl_zz << 1;
            end

        // ---- Second butterfly: WW0 = {1, 0} and WW1 = {0, -1} ----
        end else if (STAGE = 1) begin : xST1

            reg [ADD_DELAY : 0] vl_zz;
            reg dt_sw; 
            reg [DTW : 0] az_re, az_im, sz_re, sz_im;

            // ---- Counter for twiddle factor ----
            always @(posedge clk) begin
                if (rst) begin
                    dt_sw <= 0;
                end else begin
                    if (vl_zz[ADD_DELAY-1]) begin
                        dt_sw <= ~dt_sw;
                    end
                end
            end

            /* --------------------------------------------------------------
               ---- NB! Multiplication by (-1) is the same as inverse.   ----
               ---- But in 2's complement you should inverse data and +1 ----
               ---- Most negative value in 2's complement is WIERD NUM   ----
               ---- So: for positive values use Y = not(X) + 1,          ----
               ---- and for negative values use Y = not(X)               ----
               -------------------------------------------------------------- */

            // ---- Flip twiddles ----
            always @(posedge clk) begin
                // ---- WW(0){Re,Im} = {1, 0} ----
                if (dt_sw) begin
                    sz_re <= su_re;
                    sz_im <= su_im;
                end else begin
                    sz_re <= su_im;
                    if (su_re[DTW]) begin
                        sz_im <= (~su_re);
                    end else begin
                        sz_im <= (~su_re) + 1'b1;
                    end
                end
            end

            always @(posedge clk) begin
                vl_zz[0] <= IN_EN;
                vl_zz <= vl_zz << 1;
            end

            always @(posedge clk) begin
                az_re <= ad_re;
                az_im <= ad_im;
            end

            assign oa_re = az_re;
            assign oa_im = az_im;
            assign ob_re = sz_re;
            assign ob_im = sz_im;
            assign do_vl = vl_zz[ADD_DELAY];

        // ---- Others ----
        end else if (STAGE > 1) begin : xSTn

            localparam DATA_DELAY = find_delay(XSER, DTW+1, TFW);
            // type std_logic_delayN is array (DATA_DELAY-1 : 0] of std_logic_vector[DTW : 0];
            wire [DTW : 0] db_re, db_im;

            reg [DTW : 0] az_re, az_im [0 : DATA_DELAY-1];
            reg [DATA_DELAY+ADD_DELAY-1 : 0] vl_zz;

            always @ (posedge clk) begin
                vl_zz[0] <= IN_EN;
                az_re[0] <= AD_RE;
                az_im[0] <= AD_IM;
                vl_zz <= vl_zz << 1;
                az_re <= az_re << 1;
                az_im <= az_im << 1;
            end

            // -------- PROD = DIF * WW --------    
            int_cmult_dsp48 #( 
                .DTW(DTW+1),
                .TWD(TFW),
                .XSER(XSER)
            )
            xCMPL (
                .DI_RE(su_re),
                .DI_IM(su_im),
                .WW_RE(ww_re),
                .WW_IM(ww_im),
                .DO_RE(db_re),
                .DO_IM(db_im),
                .RST(rst),
                .CLK(clk)
            );    

            assign oa_re = az_re[DATA_DELAY-1];
            assign oa_im = az_im[DATA_DELAY-1];
            assign ob_re = db_re;
            assign ob_im = db_im;
            assign do_vl = vl_zz[DATA_DELAY+ADD_DELAY-1];
        end
    endgenerate
endmodule