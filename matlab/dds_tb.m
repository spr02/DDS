%% Parameters for DDS
params.len = 1024;                             % number of samples to be generated from dds

params.PHASE_DITHER = false;       % enable phase_acc dithering
params.AMPL_DITHER = true;         % enable amplitude dithering in case of truncation of dds_out
params.TAYLOR = true;              % enable taylor series exapansion of LUT values
params.SWEEP = false;              % do a frequency sweep
params.SWEEP_UP_DOWN = true;      % do linear up and down sweep or only up

% bit widths
params.N_lut_addr = 10;    % LUT size in bit (actual LUT size will be N-2 since we exploit symmertries in sine)
params.N_lut = 16;         % number of data bis in LUT
params.N_adc = 12;         % number of bits of the ADC
params.N_phase = 32;       % number of bits for phase accumulator
params.N_lfsr = 32;        % number of bits for the lfsr (psrn generator)

%lfsr
params.lfsr_poly  = [32 22 2 1];               % polynomial for lfsr
params.lfsr_seed = floor(rand(1) * (pow2(32) - 1));   % random seed for lfsr
% params.lfsr_seed = 12364;
params.latency = 3;                     % needed to account for latency/have the correct lfsr output value

%frequency parameters
params.F_clk = 150e6;                  % clock frequency (150MHz -> max synthesizable frequency is 75MHz)
params.F_0 = -0.15 * params.F_clk;             % frequency to be generated (in case of sweep, the start frequency)
params.F_1 = 0.15 * params.F_clk;              % stop frequency for sweep
F_res = params.F_clk / pow2(params.N_phase);  % calculate frequency resolution in Hz


% calculate phase/frequency tuning word
params.FTW_0 = round(params.F_0 / F_res); % value used to increment the phase accumulator
params.FTW_1 = round(params.F_1 / F_res); % top value in case of sewwp
% FTW_0 = bin2dec('00000001000000000000000000000000');
% FTW_0 = bin2dec('00000001111111111111111111111111');
% FTW_0 = bin2dec('00000001000000000000000000000001');
% params.FTW_0 = 901943132;

F_0_achieved = params.FTW_0 * F_res;


%% get the actual dds output for specified parameters
dds_out = dds(params);

%mix dds_out with delayed version of dds_out to simulate FMCW radar
tau = 300; %delay
dds_out_down = circshift(dds_out, tau); %generate the mixing signal
% dds_out = conj(dds_out) .* dds_out_down;



%% do some plots
figure(1);
clf;
subplot(3, 1, 1);
stairs(real(dds_out));
% xlim([0, 2000])
hold on;
% stairs(dds_out_corr);
tmp = 0:1/params.F_clk:((length(dds_out) - 1)/params.F_clk);
sine_opt = (cos(2*pi*F_0_achieved*tmp) + 1i*sin(2*pi*F_0_achieved*tmp)) * pow2(params.N_adc - 1);
xlabel('Sample No');
ylabel('Amplitude Value');
% plot(real(sine_opt))

subplot(3, 1, 2);
f_vec = (-floor(params.len/2):ceil(params.len/2)-1) * params.F_clk/params.len / 10e5;

h_win = blackmanharris(length(dds_out));
% h_win = flattopwin(length(dds_out));
% h_win = ones(length(dds_out), 1);
spectra = 10 * log10(fftshift( abs(fft(h_win' .* dds_out)).^2 / length(dds_out)) + eps);
spectra_sine = 10 * log10(fftshift( abs(fft(h_win' .*sine_opt)).^2 / length(sine_opt) )) - max(spectra);
spectra = spectra - max(spectra);
plot(f_vec, spectra);
% xlim([0, 2000])
ylim([-130, max(spectra) + 10]);
hold on;
plot(xlim,[mean(spectra) mean(spectra)]);
plot(f_vec, spectra_sine);
xlabel('Frequency [MHz]');
ylabel('Powerdensity [dB]');

[val, pos] = findpeaks(spectra,'NPeaks',2,'SortStr','descend');
plot(f_vec(pos),val,'o','MarkerSize',6);
SFDR = val(1) - val(2)
title(['Spectrum, SFDR = ', num2str(SFDR)]);


subplot(3,1,3);
NFFT = 256;
f_vec = (-floor(NFFT/2):ceil(NFFT/2)-1) * params.F_clk/NFFT;

spectrogram(dds_out, blackmanharris(NFFT), 32, f_vec, params.F_clk, 'yaxis');
% s = spectrogram(dds_out, ones(64, 1), 10, 64, F_clk);
% s = fftshift(s, 1);
% imagesc(abs(s));
% xlabel('Time');
% ylabel('Frequency');



