# Integer FFT/IFFT cores
This project contains integer FFT/IFFT cores for FPGA, Scheme: Radix-2, Decimation in frequency and decimation in time. Integer data type and twiddles. Code language - VHDL. Vendor: Xilinx, 6/7-series, Ultrascale, Ultrascale+. Smallest FPGA resourses and highest processing frequency that you ever seen!

### Main information

+-------------------+--------------------------------------------+
| **Title**         | Universal integer FFT cores( Xilinx FPGAs) |
+-------------------+--------------------------------------------+
| **Author**        | Alexander Kapitanov                        |
+-------------------+--------------------------------------------+
| **Contact**       | sallador@bk.ru                             |
+-------------------+--------------------------------------------+
| **Project lang**  | VHDL                                       |
+-------------------+--------------------------------------------+
| **Vendor**        | Xilinx: 6/7-series, Ultrascale, US+        |
+-------------------+--------------------------------------------+
| **Release Date**  | 20 July 2018                               |
+-------------------+--------------------------------------------+
| **Version**       | 1.0                                        |
+-------------------+--------------------------------------------+

### List of complements:
- FFTs:
 * int_fftNk – main core - FFT, Radix-2, DIF, input flow - normal, output flow - bit-reversed.
 * int_ifftNk – main core - IFFT, Radix-2, DIT, input flow - bit-reversed, output flow - normal, .

- Bflies:
 * int_dif2_fly – butterfly Radix-2, decimation in frequency,
 * int_dit2_fly – butterfly Radix-2, decimation in time,

- Complex multipliers:
 * int_cmult_dsp48 – main integer complex multiplier contains several cmults:
  * int_cmult18x25_dsp48 – simple 25 x 18 two’s-complement half-complex-multiplier,
  * int_cmult_dbl18_dsp48 – double 42(44) x 18 two’s-complement half-complex-multiplier,
  * int_cmult_dbl35_dsp48 – double 25(27) x 35 two’s-complement half-complex-multiplier,
  * int_cmult_trpl18_dsp48 – triple 59(61) x 18 two’s-complement half-complex-multiplier,
  * int_cmult_trpl52_dsp48 – triple 25(27) x 52 two’s-complement half-complex-multiplier,
> "half" means that you should set output flow: Re or Im part.

- Multipliers:
 * mlt42x18_dsp48e1 – 42 x 18 two’s-complement multiplier (DSP48E1), del.: 4 taps, res.: 2 DSPs.
 * mlt59x18_dsp48e1 – 59 x 18 two’s-complement multiplier (DSP48E1), del.: 5 taps, res.: 3 DSPs.
 * mlt35x25_dsp48e1 – 35 x 25 two’s-complement multiplier (DSP48E1), del.: 4 taps, res.: 2 DSPs.
 * mlt52x25_dsp48e1 – 52 x 25 two’s-complement multiplier (DSP48E1), del.: 5 taps, res.: 3 DSPs.
 * mlt44x18_dsp48e2 – 44 x 18 two’s-complement multiplier (DSP48E2), del.: 4 taps, res.: 2 DSPs.
 * mlt61x18_dsp48e2 – 61 x 18 two’s-complement multiplier (DSP48E2), del.: 5 taps, res.: 3 DSPs.
 * mlt35x27_dsp48e2 – 35 x 27 two’s-complement multiplier (DSP48E2), del.: 4 taps, res.: 2 DSPs.
 * mlt52x27_dsp48e2 – 52 x 27 two’s-complement multiplier (DSP48E2), del.: 5 taps, res.: 3 DSPs.

- Adder:
 * int_addsub_dsp48 – based on DSP48, up to 96-bit two’s-complement addition/substraction.

- Delay line:
 * int_delay_line – main delay line, cross-commutation data between butterflies.
 * int_align_fft – data and twiddle factor alignment for butterflies in FFT core,
 * int_align_fft – data and twiddle factor alignment for butterflies in IFFT core,

- Twiddles:
 * rom_twiddle_int – 1/4-periodic signal, twiddle factor generator based on memory and sometimes uses DSP48 units for large FFTs
 * row_twiddle_tay – twiddle factor generator which used Taylor scheme for calculation twiddles.

- Buffers:
 * inbuf_half_path – simple input buffer, perform flow into two flows: [0 .. NFFT/2), (NFFT/2 .. NFFT-1], single clock,
 * outbuf_half_path – simple input buffer, merge two flows into one signal, single clock,

 * iobuf_flow_int2 – Mode-1: BITREV = FALSE: convert Interleave-2 flow into two parts of input flows, Mode-2: BITREV = TRUE: convert two-half flows into Interleave-2 signal. 
 * int_bitrev_ord – simple converter data from bit-reverse to natural order.

