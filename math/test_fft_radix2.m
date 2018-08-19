%% -------------------------------------------------------------------------- %%
%
% Title       : fft_radix2.m
% Author      : Alexander Kapitanov	
% Company     : Insys
% E-mail      : sallador@bk.ru 
% Version     : 1.0	 
%
%---------------------------------------------------------------------------- %%
%
% Description : 
%    Radix-2 model for FFT / IFFT core
%
%---------------------------------------------------------------------------- %%
%
% Version     : 1.0 
% Date        : 2018.06.03
%
%
%% -------------------------------------------------------------------------- %%

% Preparing to work
close all; clear all;
set(0, 'DefaultAxesFontSize', 14, 'DefaultAxesFontName', 'Times New Roman');
set(0, 'DefaultTextFontSize', 14, 'DefaultTextFontName', 'Times New Roman'); 


% Settings
NFFT = 2^7;

Asig = 2^8-1;
Fsig = 24;
Fm = 1*(NFFT/1);
B = 0.95;

%% -------------------------------------------------------------------------- %%
% ---------------- 0: CREATE INPUT DATA FOR CPP/RTL -------------------------- %
%% -------------------------------------------------------------------------- %%

for i = 1:NFFT

  Dre(i,1) = Asig * cos(Fsig*(i-1)* 2*pi/NFFT);
  Dim(i,1) = Asig * sin(Fsig*(i-1)* 2*pi/NFFT);
  
  Dre(i,1) = round(Asig * cos((Fsig*(i-1) + B*(i-1)*(i-1)/2) * 2*pi/NFFT) * sin((i-1) * 1 * pi / NFFT));
  Dim(i,1) = round(Asig * sin((Fsig*(i-1) + B*(i-1)*(i-1)/2) * 2*pi/NFFT) * sin((i-1) * 1 * pi / NFFT));   
% 
%  if (i == 2)
%    Dre(i,1) = 1;
%    Dim(i,1) = 0;
%  else
%    Dre(i,1) = 0;
%    Dim(i,1) = 0;  
%  endif
%  Dre(i,1) = i-1;
%  Dim(i,1) = 0;
end



% Adding noise to real signal 
SNR = 50;
SEED = 1;

DatRe = awgn(Dre, SNR, 0, SEED);     
DatIm = awgn(Dim, SNR, 0, SEED);     

Mre = max(abs(DatRe));
Mim = max(abs(DatIm));
Mdt = max(Mre, Mim);

% DSVRe = round(((2^15 - 1)/Mdt)*DatRe);
% DSVIm = round(((2^15 - 1)/Mdt)*DatIm);
Dre = round(DatRe);
Dim = round(DatIm);

Din = Dre + 1i*Dim;
Din_Dat(:,1) = real(Din);
Din_Dat(:,2) = imag(Din);

clear Mre; clear Mim; clear Mdt;
clear DatRe; clear DatIm; 
clear SEED; clear SNR;

%% -------------------------------------------------------------------------- %%
% ---------------- 1: Etalon FFT / IFFT algorithm  --------------------------- %
%% -------------------------------------------------------------------------- %%

Ff_Dt = fft(Din, NFFT);
Ff_Dat(:,1) = real(Ff_Dt);
Ff_Dat(:,2) = imag(Ff_Dt);

Fi_Dt = ifft(Ff_Dt, NFFT);
Fi_Dat(:,1) = real(Fi_Dt);
Fi_Dat(:,2) = imag(Fi_Dt);


%% -------------------------------------------------------------------------- %%
% ---------------- 2: Testing FFT / IFFT algorithm  -------------------------- %
%% -------------------------------------------------------------------------- %%

Dfft = fn_radix2(Din, NFFT, 'FWD');

Df_Dat(:,1) = real(Dfft);
Df_Dat(:,2) = imag(-Dfft);

Difft = fn_radix2(Dfft, NFFT, 'INV');

Di_Dat(:,1) = real(Difft);
Di_Dat(:,2) = imag(Difft);

figure(1) % Plot Support function data in Time Domain
for i = 1:2
    subplot(2,2,i)
    plot(Ff_Dat(:,i), '-', 'LineWidth', 1, 'Color',[2-i 0  i-1])
    grid on
    hold on
    axis tight 
    subplot(2,2,i+2)
    plot(Df_Dat(:,i), '-', 'LineWidth', 1, 'Color',[2-i 0  i-1])
    grid on
    hold on
    axis tight       
%    title(['Support function in T/F Domain'])   
end

figure(2) % Plot Support function data in Time Domain
for i = 1:2
    subplot(2,2,i)
    plot(Din_Dat(:,i), '-', 'LineWidth', 1, 'Color',[2-i 0  i-1])
    grid on
    hold on
    axis tight 
    subplot(2,2,i+2)
    plot(Di_Dat(:,i), '-', 'LineWidth', 1, 'Color',[2-i 0  i-1])
    grid on
    hold on
    axis tight       
%    title(['Support function in T/F Domain'])   
end
