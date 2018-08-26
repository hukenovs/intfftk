// -------------------------------------------------------------------------------
// 
//  Title       : rom_twiddle_int
//  Design      : FFTK
//  Author      : Kapitanov Alexander
//  Company     :
// 
//  Description : Integer Twiddle factor (sin/cos)
// 
// -----------------------------------------------------------------------------
// 
// 	Version 1.0  01.03.2018
//     Description: Twiddle factor in ROMs for FFT/IFFT.
//  
// 
//  Example: NFFT = 16
//     ---------------------------------
//     | Stage | DEPTH | COEFS | RAMBS |
//     ---------------------------------
//     |   15  | 512   | 32K   |  TAY  |
//     |   14  | 512   | 16K   |  TAY  |
//     |   13  | 512   |  8K   |  TAY  |
//     |   12  | 512   |  4K   |  TAY  |
//     |   11  | 512** |  2K   |  TAY  |
//     |   10  | 512   |  1K   |   1   |
//     |    9  | 256   | 512   |   0   |
//     |    8  | 128   | 256   |  LUT  |
//     |    7  |  64   | 128   |  LUT  |
//     |    6  |  32   |  64   |  LUT  |
//     |    5  |  16   |  32   |  LUT  |
//     |    4  |   8   |  16   |  LUT  |
//     |    3  |   4   |   8   |  LUT  |
//     |    2  |   2   |   4   |  LUT  |
//     |    1  |   1   |   2   |   X   |
//     |    0  |   1*  |   1   |   X   |
//     ---------------------------------
//  
//  Example: NFFT = 11
//    ---------------------------------
//    | Stage | DEPTH | COEFS | RAMBS |
//    ---------------------------------
//    |   10  |  512  |  1K   |  RAMB |
//    |   9   |  256  | 512   |  LUT  |
//    |   8   |  128  | 256   |  LUT  |
//    |   7   |   64  | 128   |  LUT  |
//    |   6   |   32  |  64   |  LUT  |
//    |   5   |   16  |  32   |  LUT  |
//    |   4   |    8  |  16   |  LUT  |
//    |   3   |    4  |   8   |  LUT  |
//    |   2   |    2  |   4   |  LUT  |
//    |   1   |    1  |   2   |   X   |
//    |   0   |    1* |   1   |   X   |
//    ----------------------------------
// 
//  * - first and second stages don't need ROM. 
//      STAGE = 0: {0,1}; 
//      STAGE = 1: {0,1} and {-1,0};
//  ** - Taylor scheme (1 RAMB)
// 
//  AWD - data width = 16-25(27) for integer twiddle factor
//  
//  Delay: IF (STAGE < 11): delay - 2 taps,
//         ELSE: delay - 7 taps.
// 
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// 
// 	GNU GENERAL PUBLIC LICENSE
//   Version 3, 29 June 2007
// 
// 	Copyright (c) 2018 Kapitanov Alexander
// 
//   This program is free software: you can redistribute it and/or modify
//   it under the terms of the GNU General Public License as published by
//   the Free Software Foundation, either version 3 of the License, or
//   (at your option) any later version.
// 
//   You should have received a copy of the GNU General Public License
//   along with this program.  If not, see <http://www.gnu.org/licenses/>.
// 
//   THERE IS NO WARRANTY FOR THE PROGRAM, TO THE EXTENT PERMITTED BY
//   APPLICABLE LAW. EXCEPT WHEN OTHERWISE STATED IN WRITING THE COPYRIGHT 
//   HOLDERS AND/OR OTHER PARTIES PROVIDE THE PROGRAM "AS IS" WITHOUT WARRANTY 
//   OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, 
//   THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR 
//   PURPOSE.  THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE PROGRAM 
//   IS WITH YOU.  SHOULD THE PROGRAM PROVE DEFECTIVE, YOU ASSUME THE COST OF 
//   ALL NECESSARY SERVICING, REPAIR OR CORRECTION. 
//  
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------

module rom_twiddle_int
  #(
    parameter 
    NFFT  = 16,
    STAGE = 4,
    AWD   = 16,
	XSER  = "OLD"
  )
  (
  input clk, rst, 
  output signed [AWD-1:0] ww_re, ww_im,
  output ww_en
  );

  // functions declaration //
  function find_depth;
  input avar;
  begin
    if ((avar > 0) & (avar < 11)) find_depth = (avar-1);  
    else find_depth = 9;
  end
  endfunction
  
  localparam DEPTH = find_depth(NFFT); 
  
  
  localparam MATH_PI = 3.14159265359;
  reg [2*AWD-1 : 0] arr_re [0 : 2**DEPTH-1];
  reg [2*AWD-1 : 0] arr_im [0 : 2**DEPTH-1];
  
//  reg  mg_std;  
//  integer i;
//  initial begin
//    for (i = 0; i < 2**DEPTH; i = i +1) begin
//    mg_std = ((2.0 ** (AWD-1)) - 1.0) ? AWD < 18 : (2.0 ** (AWD-2)) - 1.0;
//    arr_re[i] <= mg_std * COS((i * MATH_PI)/(2**(DEPTH+1)));
//    arr_im[i] <= mg_std * SIN(-(i * MATH_PI)/(2**(DEPTH+1)));
//    end
//  end 


  reg [STAGE-1:0]		cnt;
  wire div;
  
  always @(posedge clk) begin
  if (rst) cnt <= 0;
  else cnt <= cnt + 1;
  end

  assign div = cnt[STAGE-1];
  
  
endmodule



