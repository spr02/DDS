function [dds_out] = dds(parameters)
%% get input parameters
    %if no input parameters are given, we simply initialize an empty struct
    %that gets filled with default values
    if nargin < 1
        parameters = [];
    end
    
    %if there are input parameters, they need to be in a struct
    if ~isempty(parameters) && ~isstruct(parameters)
        error('"opts" must be a structure');
    end

    %little helper function to "search" for a field and set variabel to
    %default parameter if it does not exist
    function out = set_param( field, default )
        if ~isfield( parameters, field )
            parameters.(field)    = default;
        end
        out = parameters.(field);
    end

    %parameters for dds
    len             = set_param('len',        1000);

    PHASE_DITHER    = set_param('PHASE_DITHER', false);
    AMPL_DITHER     = set_param('AMPL_DITHER', true);
    TAYLOR          = set_param('TAYLOR', true);
    SWEEP           = set_param('SWEEP', false);
    SWEEP_UP_DOWN   = set_param('SWEEP_UP_DOWN', false);
    
    %bit widths
    N_lut_addr      = set_param('N_lut_addr', 10);
    N_lut           = set_param('N_lut',      16);
    N_adc           = set_param('N_adc',      12);
    N_phase         = set_param('N_phase',    32);
    N_grad          = set_param('N_grad',     18);
    N_lfsr          = set_param('N_lfsr',     32);
    N_lsb           = N_phase - N_lut_addr;

    %lfsr
    lfsr_poly       = set_param('lfsr_poly',  [32 22 2 1]);
    lfsr_seed       = set_param('lfsr_seed',  12364);
    latency         = set_param('latency',    6);
    if latency > 0
        tmp = lfsr(lfsr_seed, lfsr_poly, N_lfsr, N_lfsr, latency); % account for latency (i.e. use other seed)
        lfsr_seed   = tmp(end);
    end
    
    %frequency parameters
    F_clk           = set_param('F_clk',      150e6);
    F_0             = set_param('F_0',        0.21 * F_clk);
    F_1             = set_param('F_1',        0.25 * F_clk);
    F_res           = F_clk / pow2(N_phase);  % calculate frequency resolution in Hz
    
    
    % calculate phase/frequency tuning word
    FTW_0           = set_param('FTW_0', round(F_0 / F_res)); %value used to increment the phase accumulator
    FTW_1           = set_param('FTW_1', round(F_1 / F_res)); %stop value in case of sweeps
    Sweep_rate      = set_param('Sweep_rate', 87654);
    diff            = (FTW_1 - FTW_0) / (len / 2);

    %% generate phase_accumulator for sine and cosine
    FTW = FTW_0+Sweep_rate;
    phase_acc = zeros(1, len);
    if SWEEP == true
        for i=2:len
            phase_acc(i) = phase_acc(i-1) + FTW;
            FTW = FTW + Sweep_rate;
            if SWEEP_UP_DOWN == true
                if FTW > FTW_1
                   Sweep_rate = -Sweep_rate;
                elseif FTW < FTW_0
                   Sweep_rate = -Sweep_rate;
                end
            else
                if FTW > FTW_1
                    FTW = 0;
                end
            end
            tmp(i) = FTW;
        end
    else
        for i=2:len
           phase_acc(i) = phase_acc(i-1) + FTW_0;
        end
    end
    phase_acc = mod(phase_acc, pow2(N_phase));

    if PHASE_DITHER == true
        dither_noise = rand(1, len) * pow2(N_lsb);
    %     dither_noise = lfsr(lfsr_seed, lfsr_poly, N_lfsr, N_phase - N_lut_addr, len)'
        phase_acc = phase_acc + dither_noise;
        phase_acc = mod(phase_acc, pow2(N_phase));
    end


    phase_acc_msb = floor(phase_acc / pow2(N_lsb)); % get the first MSBs of the phase acc
    phase_acc_lsb = phase_acc - phase_acc_msb * pow2(N_lsb); % get the LSBs of the phase acc
    phase_acc_lsb = floor(phase_acc_lsb / pow2(N_lsb - N_grad));
    
%     phase_acc_sin = mod(phase_acc, pow2(N_phase));
%     phase_acc_cos = mod(phase_acc + pow2(N_phase - 2), pow2(N_phase));

%     phase_acc_msb_sin = floor(phase_acc_sin / pow2(N_phase - N_lut_addr)); % get the first MSBs of the phase acc
%     phase_acc_lsb_sin = phase_acc_sin - phase_acc_msb_sin * pow2(N_phase - N_lut_addr); % get the LSBs of the phase acc

%     phase_acc_msb_cos = floor(phase_acc_cos / pow2(N_phase - N_lut_addr)); % get the first MSBs of the phase acc
%     phase_acc_lsb_cos = phase_acc_cos - phase_acc_msb_cos * pow2(N_phase - N_lut_addr); % get the LSBs of the phase acc

    %% calculate actual frequency ouput

    %get LUT values
    [dds_out_sin, dds_out_cos] = sin_lut_cplx(phase_acc_msb, N_lut_addr, N_lut);

    %get slope between lut values
    [sin_grad, cos_grad] = sin_lut_cplx(mod(phase_acc_msb + 1, pow2(N_lut)), N_lut_addr, N_lut);
    sin_grad = sin_grad - dds_out_sin;
    cos_grad = cos_grad - dds_out_cos;

    %do taylor interpolation
    if TAYLOR == true
        correction_sin = floor(sin_grad .* phase_acc_lsb / pow2(N_grad));
        dds_out_sin = dds_out_sin + correction_sin;
        correction_cos = floor(cos_grad .* phase_acc_lsb / pow2(N_grad));
        dds_out_cos = dds_out_cos + correction_cos;
    end


    % if TAYLOR == true
    %     phase_acc_lsb = phase_acc_lsb / pow2(N_phase);
    %     correction_sin = floor(dds_out_cos / pow2(6) .* phase_acc_lsb);
    %     correction_cos = floor(dds_out_sin / pow2(6) .* phase_acc_lsb);
    %     dds_out_sin = dds_out_sin + correction_sin;
    %     dds_out_cos = dds_out_cos + correction_cos;
    % end


    % in case number of ouput bits are less, we need to truncate the LSBs
    % of dds_out_sin/cos
    if N_lut > N_adc
        if AMPL_DITHER == true
            dither_noise = lfsr(lfsr_seed, lfsr_poly, N_lfsr, N_lut - N_adc, len)';
    %         dither_noise = bin_usgn_to_sgn(dither_noise, N_lut - N_adc + 1);
    %         dither_noise = floor(rand(1, len) * pow2(N_lut - N_adc));
        else
            dither_noise = zeros(size(dds_out_sin));
        end

        %sine
        dds_out_sin = dds_out_sin + dither_noise;
        dds_out_sin(dds_out_sin > (pow2(N_lut - 1) - 1)) = pow2(N_lut - 1) - 1; % simulate positive saturation
        dds_out_sin = floor(dds_out_sin / pow2(N_lut - N_adc)); %truncate bits

        %cosine
        dds_out_cos = dds_out_cos + dither_noise;
        dds_out_cos(dds_out_cos > (pow2(N_lut - 1) - 1)) =  pow2(N_lut - 1) - 1; % simulate positive saturation
        dds_out_cos = floor(dds_out_cos / pow2(N_lut - N_adc)); %truncate bits
    end


    %construct the complex signal
    dds_out = dds_out_cos + 1i * dds_out_sin;
    
    
    
    

end