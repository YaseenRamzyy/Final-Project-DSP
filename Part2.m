fprintf('=== Multi-Band Speech Equalizer ===\n');

% 1) Read Audio File
file = input('Enter audio file name: ', 's'); 
if ~isfile(file)
    error('File not found!'); 
    % Stop execution if file does not exist
end

[x, Fs] = audioread(file); %x=audio signal samples
% Fs=sampling frequency (samples per second)

% Convert stereo to mono if needed
if size(x,2) == 2
    x = mean(x,2); % Average left and right channels
end

fprintf('Loaded successfully!\n'); 


% 2) User Inputs


type = upper(input('Filter type (FIR / IIR): ', 's')); % Get filter type from user and convert to uppercase

order = input('Enter filter order: '); 

outFs = input('Enter output sample rate: '); 

% care
if strcmp(type, 'FIR')
    fprintf('Window types: hamming / hanning / blackman\n');
    win_type = lower(input('Choose window type: ', 's'));
else

    fprintf('IIR types: butter / cheby1 / cheby2\n');
    iir_type = lower(input('Choose IIR filter type: ', 's'));
    % cheby1 and cheby2 need a ripple value in dB
    if strcmp(iir_type, 'cheby1') || strcmp(iir_type, 'cheby2')
        ripple = input('Enter ripple in dB (try 1 for cheby1, 40 for cheby2): ');
    end
end


% 3) >>>>>>>>>> ADDED: Mode Selection (Preset or Custom) 

fprintf('\nModes: preset / custom\n');
mode = lower(input('Choose mode: ', 's'));

if strcmp(mode, 'preset')

    % Preset Frequency Bands
    bands = [0 100; 100 300; 300 800; 800 2000; 2000 5000; 5000 10000; 10000 20000];
    % Standard 7 speech frequency bands

    n = size(bands,1);      % el bands 3bara 3n matrix
    % Number of frequency bands

    fprintf('\nEnter gain (dB) for each band:\n');

    gains = zeros(1,n);
    % Initialize gains array

    for i = 1:n
        gains(i) = input(sprintf('Band %d (%d-%d Hz): ', ...
            i, bands(i,1), bands(i,2)));
        % Get gain value(in dB)for each band
    end

else
    % ---- ADDED: Custom Mode
    % user defines their own bands
    % project rules: min 5 bands, max 10 bands, start at 0 Hz, end at 20000 Hz

    n = input('How many bands? (5 to 10): ');
    n = max(5, min(10, n)); % clamp between 5 and 10

    bands = zeros(n, 2);
    bands(1,1) = 0; % first band must start at 0 Hz

    fprintf('Enter the upper edge of each band in Hz:\n');
    for i = 1:n-1
        edge = input(sprintf('Upper edge of band %d (Hz): ', i));
        bands(i, 2)   = edge;   % this band ends here
        bands(i+1, 1) = edge;   % next band starts here
    end
    bands(end, 2) = 20000; % last band must end at 20000 Hz

    gains = zeros(1,n);
    fprintf('\nEnter gain (dB) for each band:\n');
    for i = 1:n
        gains(i) = input(sprintf('Band %d (%g-%g Hz): ', i, bands(i,1), bands(i,2)));
    end

end

% Gains are values entered by the user for each frequency band.
% These values control whether we increase or decrease the sound level
% in a specific frequency range.
% Example:
% +3 dB-> increase the volume of this band
% -3 dB-> decrease the volume of this band
% Each frequency band is adjusted separately,
% then all bands are combined again to create the final equalized signal.



% 4) Filter Design

b = cell(1,n); %Numerator coefficients for each filter
a = cell(1,n); %Denominator coefficients for each filter

for i = 1:n
    
    % Normalize frequencies (range 0 to 1, where 1 = Nyquist frequency)
    low = bands(i,1)/(Fs/2);
    high = bands(i,2)/(Fs/2);

    % Ensure valid range to avoid errors  mynf3sh 0 wla 1
    low = max(low,0.001);
    high = min(high,0.999);

    if strcmp(type,'FIR')
        % FIR filter design
        
        if strcmp(win_type, 'hanning')
            w = hanning(order+1);
        elseif strcmp(win_type, 'blackman')
            w = blackman(order+1);
        else
            w = hamming(order+1); % default to hamming
        end

        if low < 0.01
            b{i} = fir1(order, high, 'low', w);
            % Lowpass filter for first band
        else
            % >>>>>>>>>> FIXED: added 'bandpass' and window to fir1 <<<<<<<<<<
            % before it was: fir1(order, [low high]) — missing both
            b{i} = fir1(order, [low high], 'bandpass', w);
            % Bandpass filter
        end
        a{i} = 1; % FIR filters have no feedback

    else

        %supports butter, cheby1, cheby2 
        %w hn3ml try and catch 3ashan el error

        try
            if low < 0.01
                % lowpass for first band
                if strcmp(iir_type, 'cheby1')
                    [b{i},a{i}] = cheby1(order, ripple, high, 'low');
                elseif strcmp(iir_type, 'cheby2')
                    [b{i},a{i}] = cheby2(order, ripple, high, 'low');
                else
                    [b{i},a{i}] = butter(order, high, 'low');
                end
            else
                % bandpass for all other bands
                if strcmp(iir_type, 'cheby1')
                    [b{i},a{i}] = cheby1(order, ripple, [low high], 'bandpass');
                elseif strcmp(iir_type, 'cheby2')
                    [b{i},a{i}] = cheby2(order, ripple, [low high], 'bandpass');
                else
                    [b{i},a{i}] = butter(order, [low high]);
                end
            end
        catch
            % error handling if IIR fails
            % high order IIR on narrow bands can crash, so we reduce order to 4
            warning('Band %d failed with order %d, retrying with order 4', i, order);
            if low < 0.01
                [b{i},a{i}] = butter(4, high, 'low');
            else
                [b{i},a{i}] = butter(4, [low high]);
            end
        end
    end
