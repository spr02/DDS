%% Parameters for DDS
len = 1000;                             % number of samples to be generated from dds

DITHERING = false;           % enable phase_acc dithering
TAYLOR = true;              % enable taylor series exapansion of LUT values
SWEEP = false;              % do a frequency sweep
SWEEP_UP_DOWN = false;      % do linear up and down sweep or only up

% bit widths
N_lut_addr = 10;    % LUT size in bit (actual LUT size will be N-2 since we exploit symmertries in sine)
N_lut = 16;         % number of data bis in LUT
N_adc = 12;         % number of bits of the ADC
N_phase = 32;       % number of bits for phase accumulator
N_lfsr = 32;        % number of bits for the lfsr (psrn generator)

%lfsr
lfsr_poly  = [32 22 2 1];               % polynomial for lfsr
% lfsr_seed = floor(rand(1) * (pow2(32) - 1));   % random seed for lfsr
lfsr_seed = 12364;
tmp = lfsr(lfsr_seed, lfsr_poly, N_lfsr, N_lfsr, 3); % account for latency (i.e. use other seed)
lfsr_seed = tmp(end);

%frequency parameters
F_clk = 150e6;                  % clock frequency (150MHz -> max synthesizable frequency is 75MHz)
F_0 = 0.21 * F_clk;             % frequency to be generated (in case of sweep, the start frequency)
F_1 = 0.25 * F_clk;              % stop frequency for sweep
F_res = F_clk / pow2(N_phase);  % calculate frequency resolution in Hz


%% calculate phase/frequency tuning word
FTW_0 = round(F_0 / F_res);             % frequency tuning word, value used to increment the phase accumulator
FTW_1 = round(F_1 / F_res);
% FTW_0 = bin2dec('00000001000000000000000000000000');
% FTW_0 = bin2dec('00000001111111111111111111111111');
% FTW_0 = bin2dec('00000001000000000000000000000001');
FTW_0 = 901943132;
diff = (FTW_1 - FTW_0) / (len / 2);
F_0_achieved = FTW_0 * F_res;


%% generate phase_accumulator for sine and cosine

phase_acc = zeros(1, len);
if SWEEP == true
    for i=2:len
        phase_acc(i) = phase_acc(i-1) + FTW_0;
%         FTW_0 = FTW_0 + diff;
        if i < len/2
            FTW_0 = FTW_0 + diff;
        else
            FTW_0 = FTW_0 - diff;
        end
    end
else
%     phase_acc = mod(0:FTW_0:FTW_0*len-1, pow2(N_phase));
    for i=2:len
       phase_acc(i) = phase_acc(i-1) + FTW_0;
    end
end
phase_acc = mod(phase_acc, pow2(N_phase));

if DITHERING == true
    dither_noise = rand(1, len) * pow2(N_phase - N_lut_addr);
%     dither_noise = lfsr(lfsr_seed, lfsr_poly, N_lfsr, N_phase - N_lut_addr, len)'
    phase_acc = phase_acc + dither_noise;
    phase_acc = mod(phase_acc, pow2(N_phase));
end


phase_acc_msb = floor(phase_acc / pow2(N_phase - N_lut_addr)); % get the first MSBs of the phase acc
phase_acc_lsb = phase_acc - phase_acc_msb * pow2(N_phase - N_lut_addr); % get the LSBs of the phase acc


phase_acc_sin = mod(phase_acc, pow2(N_phase));
phase_acc_cos = mod(phase_acc + pow2(N_phase - 2), pow2(N_phase));

phase_acc_msb_sin = floor(phase_acc_sin / pow2(N_phase - N_lut_addr)); % get the first MSBs of the phase acc
phase_acc_lsb_sin = phase_acc_sin - phase_acc_msb_sin * pow2(N_phase - N_lut_addr); % get the LSBs of the phase acc

phase_acc_msb_cos = floor(phase_acc_cos / pow2(N_phase - N_lut_addr)); % get the first MSBs of the phase acc
phase_acc_lsb_cos = phase_acc_cos - phase_acc_msb_cos * pow2(N_phase - N_lut_addr); % get the LSBs of the phase acc

%% calculate actual frequency ouput

