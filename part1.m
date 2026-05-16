clc;
clear;
close all;

%% Sampling frequency
Fs = 360;

%% Open ECG file
fid = fopen('100.dat','r'); % file identifier that reads ecg binary file

%% Read data
A = fread(fid,[3 inf],'uint8')'; % func reads the data from ecg (3 values at a time) bec ecg is encoded in binary formats

%% Close file
fclose(fid);

%% Convert to ECG signal
M2H = bitshift(A(:,2), -4); % decoding convert back to binary (bits) - upper bits
M1H = bitand(A(:,2), 15); % lower bits

PRL = bitshift(M1H,8) + A(:,1); % reconstruct ecg signal
PRR = bitshift(M2H,8) + A(:,1);

ecg = PRL; % final signal

%% Remove DC offset
ecg = ecg - mean(ecg); % remove dc offset

%% Create time axis
t = (0:length(ecg)-1)/Fs;

%% Plot ECG

%% Take small ECG segment
ecg_seg = ecg(1:6000)';

%% Time axis for segment
t = (0:length(ecg_seg)-1)/Fs;

%% =========================================================
%% CREATE NOISY ECG
%% =========================================================

baseline = 100*sin(2*pi*0.2*t); % simulates breathing

powerline = 50*sin(2*pi*50*t); % electricity

muscle = 30*randn(size(t));

noisy_ecg = ecg_seg + baseline + powerline + muscle;

%% Plot segment
figure
subplot(2,1,1)
plot(t, ecg_seg)

xlabel('Time (s)')
ylabel('Amplitude')
title('ECG Signal Segment')

grid on

subplot(2,1,2)
plot(t,noisy_ecg)
title('Noisy ECG')

xlabel('Time (s)')
ylabel('Amplitude')

grid on

%% =========================================================
%% NOTCH FILTER DESIGN
%% =========================================================

f0 = 50;
Q = 35;

wo = f0/(Fs/2);

bw = wo/Q;

[b_notch,a_notch] = iirnotch(wo,bw);

%% Apply Notch Filter
notch_ecg = filtfilt(b_notch,a_notch,noisy_ecg);

%% =========================================================
%% FIR FILTER DESIGN
%% =========================================================

fir_order = 100;

fc_fir = 40;

b_fir = fir1(fir_order, ...
    fc_fir/(Fs/2), ...
    'low', ...
    hamming(fir_order+1));

%% Apply FIR Filter
fir_ecg = filtfilt(b_fir,1,noisy_ecg);

%% =========================================================
%% CHEBYSHEV FILTER ANALYSIS
%% =========================================================

%% Filter specifications
fc_cheby = 0.5;        % Cutoff frequency in Hz
order_cheby = 4;       % Filter order
Rp = 0.5;              % Passband ripple in dB
%% Design Chebyshev Type-I High-Pass Filter
[b_cheby, a_cheby] = cheby1(order_cheby, Rp, fc_cheby/(Fs/2), 'high');

%% =========================================================
%% FINAL ECG USING ALL FILTERS
%% =========================================================

filtered1 = filtfilt(b_notch,a_notch,noisy_ecg);

filtered2 = filtfilt(b_fir,1,filtered1);

final_ecg = filtfilt(b_cheby,a_cheby,filtered2);

%% =========================================================
%% SNR CALCULATION
%% =========================================================

noise_before = noisy_ecg - ecg_seg;

noise_after = final_ecg - ecg_seg;

snr_before = 10*log10(sum(ecg_seg.^2) / sum(noise_before.^2));

snr_after = 10*log10(sum(ecg_seg.^2) / sum(noise_after.^2));


%% =========================================================
%% INTERACTIVE MENU
%% =========================================================

while true

choice = menu('ECG Signal Processing Menu', ...
    '1. Notch Filter Analysis', ...
    '2. FIR Filter Analysis', ...
    '3. Chebyshev Filter Analysis', ...
    '4. Final Filtered ECG', ...
    '5. PSD Analysis', ...
    '6. Spectrogram Analysis', ...
    '7. SNR Analysis', ...
    '8. Exit');

%% =========================================================
%% MENU SWITCH
%% =========================================================

switch choice

%% =========================================================
case 1
%% NOTCH FILTER ANALYSIS

disp('Notch Filter Numerator Coefficients:')
disp(b_notch)