end

fprintf('Filters designed!\n');


% =========================================
% Filter Analysis Plots
% =========================================

for i = 1:n

    figure;

   
    % Magnitude + Phase Response
   
    subplot(2,2,1);

    freqz(b{i}, a{i}, 1024, Fs);
    title(['Frequency Response - Band ' num2str(i)]);
    % Shows magnitude and phase response

   
    % Impulse Response
   
    subplot(2,2,2);

    impz(b{i}, a{i});
    title(['Impulse Response - Band ' num2str(i)]);
    % Response of filter to one impulse

    % Step Response

    subplot(2,2,3);

    stepz(b{i}, a{i});
    title(['Step Response - Band ' num2str(i)]);
    % Response of filter to step input

   
    % Pole-Zero Plot

    subplot(2,2,4);

    zplane(b{i}, a{i});
    title(['Pole-Zero Plot - Band ' num2str(i)]);
    % Shows poles and zeros of the filter

end



% 5) Apply Filters and Gains

y = zeros(length(x),1); 
% Create empty output signal
% Same length as the original audio signal

for i = 1:n
    
    temp = filter(b{i}, a{i}, x); 
    % Pass the signal through the filter
    % This extracts only the frequencies of this band
    
    gain = 10^(gains(i)/20); 
    % Convert gain from dB to linear scale
    % Example:
    % +6 dB ? 2x louder
    % -6 dB ? half volume
    
    y = y + temp * gain; 
    % Apply gain to the filtered signal
    % Then add it to the final output
end

% Normalize signal to avoid clipping
% Clipping happens when values exceed 1 or -1
% normalize only if signal exceeds valid range
% we only normalize if clipping would actually happen
if max(abs(y)) > 1
    y = y / max(abs(y));
    fprintf('Output normalized to avoid clipping\n');
end
fprintf('Processing done!\n');


% 6) Resampling

if outFs ~= Fs
    y_out = resample(y, outFs, Fs);
    % Change the sample rate of the signal
    % y3ny bos
    % 44100 -> 88200 (upsampling)
    % 44100 -> 22050 (downsampling)
else
    y_out = y;
end

% 7) Save Output

audiowrite('output.wav', y_out, outFs); 
% Save the processed audio signal as a WAV file

fprintf('Saved as output.wav\n');

%----------Save 4x and half sample rate versions
% demonstrating both upsampling and downsampling

y_4x   = resample(y, 4, 1);         % multiply sample rate by 4    y*4/1
y_half = resample(y, 1, 2);         % divide sample rate by 2      y*1/2
     
audiowrite('output_4x.wav',   max(-1, min(1, y_4x)),Fs*4);
audiowrite('output_half.wav', max(-1, min(1, y_half)),Fs/2);

fprintf('Saved output_4x.wav at %d Hz\n',Fs*4);
fprintf('Saved output_half.wav at %d Hz\n',Fs/2);

% 8) Analysis Plots


% -------- Time Domain --------
% Compare original signal and equalized signal

figure;

subplot(2,1,1);
plot(x); 
title('Original Signal'); 
% Plot original waveform

subplot(2,1,2);
plot(y); 
title('Equalized Signal'); 
% Plot processed waveform

% ----------------------------------------------------------

% Power Spectral Density (PSD)

% PSD shows how signal power is distributed across frequencies

% hn3ml comparison using 2 subplots
figure
subplot(1,2,1);
pwelch(x,[],[],[],Fs);
title('Original PSD');
% Frequency content of original signal
 
subplot(1,2,2);
pwelch(y,[],[],[],Fs);   % use y at original Fs for fair comparison
title('Equalized PSD');
% Frequency content after equalization
 
sgtitle('Power Spectral Density (Welch Method)');

% PSD comparison for all sample rates
% showing PSD at original, 4x, and half rates

figure;

subplot(1,3,1);
pwelch(y,[],[],[],Fs);
title(['Original Rate: ' num2str(Fs) ' Hz']);

subplot(1,3,2);
pwelch(y_4x,[],[],[],Fs*4);
title(['4x Rate: ' num2str(Fs*4) ' Hz']);

subplot(1,3,3);
pwelch(y_half,[],[],[],Fs/2);
title(['Half Rate: ' num2str(Fs/2) ' Hz']);

sgtitle('PSD at Different Output Sample Rates');

% Spectrogram
% ================================
% Spectrogram shows frequency changes over time

figure;
subplot(1,2,1);
spectrogram(x, 256, 200, 512, Fs, 'yaxis');
title('Original Spectrogram');
% Original audio spectrogram
 
subplot(1,2,2);
spectrogram(y, 256, 200, 512, Fs, 'yaxis');
title('Equalized Spectrogram');
% Processed audio spectrogram
 
sgtitle('Spectrogram (STFT)');


% 9) Play Audio
% ================================


ans1 = input('Play original signal? (y/n): ', 's');
if strcmpi(ans1, 'y')
    sound(x, Fs);
    % Play original audio
    pause(length(x)/Fs + 1);
    % et2al until playback finishes
end
 
ans2 = input('Play equalized signal? (y/n): ', 's');
if strcmpi(ans2, 'y')
    sound(y_out, outFs);
    % Play equalized audio
    pause(length(y_out)/outFs + 1);
end
 
fprintf('Done!\n');
