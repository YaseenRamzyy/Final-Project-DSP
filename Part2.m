fprintf('=== Multi-Band Speech Equalizer ===\n'); % Display program title

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


% 3) Preset Frequency Bands

bands = [0 100; 100 300; 300 800; 800 2000; 2000 5000; 5000 10000; 10000 20000]; 
% Standard 7 speech frequency bands   

n = size(bands,1);       % el bands 3bara 3n matrix
% Number of frequency bands

fprintf('\nEnter gain (dB) for each band:\n');

gains = zeros(1,n); 
% Initialize gains array

for i = 1:n
    gains(i) = input(sprintf('Band %d (%d-%d Hz): ', ...    
        i, bands(i,1), bands(i,2))); % kda el user byktb el gain w yd5lo gwa el array
    % Get gain value (in dB) for each band
end

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
        
        if low < 0.01
            b{i} = fir1(order, high, 'low'); 
            % Lowpass filter for first band bec we can't make band pass for
            % the first
        else
            b{i} = fir1(order, [low high]); 
            % Bandpass filter
        end
        
        a{i} = 1; % FIR filters have no feedback
        
    else
        % IIR filter design (Butterworth)
        if low < 0.01
            [b{i},a{i}] = butter(order, high, 'low'); 
            else0
            [b{i},a{i}] = butter(order, [low high]); 
        end
    end
end

fprintf('Filters designed!\n');


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
y = y / max(abs(y));

fprintf('Processing done!\n');
