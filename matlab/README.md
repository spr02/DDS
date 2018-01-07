# Matlab reference model for the DDS
This is a matlab model used to verify the output of the HDL.

## DDS Testbench
The file [dds_tb.m](dds_tb.m) can be used to simulate the DDS core. All parameters can be set and the DDS output can be evalueated. There is also some plot generation included in the script.

## Verifcation
In order to verify the output of the HDL, first the RTL simulation has to be run in order to generate the file "hdl_out_log.m". This includes some parameter definitions and the actual HDL output. This script is automatically executed by the [verify.m](verify.m) script. The script further generates samples using the MATLAB model and verifies the output of the HDL.