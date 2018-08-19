%% -------------------------------------------------------------------------- %%
%
% Title       : fft_radix2.m
% Author      : Alexander Kapitanov	
% Company     : Insys
% E-mail      : sallador@bk.ru 
% Version     : 1.0	 
%
% --------------------------------------------------------------------------- %%
%
% Description : 
%    Radix-2 model for FFT / IFFT core
%
% --------------------------------------------------------------------------- %%
%
% Version     : 1.0 
% Date        : 2018.06.03
%
%% -------------------------------------------------------------------------- %%
function Dout = fn_radix2(Din, N, MODE)
  if (MODE == 'FWD') 
    Dout = fn_fft_dif(Din, N);
  elseif (MODE == 'INV')
    Dout = fn_fft_dit(Din, N);
  else
    Dout = 0;
    disp('Please, enter correct MODE parameter: FWD of INV!');
  endif
endfunction
%% -------------------------------------------------------------------------- %%
% ------------ Radix-2: Cross-commutation function for FFT/iFFT -------------- %
% -- 
% -- Example: NFFT = 16, Stages = log2(NFFT)-1 = 3;
% -- Data: Ia / Ib - input data, Oa / Ob - output data (HEX format)
% --
% -- Stage 1: 
% -- 
% -- Ia: 01234567    Oa: 012389AB (switch each N/4  = 4 block)
% -- Ib: 89ABCDEF    Ob: 4567CDEF
% --
% -- Stage 2: 
% -- 
% -- Ia: 012389AB    Oa: 014589CD (switch each N/8  = 2 block)
% -- Ib: 4567CDEF    Ob: 2367ABEF
% --
% -- Stage 3: 
% -- 
% -- Ia: 014589CD    Oa: 02468ACE (switch each N/16 = 1 block)
% -- Ib: 2367ABEF    Ob: 13579BDF
% --
function [Oa, Ob] = fn_rev2rdx(Ia, Ib, stg, N)
  CNTj = 2^stg;
  CNTi = (N/2)/CNTj;
  for i = 1:CNTi
    for j = 1:CNTj
      
      STP = 2*(ceil(j/2)-1)*CNTi;
      
      if (mod(j,2) == 1)
        Oa(i+CNTi*(j-1),1) = Ia(i+STP);
        Ob(i+CNTi*(j-1),1) = Ia(i+STP+CNTi);
      else
        Oa(i+CNTi*(j-1),1) = Ib(i+STP);
        Ob(i+CNTi*(j-1),1) = Ib(i+STP+CNTi);
      endif

    endfor
  endfor
endfunction

function [Oa, Ob] = fn_rdx2rev(Ia, Ib, stg, N)
  NL = log2(N);
  CNTj = 2^(NL-stg);
  CNTi = (N/2)/CNTj;
  for i = 1:CNTi
    for j = 1:CNTj
      
      STP = 2*(ceil(j/2)-1)*CNTi;
      
      if (mod(j,2) == 1)
        Oa(i+CNTi*(j-1),1) = Ia(i+STP);
        Ob(i+CNTi*(j-1),1) = Ia(i+STP+CNTi);
      else
        Oa(i+CNTi*(j-1),1) = Ib(i+STP);
        Ob(i+CNTi*(j-1),1) = Ib(i+STP+CNTi);
      endif
    endfor
  endfor
