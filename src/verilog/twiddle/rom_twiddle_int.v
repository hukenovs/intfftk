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
  function integer find_depth;
    input integer avar;
  begin
    if ((avar > 0) && (avar < 11)) find_depth = (avar-1);  
    else find_depth = 9;
  end
  endfunction
  
  localparam DEPTH = find_depth(STAGE);
  localparam real MATH_PI = 3.14159265358979323846;

  // Factorial function: y = x! if x = 0 or 1 then y = 1 else y = factorial(x)
  function automatic [63:0] fn_fact;
    input [4:0] x;
    integer i;
  begin
    if (x > 1)
      fn_fact = fn_fact(x-1) * x;
    else 
      fn_fact = 1;
  end
  endfunction

  // Calculate sin(x) via Taylor series (10-order)
  function real find_sin;
    input real x;
  begin
    find_sin = x - x**3/fn_fact(3) + x**5/fn_fact(5) - x**7/fn_fact(7) + x**9/fn_fact(9) - x**11/fn_fact(11) + x**13/fn_fact(13) - x**15/fn_fact(15) + x**17/fn_fact(17) - x**19/fn_fact(19);
  end
  endfunction

  // Calculate cos(x) via Taylor series (10-order)
  function real find_cos;
  input real x;
  begin
    find_cos = 1 - x**2/fn_fact(2) + x**4/fn_fact(4) - x**6/fn_fact(6) + x**8/fn_fact(8) - x**10/fn_fact(10) + x**12/fn_fact(12) - x**14/fn_fact(14) + x**16/fn_fact(16) - x**18/fn_fact(18);
  end
  endfunction

  // Create ROM data
  function [2*AWD-1 : 0] rom_twiddle;
    input integer ii;

    real phase, magn;
    reg [AWD-1 : 0] sig_re, sig_im;
  begin
    magn = (AWD < 18) ? (2.0 ** (AWD-1) - 1.0) : (2.0 ** (AWD-2) - 1.0); 

    phase = (ii * MATH_PI) / (2.0 ** (DEPTH+1));

    sig_re = $rtoi(magn * find_cos(phase)); // $rtoi(real_number);
    sig_im = $rtoi(magn * find_sin(phase));

    rom_twiddle = {sig_im, sig_re};
  end
  endfunction

  integer i; 
  reg [2*AWD-1 : 0] arr_data [0 : 2**DEPTH-1];
  initial begin
    for (i = 0; i < 2**DEPTH; i = i + 1) 
      arr_data[i] = rom_twiddle(i); 
  end
  
  reg [STAGE-1:0] cnt;
  wire div;
  
  always @(posedge clk) begin
  if (rst) cnt <= 0;
  else cnt <= cnt + 1;
  end

  assign div = cnt[STAGE-1];
  
endmodule