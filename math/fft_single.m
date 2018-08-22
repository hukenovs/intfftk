%% -----------------------------------------------------------------------
%
% Title       : fft_single.m
% Author      : Alexander Kapitanov	
% Company     : AO Insys
% E-mail      : sallador@bk.ru 
% Version     : 1.0	 
%
%-------------------------------------------------------------------------
%
% Description : 
%    Top level for testing Forward Fourier Transform
%
%-------------------------------------------------------------------------
%
% Version     : 1.0 
% Date        : 2015.12.12 
%
%-------------------------------------------------------------------------	   

% Preparing to work
close all;
clear all;

set(0, 'DefaultAxesFontSize', 14, 'DefaultAxesFontName', 'Times New Roman');
set(0, 'DefaultTextFontSize', 14, 'DefaultTextFontName', 'Times New Roman'); 

% Settings
NFFT = 2^10;            % Sampling Frequency
t = 0:1/NFFT:1-1/NFFT;  % Time vector #1
tt = 1:NFFT;            % Time vector #2

Asig = (2^(5))-1;
Fsig = 1;

Fd = 1;
B = 0.65;
% For testing FORWARD and INVERSE FFT: FWT

STAGE = log2(NFFT);

%% -------------------------------------------------------------------------- %%
% ---------------- 0: CREATE INPUT DATA FOR CPP/RTL -------------------------- % 
%% -------------------------------------------------------------------------- %%
F = 129;

for i = 1:NFFT
  Dre(i,1) = round(Asig * cos(F * (i-1) * 2 * pi / NFFT) + Asig * 4 * cos((F+8) * (i-1) * 2 * pi / NFFT));
  Dim(i,1) = round(Asig * sin(F * (i-1) * 2 * pi / NFFT) + Asig * 4 * sin((F+8) * (i-1) * 2 * pi / NFFT)); 
  
  Dre(i,1) = round(Asig * cos((Fsig*(i-1) + B*(i-1)*(i-1)/2) * 2*pi/NFFT) * sin((i-1) * 1 * pi / NFFT));
  Dim(i,1) = round(Asig * sin((Fsig*(i-1) + B*(i-1)*(i-1)/2) * 2*pi/NFFT) * sin((i-1) * 1 * pi / NFFT)); 
  
  if (i == F) 
    Dre(i,1) = Asig;
    Dim(i,1) = 0;  
  else
    Dre(i,1) = 0;
    Dim(i,1) = 0;   
  end 
  Dre(i,1) = round(Asig * cos(F * (i-1) * 2 * pi / NFFT));
  Dim(i,1) = round(Asig * sin(F * (i-1) * 2 * pi / NFFT));  

 

end


% Adding noise to real signal 
SNR = -35;
SEED = 1;

DatRe = awgn(Dre, SNR, 0, SEED);     
DatIm = awgn(Dim, SNR, 0, SEED);     

DSVRe = round(DatRe);
DSVIm = round(DatIm);


Mre = max(abs(DatRe));
Mim = max(abs(DatIm));
Mdt = max(Mre, Mim);

DSVRe = round(((Asig)/Mdt)*DatRe);
DSVIm = round(((Asig)/Mdt)*DatIm);
%DSVRe = round(DatRe);
%DSVIm = round(DatIm);
DSV(:,1) = DSVRe;
DSV(:,2) = DSVIm;



% Save data to file
fid = fopen ("di_single.dat", "w");
for i = 1:NFFT/1
    fprintf(fid, "%d %d\n",  DSVRe(i,1), DSVIm(i,1));
end
fclose(fid);

Di = DSV(:,1) + 1i*DSV(:,2);
Dx = fft(Di);
Dxre = real(Dx);
Dxim = imag(Dx);

DSX(:,1) = Dxre;
DSX(:,2) = Dxim;

figure(1) % 
for i = 1:2
  subplot(2,2,i)
  plot(tt(1:NFFT), DSV(1:NFFT,i), '-', 'LineWidth', 1, 'Color',[2-i 0  i-1])
  grid on
  axis tight 
  title(['Input data (time)'])  
end

figure(1) % 
for i = 1:2
  subplot(2,2,i+2)
  plot(tt(1:NFFT), DSX(1:NFFT,i), '-', 'LineWidth', 1, 'Color',[2-i 0  i-1])
  grid on
  axis tight 
  title(['FFT data (freq)'])  
end
