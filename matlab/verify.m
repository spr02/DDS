params = struct();

%get the hdl output
hdl_out_log;

params

%run the dds testbench
ref_dds_out = dds(params);

%ouput
real_match = sum(hdl_dds_out(:, 1) == real(ref_dds_out)')
imag_match = sum(hdl_dds_out(:, 2) == imag(ref_dds_out)')

if real_match == params.len && imag_match == params.len
    disp('All values matched.');
else
    str = ['Only ', num2str(real_match), ' real samples and ',...
        num2str(imag_match), ' imaginary sample out of ', num2str(params.len), ' complex samples matched.'];
    disp(str);
end

%correction
% sum(hdl_out(:, 1) == correction_cos')
% sum(hdl_out(:, 2) == correction_sin')