disp('Notch Filter Denominator Coefficients:')
disp(a_notch)

figure

subplot(2,1,1)
plot(t,noisy_ecg)
title('Noisy ECG')

xlabel('Time (s)')
ylabel('Amplitude')

grid on

subplot(2,1,2)
plot(t,notch_ecg)
title('ECG After Notch Filter')

xlabel('Time (s)')
ylabel('Amplitude')

grid on

figure
freqz(b_notch,a_notch,1024,Fs)

title('Notch Filter Frequency Response')

figure
zplane(b_notch,a_notch)

title('Notch Filter Pole-Zero Plot')

figure
impz(b_notch,a_notch,100)

title('Notch Filter Impulse Response')

figure
stepz(b_notch,a_notch,100)

title('Notch Filter Step Response')


% Frequency response
[H_notch,f_notch] = freqz(b_notch,a_notch,1024,Fs);

mag_notch = 20*log10(abs(H_notch));

% Passband frequencies
passband_notch = (f_notch < 45) | (f_notch > 55);

% Stopband around 50 Hz
stopband_notch = (f_notch >= 49.9) & (f_notch <= 50.1);

% Passband ripple
passband_ripple_notch = ...
    max(mag_notch(passband_notch)) - ...
    min(mag_notch(passband_notch));

% Stopband attenuation
stopband_attenuation_notch = ...
    -max(mag_notch(stopband_notch));

fprintf('\n====================================\n')
fprintf('NOTCH FILTER VERIFICATION\n')
fprintf('====================================\n')

fprintf('Passband Ripple = %.2f dB\n', ...
    passband_ripple_notch)

fprintf('Stopband Attenuation = %.2f dB\n', ...
    stopband_attenuation_notch)

fprintf('Cutoff Frequency = %d Hz\n', f0)

fprintf('Filter Order = %d\n', ...
    length(a_notch)-1)
fprintf('\n====================================\n')


%% =========================================================
case 2
%% FIR FILTER ANALYSIS

disp('FIR Filter Coefficients:')
disp(b_fir)

figure

subplot(2,1,1)
plot(t,noisy_ecg)
title('Noisy ECG')

xlabel('Time (s)')
ylabel('Amplitude')

grid on

subplot(2,1,2)
plot(t,fir_ecg)
title('ECG After FIR Filter')

xlabel('Time (s)')
ylabel('Amplitude')

grid on

figure
freqz(b_fir,1,1024,Fs)

title('FIR Frequency Response')

figure
zplane(b_fir,1)

title('FIR Pole-Zero Plot')

figure
impz(b_fir,1)

title('FIR Impulse Response')

figure
stepz(b_fir,1)

title('FIR Step Response')

% Frequency response
[H_fir,f_fir] = freqz(b_fir,1,1024,Fs);

mag_fir = 20*log10(abs(H_fir));

% Passband
passband_fir = f_fir <= 35;

% Stopband
stopband_fir = f_fir >= 45;

% Passband ripple
passband_ripple_fir = ...
    max(mag_fir(passband_fir)) - ...
    min(mag_fir(passband_fir));

% Stopband attenuation
stopband_attenuation_fir = ...
    -max(mag_fir(stopband_fir));

fprintf('\n====================================\n')
fprintf('FIR FILTER VERIFICATION\n')
fprintf('====================================\n')

fprintf('Passband Ripple = %.2f dB\n', ...
    passband_ripple_fir)

fprintf('Stopband Attenuation = %.2f dB\n', ...
    stopband_attenuation_fir)

fprintf('Cutoff Frequency = %.2f Hz\n', ...
    fc_fir)

fprintf('Filter Order = %d\n', ...
    fir_order)
fprintf('\n====================================\n')


%% =========================================================
case 3
    
%% FIR FILTER ANALYSIS

%% Display filter coefficients

disp('Chebyshev High-Pass Filter Numerator Coefficients:')
disp(b_cheby)
disp('Chebyshev High-Pass Filter Denominator Coefficients:')
disp(a_cheby)
%% Apply Chebyshev Filter

cheby_ecg = filtfilt(b_cheby, a_cheby, noisy_ecg);
%% Plot Before and After Filtering