endfunction
%% -------------------------------------------------------------------------- %%
% ------------ Radix-2: Twiddle factor (exp^(-j*nk*pi/NFFT) ------------------ %
% --
function [Ww] = fn_twiddle_dif(N)
  for i = 1:N/2  
    Wre(i,1) = cos((i-1) * 2*pi/N);
    Wim(i,1) = sin((i-1) * 2*pi/N);  
  endfor
  Ww = Wre - 1j*Wim;
endfunction

function [Ww] = fn_twiddle_dit(N)
  for i = 1:N/2  
    Wre(i,1) = cos((i-1) * 2*pi/N);
    Wim(i,1) = sin((i-1) * 2*pi/N);  
  endfor
  Ww = Wre + 1j*Wim;
endfunction

function [Wo] = fn_twiddleN_dif(Wi, i, N)   
  CNT = 2^((i-1));
  STP = (N/2)/CNT;
  for n = 1:STP
    for k = 1:CNT;
      Wo(n + STP*(k-1),1) = Wi((n-1)*CNT+1,1);
    endfor
  endfor
endfunction

function [Wo] = fn_twiddleN_dit(Wi, i, N)   
  NL = log2(N);
  CNT = 2^((NL-i));
  STP = (N/2)/CNT;
  for n = 1:STP
    for k = 1:CNT;
      Wo(n + STP*(k-1),1) = Wi((n-1)*CNT+1,1);
    endfor
  endfor
endfunction
%% -------------------------------------------------------------------------- %%
% ------------ Radix-2: Butterfly (DIF: decimation in freq ------------------- %
% --
% -- Decimation in frequency: DIF FFT Radix-2
% -- OA = (IA + IB);
% -- OB = (IA - IB) * Ww;
% --
function [Oa, Ob] = fn_fly_dif(Ia, Ib, Ww)
  Oa = (Ia .+ Ib);
  Ob = (Ia .- Ib) .* Ww;
endfunction
% --
% -- Decimation in time: DIT FFT Radix-2
% -- OA = IA + IB * Ww;
% -- OB = IA - IB * Ww;
% --
function [Oa, Ob] = fn_fly_dit(Ia, Ib, Ww)
  Oa = Ia .+ Ib .* Ww;
  Ob = Ia .- Ib .* Ww;
endfunction
% --
%% -------------------------------------------------------------------------- %%
% ------------ Radix-2: Forward FFT algorithm: DIF / DIT --------------------- %
function Dout = fn_fft_dif(Din, N)
  % Input buffer
  Ia(:,1) = Din(1:N/2,1);
  Ib(:,1) = Din(1+N/2:N,1);
  
  % Twiddle factor
  Ww = fn_twiddle_dif(N);
  NL = log2(N);

  for i = 1:NL
    % Find twiddle factor
    Wx = fn_twiddleN_dif(Ww, i, N);
    
    if (i == 1)
      Ta = Ia;
      Tb = Ib;
    else
      Ta = Ra;
      Tb = Rb;  
    endif
    % Calculate butterfly
    [Oa, Ob] = fn_fly_dif(Ta, Tb, Wx);
%    Oa = Ta;
%    Ob = Tb;
    % Cross commutation
    if (i < NL)
      [Ra, Rb] = fn_rev2rdx(Oa, Ob, i, N);
    endif
  endfor  
   % Output buffer
  for i = 1:N/2  
    Oo(2*i-1,1) = Oa(i,1);
    Oo(2*i-0,1) = Ob(i,1);  
  endfor

  % Bitreverse Radix-2
  Dout = bitrevorder(Oo);

endfunction


function Dout = fn_fft_dit(Din, N)
  % Input buffer
  
  Dx = bitrevorder(Din);
  % Di = real(Dx) - 1j*imag(Dx);
  for i = 1:N/2  
    Ia(i,1) = Dx(2*i-1,1);
    Ib(i,1) = Dx(2*i-0,1);  
  endfor

  % Twiddle factor
  Ww = fn_twiddle_dit(N);
  NL = log2(N);
  
  for i = 1:NL
    % Find twiddle factor
    Wx = fn_twiddleN_dit(Ww, i, N);
    
    if (i == 1)
      Ta = Ia;
      Tb = Ib;
    else
      Ta = Ra;
      Tb = Rb;  
    endif
    % Calculate butterfly
    [Oa, Ob] = fn_fly_dit(Ta, Tb, Wx);
%    Oa = Ta;
%    Ob = Tb;
    % Cross commutation
    if (i < NL)
      [Ra, Rb] = fn_rdx2rev(Oa, Ob, i, N);
    endif

  endfor  
  % Output buffer
  Dout(1:N/2  ,1) = Oa(:,1);
  Dout(1+N/2:N,1) = Ob(:,1);  

endfunction
%% -------------------------------------------------------------------------- %%