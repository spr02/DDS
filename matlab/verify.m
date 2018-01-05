%get the hdl output
hdl_out_log

%run the dds testbench
dds_tb

%ouput
sum(hdl_out(:, 1) == dds_out_cos')
sum(hdl_out(:, 2) == dds_out_sin')

%correction
% sum(hdl_out(:, 1) == correction_cos')
% sum(hdl_out(:, 2) == correction_sin')