figure
subplot(2,1,1)
plot(t, noisy_ecg)
title('ECG Before Chebyshev High-Pass Filter')
xlabel('Time (s)')
ylabel('Amplitude')
grid on
subplot(2,1,2)
plot(t, cheby_ecg)
title('ECG After Chebyshev High-Pass Filter')
xlabel('Time (s)')
ylabel('Amplitude')
grid on
%% Magnitude and Phase Response

figure
freqz(b_cheby, a_cheby, 1024, Fs)
title('Chebyshev High-Pass Filter Frequency Response')
%% Pole-Zero Plot

figure
zplane(b_cheby, a_cheby)
title('Chebyshev High-Pass Filter Pole-Zero Plot')
%% Impulse Response

figure
impz(b_cheby, a_cheby)
title('Impulse Response of Chebyshev High-Pass Filter')
%% Step Response

figure
stepz(b_cheby, a_cheby)
title('Step Response of Chebyshev High-Pass Filter')

%% Verify Filter Specifications

% Frequency response data
[H, f] = freqz(b_cheby, a_cheby, 1024, Fs);
magnitude_dB = 20*log10(abs(H));
figure
plot(f, magnitude_dB)
xlabel('Frequency (Hz)')
ylabel('Magnitude (dB)')
title('Chebyshev High-Pass Filter Magnitude Response')
grid on
%% Passband and Stopband Verification

passband = f >= 1;      % frequencies above cutoff
stopband = f <= 0.2;    % low-frequency noise region
passband_ripple = max(magnitude_dB(passband)) - ...
                  min(magnitude_dB(passband));
stopband_attenuation = -max(magnitude_dB(stopband));
fprintf('\nFilter Verification\n')
fprintf('Passband Ripple = %.2f dB\n', passband_ripple)
fprintf('Stopband Attenuation = %.2f dB\n', ...
         stopband_attenuation)
fprintf('Cutoff Frequency = %.2f Hz\n', fc_cheby)
fprintf('Filter Order = %d\n', order_cheby)
fprintf('\n====================================\n')

%% Compare Original, Noisy, and Chebyshev Filtered ECG

figure
subplot(3,1,1)
plot(t, ecg_seg)
title('Original ECG Signal')
xlabel('Time (s)')
ylabel('Amplitude')
grid on
subplot(3,1,2)
plot(t, noisy_ecg)
title('Noisy ECG Signal')
xlabel('Time (s)')
ylabel('Amplitude')
grid on
subplot(3,1,3)
plot(t, cheby_ecg)
title('Chebyshev High-Pass Filtered ECG')
xlabel('Time (s)')
ylabel('Amplitude')
grid on


%% =========================================================
case 4
%% FINAL FILTERED ECG

figure

subplot(3,1,1)
plot(t,ecg_seg)

title('Original ECG')

xlabel('Time (s)')
ylabel('Amplitude')

grid on

subplot(3,1,2)
plot(t,noisy_ecg)

title('Noisy ECG')

xlabel('Time (s)')
ylabel('Amplitude')

grid on

subplot(3,1,3)
plot(t,final_ecg)

title('Final Filtered ECG')

xlabel('Time (s)')
ylabel('Amplitude')

grid on

%% =========================================================
case 5
%% PSD ANALYSIS

figure

subplot(2,1,1)

pwelch(noisy_ecg,[],[],[],Fs)

title('PSD of Noisy ECG')

subplot(2,1,2)

pwelch(final_ecg,[],[],[],Fs)

title('PSD of Final Filtered ECG')

%% =========================================================
case 6
%% SPECTROGRAM

figure

spectrogram(noisy_ecg,256,200,512,Fs,'yaxis')
colorbar
caxis([-80 40])


title('Spectrogram of Noisy ECG')

figure

spectrogram(final_ecg,256,200,512,Fs,'yaxis')
colorbar
caxis([-80 40])
title('Spectrogram of Final Filtered ECG')

%% =========================================================
case 7
%% SNR ANALYSIS

fprintf('\n====================================\n')

fprintf('SNR RESULTS\n')

fprintf('====================================\n')

fprintf('SNR Before Filtering = %.2f dB\n', ...
    snr_before)

fprintf('SNR After Filtering = %.2f dB\n', ...
    snr_after)

fprintf('SNR Improvement = %.2f dB\n', ...
    snr_after - snr_before)

%% =========================================================
case 8
%% EXIT

disp('Exiting Program...')

break

end

end