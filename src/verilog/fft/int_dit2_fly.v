// -------------------------------------------------------------------------------
// --
// -- Title       : int_dit2_fly
// -- Design      : FFT
// -- Author      : Kapitanov Alexander
// -- Company     :
// -- E-mail      : sallador@bk.ru
// --
// -- Description : DIT butterfly (Radix-2)
// --
// -------------------------------------------------------------------------------
// --
// --    Version 1.0  29.11.2018
// --    Description: Simple butterfly Radix-2 for FFT (DIT)
// --
// --    Algorithm: Decimation in time
// --
// --    X = A+B*W,
// --    Y = A-B*W;
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

module int_dit2_fly
    #(
        parameter
        STAGE    = 3,    // --! Butterfly stages
        DTW      = 16,   // --! Data width
        TFW      = 16,   // --! Twiddle factor width
        SCALE    = 1,    // --! If 1 - Scaled, else Unscaled (truncate)
        XSER     = "OLD" // --! Xilinx series: NEW - DSP48E2, OLD - DSP48E1
    )
    (
        input clk, rst,
       
        input [DTW-1 : 0] ia_re, ia_im, ib_re, ib_im,
        input in_en,
        input [TFW-1 : 0] ww_re, ww_im,

        output signed [DTW-SCALE : 0] oa_re, oa_im, ob_re, ob_im,
        output do_vl
    );

    // functions declaration //
    function integer find_delay;
        input sVAR;
        input integer iDW, iTW;
        integer loDSP, hiDSP;
    begin
        loDSP = (sVAR == "OLD") ? 25 : 27;
        hiDSP = (sVAR == "OLD") ? 43 : 45;
        // ---- TWIDDLE WIDTH UP TO 18 ----
        if (iTW < 19) begin
            if (iDW <= loDSP)
                find_delay = 4;
            else if ((iDW > loDSP) && (iDW < hiDSP))
                find_delay = 6;
            else
                find_delay = 8;
        // ---- TWIDDLE WIDTH FROM 18 TO 25 ----
        end else if ((iTW > 18) && (iTW <= loDSP)) begin
            if (iDW < 19)
                find_delay = 4;
            else if ((iDW > 18) && (iDW < 36))
                find_delay = 6;
            else
                find_delay = 8;
        end else begin
        // ---- ADD YOUR CODE IF YOU NEED TWIDDLE WIDTH MORE THAN 25 BITS ----
            find_delay = 0;
        end
    end
    endfunction

    localparam ADD_DELAY = (DTW < 48) ? 2 : 3;

    reg [DTW-SCALE : 0] az_re, az_im, bw_re, bw_im;

    // ---------------------------------------------------------------
    // -------- SUM = (A + B), DIF = (A-B) --------
    int_addsub_dsp48 #(
        .DSPW(DTW),
        .XSER(XSER)
    )
    xADD_RE (
        .IA_RE(az_re),
        .IA_IM(az_im),
        .IB_RE(bw_re),
        .IB_IM(bw_im),

        .OX_RE(oa_re),
        .OX_IM(oa_im),
        .OY_RE(ob_re),
        .OY_IM(ob_im),

        .RST(rst),
        .CLK(clk)
    );
    // ---------------------------------------------------------------

    generate
        // ---- First butterfly: don't need multipliers! WW0 = {1, 0} ----
        if (STAGE == 0) begin : xST0
            reg [ADD_DELAY-1 : 0] vl_zz;

            always @(*) bw_re <= ib_re;
            always @(*) bw_im <= ib_im;
            always @(*) az_re <= ia_re;
            always @(*) az_im <= ia_im;
            assign do_vl = vl_zz[ADD_DELAY-1];

            always @(posedge clk) vl_zz <= {vl_zz[ADD_DELAY-2 : 0], in_en};

        // ---- Second butterfly: WW0 = {1, 0} and WW1 = {0, -1} ----
        end else if (STAGE == 1) begin : xST1

            reg [ADD_DELAY : 0] vl_zz;
            reg dt_sw; 

            // ---- Counter for twiddle factor ----
            always @(posedge clk) begin
                if (rst)
                    dt_sw <= 0;
                else if (in_en)
                    dt_sw <= ~dt_sw;
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
                    bw_re <= ib_re;
                    bw_im <= ib_im;
                end else begin
                    bw_im <= ib_re;
                    bw_re <= (ib_im[DTW-1]) ? (~ib_im) : ((~ib_im) + 1'b1);
                end
            end

            always @(posedge clk) vl_zz <= {vl_zz[ADD_DELAY-1 : 0], in_en};

            always @(posedge clk) begin
                az_re <= ia_re;
                az_im <= ia_im;
            end

            assign do_vl = vl_zz[ADD_DELAY];

        // ---- Others ----
        end else if (STAGE > 1) begin : xSTn

            localparam DATA_DELAY = find_delay(XSER, DTW+1-SCALE, TFW);

            reg [DTW-SCALE : 0] dz_re [0 : DATA_DELAY-1];
            reg [DTW-SCALE : 0] dz_im [0 : DATA_DELAY-1];
            reg [DATA_DELAY+ADD_DELAY-1 : 0] vl_zz;
            
            always @(posedge clk) vl_zz <= {vl_zz[DATA_DELAY+ADD_DELAY-2 : 0], in_en};

            integer i;
            always @ (posedge clk) begin
                for (i = 1; i < DATA_DELAY; i = i + 1) begin
                    dz_re[i] <= dz_re[i-1];
                    dz_im[i] <= dz_im[i-1];
                end
                dz_re[0] <= ia_re;
                dz_im[0] <= ia_im;
            end

            // -------- PROD = DIF * WW --------    
            int_cmult_dsp48 #( 
                .DTW(DTW+1-SCALE),
                .TWD(TFW),
                .XSER(XSER)
            )
            xCMPL (
                .DI_RE(ib_re),
                .DI_IM(ib_im),
                .WW_RE(ww_re),
                .WW_IM(ww_im),

                .DO_RE(bw_im),
                .DO_IM(bw_re),

                .RST(rst),
                .CLK(clk)
            );    

            assign do_vl = vl_zz[DATA_DELAY+ADD_DELAY-1];
        end
    endgenerate
endmodule