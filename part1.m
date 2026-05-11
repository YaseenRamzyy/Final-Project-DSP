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
ecg_seg = ecg(1:3000)';

%% Time axis for segment
t = (0:length(ecg_seg)-1)/Fs;

%% Plot segment
figure
plot(t, ecg_seg)

xlabel('Time (s)')
ylabel('Amplitude')
title('ECG Signal Segment')
grid on

%% Baseline wander noise
baseline = 300*sin(2*pi*0.2*t); % simulates breathing

%% Power-line interference (50 Hz)
powerline = 100*sin(2*pi*50*t); % electricity

%% Muscle noise (random noise)
muscle = 50*randn(size(t)); 

%% Create noisy ECG
noisy_ecg = ecg_seg + baseline + powerline + muscle;

%% Plot noisy ECG
figure

subplot(2,1,1)
plot(t, ecg_seg)
title('Original ECG')
xlabel('Time (s)')
ylabel('Amplitude')
grid on

subplot(2,1,2)
plot(t, noisy_ecg)
title('Noisy ECG')
xlabel('Time (s)')
ylabel('Amplitude')
grid on

%% High-pass Butterworth filter

fc = 0.5;          % cutoff frequency
order = 4;         % filter order

[b,a] = butter(order, fc/(Fs/2), 'high');

%% Apply filter
hp_ecg = filtfilt(b,a,noisy_ecg); % filters forw and back

%% Plot result
figure

subplot(2,1,1)
plot(t,noisy_ecg)
title('Before High-Pass Filter')
xlabel('Time (s)')
ylabel('Amplitude')
grid on

subplot(2,1,2)
plot(t,hp_ecg)
title('After High-Pass Filter')
xlabel('Time (s)')
ylabel('Amplitude')
grid on

%% IIR Notch Filter Design

f0 = 50;          % notch frequency
Q = 35;           % quality factor (notch width)

wo = f0/(Fs/2); % normalized freq

bw = wo/Q; % bandwidth

[b_notch,a_notch] = iirnotch(wo,bw);

%% Apply notch filter
notch_ecg = filtfilt(b_notch,a_notch,hp_ecg);

%% Plot results
figure

subplot(2,1,1)
plot(t,hp_ecg)
title('Before Notch Filter')
xlabel('Time (s)')
ylabel('Amplitude')
grid on

subplot(2,1,2)
plot(t,notch_ecg)
title('After Notch Filter')
xlabel('Time (s)')
ylabel('Amplitude')
grid on

%% freq response
figure
freqz(b_notch,a_notch,1024,Fs)
title('Notch Filter Frequency Response')


figure
zplane(b_notch,a_notch)
title('Notch Filter Pole-Zero Plot')

%% =========================================================
%% Low-Pass Butterworth Filter
%% Purpose:
%% Remove high-frequency muscle (EMG) noise
%% =========================================================


%% Low-pass filter specifications
fc_lp = 40;        % Cutoff frequency in Hz
order_lp = 4;      % Filter order

%% Design Butterworth low-pass filter
[b_lp, a_lp] = butter(order_lp, fc_lp/(Fs/2), 'low');

%% Apply low-pass filter
filtered_ecg = filtfilt(b_lp, a_lp, notch_ecg);

%% =========================================================
%% Plot Before and After Low-Pass Filtering
%% =========================================================

figure

subplot(2,1,1)
plot(t, notch_ecg)
title('ECG Before Low-Pass Filter')
xlabel('Time (s)')
ylabel('Amplitude')
grid on

subplot(2,1,2)
plot(t, filtered_ecg)
title('ECG After Low-Pass Filter')
xlabel('Time (s)')
ylabel('Amplitude')
grid on

%% =========================================================
%% Frequency Response of Low-Pass Filter
%% =========================================================

figure
freqz(b_lp, a_lp, 1024, Fs)

title('Low-Pass Filter Frequency Response')

%% =========================================================
%% Pole-Zero Plot
%% =========================================================

figure
zplane(b_lp, a_lp)

title('Low-Pass Filter Pole-Zero Plot')

%% =========================================================
%% Impulse Response
%% =========================================================

figure
impz(b_lp, a_lp)

title('Impulse Response of Low-Pass Filter')

%% =========================================================
%% Step Response
%% =========================================================

figure
stepz(b_lp, a_lp)

title('Step Response of Low-Pass Filter')

%% =========================================================
%% Final ECG Comparison
%% =========================================================

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
plot(t, filtered_ecg)
title('Filtered ECG Signal')
xlabel('Time (s)')
ylabel('Amplitude')
grid on


%% =========================================================
%% FIR Low-Pass Filter Design Using Hamming Window
%% =========================================================

clc;

%% FIR filter specifications
fir_order = 60;      % FIR filter order
fc_fir = 40;         % Cutoff frequency in Hz

%% Design FIR filter
b_fir = fir1(fir_order, fc_fir/(Fs/2), 'low', hamming(fir_order+1));

%% Apply FIR filter
fir_ecg = filtfilt(b_fir, 1, noisy_ecg);

%% =========================================================
%% Plot FIR Filtering Results
%% =========================================================

figure

subplot(2,1,1)
plot(t, noisy_ecg)
title('Noisy ECG Signal')
xlabel('Time (s)')
ylabel('Amplitude')
grid on

subplot(2,1,2)
plot(t, fir_ecg)
title('FIR Filtered ECG Signal')
xlabel('Time (s)')
ylabel('Amplitude')
grid on
%% =========================================================
%% FIR Frequency Response
%% =========================================================

figure
freqz(b_fir,1,1024,Fs)

title('FIR Filter Frequency Response')
%% =========================================================
%% FIR Pole-Zero Plot
%% =========================================================

figure
zplane(b_fir,1)

title('FIR Filter Pole-Zero Plot')
%% =========================================================
%% FIR Impulse Response
%% =========================================================

figure
impz(b_fir,1)

title('FIR Filter Impulse Response')