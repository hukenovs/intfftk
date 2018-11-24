// -------------------------------------------------------------------------------
// --
// -- Title       : row_twiddle_tay
// -- Design      : fpfftk
// -- Author      : Kapitanov Alexander
// -- Company     : 
// --
// -- Description : Integer Twiddle factor w/ Taylor scheme
// --
// -------------------------------------------------------------------------------
// --
// --    Version 1.0  22.11.2018
// --
// --     Data decoder for twiddle factor.
// --     Main algorithm for calculation FFT coefficients    by Taylor scheme.
// --
// --    Wcos(x) = cos(x)+sin(x)*pi*cnt(x)/NFFT; *
// --    Wsin(x) = sin(x)-cos(x)*pi*cnt(x)/NFFT;
// --
// --    MPX = (M_PI * CNT) is always has [15:0] bit field!
// --
// --    ** if NFFT > 512K just use 2D FFT algorithm!!
// --        
// --    RAMB (Width * Depth) is constant value and equals 32x1K,
// -- 
// --    Taylor alrogithm takes 3 Mults and 2 Adders in INT format. 
// --
// -- Summary:
// --    Twiddle WW generator takes 2 DSP48s and 2 RAMBs 18K.
// --
// --    -----------------------
// --    | STG  | COEFS | NFFT  |
// --    -----------------------
// --    |  0  |   2K  |   4K  |
// --    |  1  |   4K  |   8K  |
// --    |  2  |   8K  |  16K  |
// --    |  3  |  16K  |  32K  |
// --    |  4  |  32K  |  64K  |
// --    |  5  |  64K  | 128K  |
// --    |  6  | 128K  | 256K  |
// --    |  7  | 256K  | 512K  |
// --    -----------------------
// --
// -------------------------------------------------------------------------------
// --  
// --                       DSP48E1/2
// --             __________________________
// --            |                          |
// --            |     MULT 18x25(27)       |
// --   SIN/COS  | A   _____      ADD/SUB   |
// --  --------->|--->|     |      _____    |
// --   M_PI     | B  |  *  |---->|     |   | NEW SIN/COS
// --  --------->|--->|_____|     |  +  | P |
// --   COS/SIN  | C              |  /  |---|-->
// --  --------->|--------------->|  -  |   |
// --            |                |_____|   |
// --            |                          |
// --            |__________________________|
// -- 
// --   P = A[24:0] * B[17:0] + C[47:0] (7-series)
// --   P = A[26:0] * B[17:0] + C[47:0] (Ultrascale / Ultrascale+)
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

