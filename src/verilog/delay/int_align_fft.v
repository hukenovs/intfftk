//-----------------------------------------------------------------------------
//
// Title       : int_align_fft
// Design      : Integer FFTK
// Author      : Kapitanov Alexander
// Company     : 
//
// Description : Align Forward FFT data and twiddles by using delay lines
//
// Version 1.0  23.08.2018
//         Delay correction for TWIDDLE factor and FLYes: Forward FFT
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

module int_align_fft 
    #(
        parameter 
        NFFT  = 16,
        DATW  = 4,
        STAGE = 16
    )
    (
        input  CLK, 
        input  [DATW-1:0] IA_RE, IA_IM, IB_RE, IB_IM,
        output reg [DATW-1:0] OA_RE, OA_IM, OB_RE, OB_IM,
        
        input  BF_EN, 
        output reg BF_VL, TW_EN
    );

    generate
        if (STAGE < 11) begin
            
            always @(*) begin
                BF_VL = BF_EN;
                OA_RE = IA_RE;
                OA_IM = IA_IM;
                OB_RE = IB_RE;
                OB_IM = IB_IM;
            end                

        end else if ((STAGE > 1) & (STAGE < 11)) begin

            if (DATW < 48) begin
                always @(*) begin
                    TW_EN = BF_EN;
                end
            end else if (DATW > 47) begin
                always @(posedge(CLK)) begin
                    TW_EN <= BF_EN;
                end
            end
        end else if (STAGE > 10) begin
    
            localparam integer ADD_DEL = (DATW < 48) ? 3 : 2;
            reg [DATW-1 : 0] za_re[ADD_DEL : 0] ;
            reg [DATW-1 : 0] za_im[ADD_DEL : 0] ;
            reg [DATW-1 : 0] zb_re[ADD_DEL : 0] ;
            reg [DATW-1 : 0] zb_im[ADD_DEL : 0] ;
            reg bf_ez [ADD_DEL : 0];  
            
            always @(*) begin
                TW_EN = BF_EN;
            end 
            
            integer i;
            always @(posedge CLK) begin
                for(i = ADD_DEL; i > 0; i=i-i) begin
                    za_re[i] <= za_re[i-1];
                    za_im[i] <= za_im[i-1];
                    zb_re[i] <= zb_re[i-1];
                    zb_im[i] <= zb_im[i-1];
                    bf_ez[i] <= bf_ez[i-1];
                end
                za_re[0] <= IA_RE;
                za_im[0] <= IA_IM;
                zb_re[0] <= IB_RE;
                zb_im[0] <= IB_IM;
                bf_ez[0] <= BF_EN;
            end

            always @(*) begin
                OA_RE = za_re[ADD_DEL];
                OA_IM = za_im[ADD_DEL];
                OB_RE = zb_re[ADD_DEL];
                OB_IM = zb_im[ADD_DEL];
                BF_VL = bf_ez[ADD_DEL];
            end

        end
    endgenerate
endmodule