[dds_out_sin, dds_out_cos] = sin_lut_cplx(phase_acc_msb, N_lut_addr, N_lut);

[sin_grad, cos_grad] = sin_lut_cplx(mod(phase_acc_msb + 1, pow2(N_lut)), N_lut_addr, N_lut);
sin_grad = sin_grad - dds_out_sin;
cos_grad = cos_grad - dds_out_cos;

%187/-188
if TAYLOR == true
    correction_sin = floor(sin_grad .* phase_acc_lsb / pow2(N_phase - N_lut_addr));
    dds_out_sin = dds_out_sin + correction_sin;
    correction_cos = floor(cos_grad .* phase_acc_lsb / pow2(N_phase - N_lut_addr));
    dds_out_cos = dds_out_cos + correction_cos;
end


% if TAYLOR == true
%     phase_acc_lsb = phase_acc_lsb / pow2(N_phase);
%     correction_sin = floor(dds_out_cos / pow2(6) .* phase_acc_lsb);
%     correction_cos = floor(dds_out_sin / pow2(6) .* phase_acc_lsb);
%     dds_out_sin = dds_out_sin + correction_sin;
%     dds_out_cos = dds_out_cos + correction_cos;
% end



if N_lut > N_adc
    dither_noise = lfsr(lfsr_seed, lfsr_poly, N_lfsr, N_lut - N_adc, len)';
%     dither_noise_lfsr = lfsr(lfsr_seed, lfsr_poly, N_lfsr, 32, len)';
%     dither_noise = bin_usgn_to_sgn(dither_noise, N_lut - N_adc + 1);
%     dither_noise = floor(rand(1, len) * pow2(N_lut - N_adc));
%     dither_noise = zeros(size(dds_out_sin));
    dds_out_sin = dds_out_sin + dither_noise;
    dds_out_sin(dds_out_sin > (pow2(N_lut - 1) - 1)) = pow2(N_lut - 1) - 1; % simulate positive saturation
    dds_out_sin = floor(dds_out_sin / pow2(N_lut - N_adc)); %truncate bits
%     dds_out_sin(dds_out_sin > 2047) = 2047;
%     dds_out_sin(dds_out_sin < -2048) = -2048;
    dds_out_cos = dds_out_cos + dither_noise;
    dds_out_cos(dds_out_cos > (pow2(N_lut - 1) - 1)) =  pow2(N_lut - 1) - 1; % simulate positive saturation
    dds_out_cos = floor(dds_out_cos / pow2(N_lut - N_adc));
%     dds_out_cos(dds_out_cos > 2047) = 2047;
%     dds_out_cos(dds_out_cos < -2048) = -2048;
end

tau = 600;
dds_out = dds_out_cos + 1i * dds_out_sin;
dds_out_down = dds_out_cos - 1i * dds_out_sin;
% dds_out = dds_out(tau:end) .* dds_out_down(1:end-tau+1);

% dds_out_down = circshift(dds_out_cos - 1i * dds_out_sin, tau);
% dds_out = dds_out .* dds_out_down;

%% do some plots
figure(1);
clf;
subplot(3, 1, 1);
stairs(real(dds_out));
% xlim([0, 2000])
hold on;
% stairs(dds_out_corr);
tmp = 0:1/F_clk:((length(dds_out) - 1)/F_clk);
sine_opt = (cos(2*pi*F_0_achieved*tmp) + 1i*sin(2*pi*F_0_achieved*tmp)) * pow2(N_adc - 1);
xlabel('Sample No');
ylabel('Amplitude Value');
% plot(real(sine_opt))

subplot(3, 1, 2);
f_vec = (-floor(len/2):ceil(len/2)-1) * F_clk/len / 10e5;

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
NFFT = 64;
f_vec = (-floor(NFFT/2):ceil(NFFT/2)-1) * F_clk/NFFT;

spectrogram(dds_out, blackmanharris(NFFT), 32, f_vec, F_clk, 'yaxis');
% s = spectrogram(dds_out, ones(64, 1), 10, 64, F_clk);
% s = fftshift(s, 1);
% imagesc(abs(s));
% xlabel('Time');
% ylabel('Frequency');