module row_twiddle_tay 
    #(
        parameter 
        AWD    = 16,    // --! Sin/cos MSB (Mag = 2**Amag)
        XSER   = "NEW", // --! FPGA family: for 6/7 series: "OLD"; for ULTRASCALE: "NEW"    
        STG    = 2      // --! Stage of Taylor series: 0, 1, 2, 3, 4, 5, 6, 7 
    )
    (
        input clk, rst,

        input [2*AWD-1 : 0] rom_ww,
        input [STG : 0] rom_cnt,
        output signed rom_re, rom_im
    );

    // ---------------- Calculate Data Width --------
    localparam real MATH_PI = 3.14159265358979323846;
    localparam integer XSHIFT = (XSER == "NEW") ? 21 : 23;

    function integer const_pi;
        input integer stage;
        integer del_val;
    begin
        del_val = (XSER == "NEW") ? 2 : 0;
        const_pi = $rtoi(MATH_PI * 2.0**(13-stage-del_val));
    end
    endfunction
    
    localparam integer MATHPI = const_pi(STG);
    
    // ---------------- Assign ROM data ----------------
    integer i; 
    reg [15 : 0] rom_pi [0 : 2**(STG+1)-1];
    initial begin
        for (i = 0; i < 2**(STG+1)-1; i = i + 1) begin 
          rom_pi[i] = i * MATHPI;
        end 
    end

    reg  [23 : 0] mpi;
	always @(posedge clk) mpi[15 : 0] <= rom_pi[rom_cnt];	
	always @(*) mpi[23 : 16] = 0;

    // ---------------- Rounding output data ----------------
    wire [47 : 0] sin_prod, cos_prod;
    wire [48-XSHIFT : 0] cos_pdt, sin_pdt;
    reg  [47-XSHIFT : 0] cos_rnd, sin_rnd;
    
    assign cos_pdt = cos_prod[47 : XSHIFT-1];
    assign sin_pdt = sin_prod[47 : XSHIFT-1];

    always @(posedge clk) begin
        if (cos_pdt[0]) 
            cos_rnd <= cos_pdt[48-XSHIFT : 1] + 1;
        else 
            cos_rnd <= cos_pdt[48-XSHIFT : 1];
    
        if (sin_pdt[0]) 
            sin_rnd <= sin_pdt[48-XSHIFT : 1] + 1;
        else 
            sin_rnd <= sin_pdt[48-XSHIFT : 1];
    end
    
    assign rom_re = sin_rnd[AWD-1 : 0];
    assign rom_im = cos_rnd[AWD-1 : 0];


    // ---- DSP48 MACC PORTS: P = A[24:0] * B[17:0] + C[47:0]
    // ---- DATA FOR B PORT (18-bit) ----
    wire [17 : 0] mpx;
    assign mpx = {{1'b0}, {mpi[17 : 1]}};

    // ---- DATA FOR A PORT (29-bit) ----
    wire [29 : 0] cos_aa, sin_aa;
    reg  [47 : 0] cos_cc, sin_cc;

    assign sin_aa = { {(29-(AWD-1)){rom_ww[1*AWD-1]}}, rom_ww[1*AWD-1 : 0*AWD] };
    assign cos_aa = { {(29-(AWD-1)){rom_ww[2*AWD-1]}}, rom_ww[2*AWD-1 : 1*AWD] };

    always @(posedge clk) begin
        cos_cc <= { {(48-AWD-XSHIFT){cos_aa[AWD-1]}}, cos_aa[AWD-1 : 0] , {(XSHIFT-1){1'b0}} };
        sin_cc <= { {(48-AWD-XSHIFT){sin_aa[AWD-1]}}, sin_aa[AWD-1 : 0] , {(XSHIFT-1){1'b0}} };
    end

    // ---- Counter / Address increment ----
    generate
        if (XSER == "OLD") begin

            DSP48E1 #(
                .ACASCREG(1),
                .ADREG(0),
                .ALUMODEREG(1),
                .AREG(1),
                .BCASCREG(1),
                .BREG(1),
                .CARRYINREG(1),
                .CARRYINSELREG(1),
                .CREG(1),
                .DREG(0),
                .INMODEREG(1),
                .MREG(1),
                .OPMODEREG(1),
                .PREG(1)
            )
            MULT_ADD (
                // Cascade: 30-bit (each) input: 
                .ACIN(30'b0),
                .BCIN(18'b0),
                .CARRYCASCIN(1'b0),
                .MULTSIGNIN(1'b0),
                .PCIN(48'b0),
                .ALUMODE(4'b0011),
                .CARRYINSEL(3'b0),
                .CLK(clk),
                .INMODE(5'b0),
                .OPMODE(7'b0110101),
                // Data input / output data ports
                .A(sin_aa),
                .B(mpx),
                .C(cos_cc),
                .P(cos_prod),
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
                .RSTA(rst),
                .RSTALLCARRYIN(rst),
                .RSTALUMODE(rst),
                .RSTB(rst),
                .RSTC(rst),
                .RSTCTRL(rst),
                .RSTD(rst),
                .RSTINMODE(rst),
                .RSTM(rst),
                .RSTP(rst)
            );

            DSP48E1 #(
                .ACASCREG(1),
                .ADREG(0),
                .ALUMODEREG(1),
                .AREG(1),
                .BCASCREG(1),
                .BREG(1),
                .CARRYINREG(1),
                .CARRYINSELREG(1),
                .CREG(1),
                .DREG(0),
                .INMODEREG(1),
                .MREG(1),
                .OPMODEREG(1),
                .PREG(1)
            )
            MULT_SUB (
                // Cascade: 30-bit (each) input: 
                .ACIN(30'b0),
                .BCIN(18'b0),
                .CARRYCASCIN(1'b0),
                .MULTSIGNIN(1'b0),
                .PCIN(48'b0),
                .ALUMODE(4'b0000),
                .CARRYINSEL(3'b0),
                .CLK(clk),
                .INMODE(5'b0),
                .OPMODE(7'b0110101),
                // Data input / output data ports
                .A(cos_aa),
                .B(mpx),
                .C(sin_cc),
                .P(sin_prod),
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
                .RSTA(rst),
                .RSTALLCARRYIN(rst),
                .RSTALUMODE(rst),
                .RSTB(rst),
                .RSTC(rst),
                .RSTCTRL(rst),
                .RSTD(rst),
                .RSTINMODE(rst),
                .RSTM(rst),
                .RSTP(rst)
            );
        end else begin

            DSP48E2 #(
                .ACASCREG(1),
                .ADREG(0),
                .ALUMODEREG(1),
                .AREG(1),
                .BCASCREG(1),
                .BREG(1),
                .CARRYINREG(1),
                .CARRYINSELREG(1),
                .CREG(1),
                .DREG(0),
                .INMODEREG(1),
                .MREG(1),
                .OPMODEREG(1),
                .PREG(1)
            )
            MULT_ADD (
                // Cascade: 30-bit (each) input: 
                .ACIN(30'b0),
                .BCIN(18'b0),
                .CARRYCASCIN(1'b0),
                .MULTSIGNIN(1'b0),
                .PCIN(48'b0),
                .ALUMODE(4'b0011),
                .CARRYINSEL(3'b0),
                .CLK(clk),
                .INMODE(5'b0),
                .OPMODE(9'b000110101),
                // Data input / output data ports
                .A(sin_aa),
                .B(mpx),
                .C(cos_cc),
                .P(cos_prod),
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
                .RSTA(rst),
                .RSTALLCARRYIN(rst),
                .RSTALUMODE(rst),
                .RSTB(rst),
                .RSTC(rst),
                .RSTCTRL(rst),
                .RSTD(rst),
                .RSTINMODE(rst),
                .RSTM(rst),
                .RSTP(rst)
            );

            DSP48E2 #(
                .ACASCREG(1),
                .ADREG(0),
                .ALUMODEREG(1),
                .AREG(1),
                .BCASCREG(1),
                .BREG(1),
                .CARRYINREG(1),
                .CARRYINSELREG(1),
                .CREG(1),
                .DREG(0),
                .INMODEREG(1),
                .MREG(1),
                .OPMODEREG(1),
                .PREG(1)
            )
            MULT_SUB (
                // Cascade: 30-bit (each) input: 
                .ACIN(30'b0),
                .BCIN(18'b0),
                .CARRYCASCIN(1'b0),
                .MULTSIGNIN(1'b0),
                .PCIN(48'b0),
                .ALUMODE(4'b0000),
                .CARRYINSEL(3'b0),
                .CLK(clk),
                .INMODE(5'b0),
                .OPMODE(9'b000110101),
                // Data input / output data ports
                .A(cos_aa),
                .B(mpx),
                .C(sin_cc),
                .P(sin_prod),
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
                .RSTA(rst),
                .RSTALLCARRYIN(rst),
                .RSTALUMODE(rst),
                .RSTB(rst),
                .RSTC(rst),
                .RSTCTRL(rst),
                .RSTD(rst),
                .RSTINMODE(rst),
                .RSTM(rst),
                .RSTP(rst)
            );
        end
    endgenerate
endmodule